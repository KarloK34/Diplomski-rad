"""Equal-budget hyperparameter sweep for the depthwise-separable CNN on wf2.

Gives the separable architecture the same 14 configs, search space and
selection protocol as the baseline sweep (train 0-14, early-stop 15-18,
validation macro-F1 as the only selection criterion, test set 19-23 touched
once for the top 3, 5-fold GroupKFold CV for the winner) so it's comparable
to `A_baseline`/`D_dilated_reg` instead of being judged on default
hyperparameters against tuned competitors.

Usage:
    python ml/scripts/separable_hp_sweep.py --only C0_vanilla   # smoke test, ~2 min
    python ml/scripts/separable_hp_sweep.py                     # full sweep, ~1-2 h CPU
    python ml/scripts/separable_hp_sweep.py --user-sessions C:\\Users\\karlo\\Downloads

Outputs go to ml/results/ (separable_hp_sweep_{val,test,cv,in_the_wild}*.csv)
and models/cnn_separable_hp_<winner>.keras{,.preproc.json}.
"""

from __future__ import annotations

import argparse
import glob
import importlib.util
import json
import os
import sys
import time

import numpy as np
import pandas as pd

_SCRIPTS = os.path.dirname(os.path.abspath(__file__))
_ML_DIR = os.path.abspath(os.path.join(_SCRIPTS, os.pardir))
_REPO_ROOT = os.path.abspath(os.path.join(_ML_DIR, os.pardir))
_RESULTS = os.path.join(_ML_DIR, "results")
_MODELS = os.path.join(_REPO_ROOT, "models")
sys.path.insert(0, _ML_DIR)

SEED = 42
WINDOW, STEP = 128, 64
ACT_LABELS = ["dws", "ups", "wlk", "jog", "std", "sit"]

# Identical to CONFIGS in 13-hp-sweep-baseline.ipynb: same 14 points, same order.
# name, lr, batch, l2, spatial_dropout, dense_dropout, label_smoothing
CONFIGS = [
    ("C0_vanilla",   1e-3, 32, 0.0,   0.0, 0.3, 0.0),
    ("C1_low_lr",    5e-4, 32, 0.0,   0.0, 0.3, 0.0),
    ("C2_high_lr",   2e-3, 32, 0.0,   0.0, 0.3, 0.0),
    ("C3_small_bs",  1e-3, 16, 0.0,   0.0, 0.3, 0.0),
    ("C4_large_bs",  1e-3, 64, 0.0,   0.0, 0.3, 0.0),
    ("C5_l2_light",  1e-3, 32, 5e-5,  0.0, 0.3, 0.0),
    ("C6_l2_heavy",  1e-3, 32, 5e-4,  0.0, 0.3, 0.0),
    ("C7_sd_light",  1e-3, 32, 0.0,   0.1, 0.3, 0.0),
    ("C8_sd_heavy",  1e-3, 32, 0.0,   0.2, 0.3, 0.0),
    ("C9_less_dd",   1e-3, 32, 0.0,   0.0, 0.2, 0.0),
    ("C10_more_dd",  1e-3, 32, 0.0,   0.0, 0.4, 0.0),
    ("C11_ls",       1e-3, 32, 0.0,   0.0, 0.3, 0.05),
    ("C12_combo_A",  1e-3, 32, 1e-4,  0.2, 0.3, 0.05),
    ("C13_combo_B",  5e-4, 32, 1e-4,  0.1, 0.3, 0.05),
]
FIELDS = ("name", "lr", "batch", "l2", "sd", "dd", "ls")


def _load_module(filename: str, alias: str):
    spec = importlib.util.spec_from_file_location(alias, os.path.join(_SCRIPTS, filename))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def build_separable_param(input_shape, n_classes=6, l2=0.0, spatial_dropout=0.0,
                          dense_dropout=0.3):
    """Notebook 03 §5 `build_cnn_separable`, with the baseline sweep's knobs added.

    With l2=0, spatial_dropout=0, dense_dropout=0.3 this is bit-for-bit the
    architecture `separable_on_wf2.py` already measured. `SeparableConv1D` has
    no `kernel_regularizer`, so l2 here applies to both the depthwise and
    pointwise kernel.
    """
    import keras
    from keras import layers, regularizers
    reg = regularizers.l2(l2) if l2 > 0 else None

    def sep(x, filters, kernel):
        return layers.SeparableConv1D(
            filters, kernel, activation="relu", padding="same",
            depthwise_regularizer=reg, pointwise_regularizer=reg)(x)

    inp = keras.Input(shape=input_shape)
    x = sep(inp, 64, 7)
    x = layers.BatchNormalization()(x)
    if spatial_dropout > 0:
        x = layers.SpatialDropout1D(spatial_dropout)(x)
    x = layers.MaxPooling1D(2)(x)
    x = sep(x, 128, 5)
    x = layers.BatchNormalization()(x)
    if spatial_dropout > 0:
        x = layers.SpatialDropout1D(spatial_dropout)(x)
    x = layers.MaxPooling1D(2)(x)
    x = sep(x, 128, 3)
    x = layers.BatchNormalization()(x)
    x = layers.GlobalAveragePooling1D()(x)
    x = layers.Dense(128, activation="relu", kernel_regularizer=reg)(x)
    x = layers.Dropout(dense_dropout)(x)
    return keras.Model(inp, layers.Dense(n_classes, activation="softmax")(x),
                       name="cnn_separable_param")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", help="comma-separated config names, for a smoke test")
    ap.add_argument("--top-k", type=int, default=3, help="how many configs reach the test set")
    ap.add_argument("--user-sessions", metavar="DIR",
                    help="directory with the app's session_*.json logs")
    ap.add_argument("--no-cv", action="store_true", help="skip the 5-fold CV of the winner")
    args = ap.parse_args()

    import tensorflow as tf
    import keras
    from keras import callbacks, losses
    from sklearn.metrics import confusion_matrix, f1_score
    from sklearn.model_selection import GroupKFold
    from sklearn.utils.class_weight import compute_class_weight
    from utils.orientation_invariant_features import (
        WALKING_FRAME_V2_COLS, compute_walking_frame_features_v2)
    from utils.streaming_offline_compare import normalize_window

    crc = _load_module("classical_representation_comparison.py", "_crc")
    sep_base = _load_module("separable_on_wf2.py", "_sep_base")

    configs = [c for c in CONFIGS
               if not args.only or c[0] in {s.strip() for s in args.only.split(",")}]
    if not configs:
        raise SystemExit(f"--only matched nothing; names are {[c[0] for c in CONFIGS]}")
    print(f"{len(configs)} konfiguracija u redu\n")

    print("ucitavanje MotionSensea ...")
    raw = crc.load_motionsense()
    feats = compute_walking_frame_features_v2(raw, fs_hz=crc.FS_HZ,
                                              smooth_seconds=crc.SMOOTH_SECONDS)

    def split(ids):
        X, y, g = crc.sliding_windows(feats[feats["id"].isin(ids)], WALKING_FRAME_V2_COLS)
        Xn = np.stack([normalize_window(w) for w in X]).astype(np.float32)
        return Xn, y.astype(int), g

    Xtr, ytr, _ = split(range(15))
    Xva, yva, _ = split(range(15, 19))
    Xte, yte, _ = split(range(19, 24))
    print(f"  ucenje {Xtr.shape}, vrednovanje {Xva.shape}, ispitivanje {Xte.shape}")

    cw = compute_class_weight("balanced", classes=np.arange(6), y=ytr)
    class_weight = {int(i): float(w) for i, w in enumerate(cw)}
    n_chan = len(WALKING_FRAME_V2_COLS)

    def fit_one(cfg):
        name, lr, batch, l2, sd, dd, ls = cfg
        tf.keras.backend.clear_session()
        tf.random.set_seed(SEED)
        np.random.seed(SEED)
        model = build_separable_param((WINDOW, n_chan), l2=l2, spatial_dropout=sd,
                                      dense_dropout=dd)
        if ls > 0:
            loss = losses.CategoricalCrossentropy(label_smoothing=ls)
            y_fit = tf.one_hot(ytr, depth=6).numpy()
            y_val_fit = tf.one_hot(yva, depth=6).numpy()
        else:
            loss = losses.SparseCategoricalCrossentropy()
            y_fit, y_val_fit = ytr, yva
        model.compile(optimizer=keras.optimizers.Adam(lr), loss=loss, metrics=["accuracy"])
        t0 = time.time()
        hist = model.fit(
            Xtr, y_fit, validation_data=(Xva, y_val_fit), epochs=50, batch_size=batch,
            class_weight=class_weight, verbose=0,
            callbacks=[callbacks.EarlyStopping(monitor="val_loss", patience=10,
                                               restore_best_weights=True),
                       callbacks.ReduceLROnPlateau(monitor="val_loss", patience=5,
                                                   factor=0.5, min_lr=1e-6)])
        val_f1 = float(f1_score(yva, model.predict(Xva, verbose=0).argmax(axis=1),
                                average="macro"))
        row = dict(zip(FIELDS, cfg))
        row.update(val_f1=val_f1, epochs=len(hist.history["loss"]),
                   elapsed_s=round(time.time() - t0, 1),
                   params=int(model.count_params()))
        return row, model

    trained = {}
    rows = []
    for cfg in configs:
        row, model = fit_one(cfg)
        trained[row["name"]] = model
        rows.append(row)
        print(f"  {row['name']:14s} val_F1={row['val_f1']:.4f}  epoha={row['epochs']:>2d}  "
              f"{row['elapsed_s']:.0f} s")

    os.makedirs(_RESULTS, exist_ok=True)
    val_df = pd.DataFrame(rows).sort_values("val_f1", ascending=False).reset_index(drop=True)
    val_df.to_csv(os.path.join(_RESULTS, "separable_hp_sweep_val.csv"), index=False)
    print("\nporedak po skupu za vrednovanje:")
    print(val_df[["name", "val_f1", "epochs", "params"]].round(4).to_string(index=False))

    top = val_df.head(args.top_k)["name"].tolist()
    print(f"\nskup za ispitivanje otvara se za: {top}")
    test_rows = []
    for name in top:
        pred = trained[name].predict(Xte, verbose=0).argmax(axis=1)
        per_class = f1_score(yte, pred, average=None)
        test_rows.append({
            "name": name,
            "val_f1": float(val_df.loc[val_df.name == name, "val_f1"].iloc[0]),
            "test_f1": float(f1_score(yte, pred, average="macro")),
            "accuracy": float((pred == yte).mean()),
            **{f"F1_{a}": float(v) for a, v in zip(ACT_LABELS, per_class)},
        })
    test_df = pd.DataFrame(test_rows).set_index("name")
    test_df.to_csv(os.path.join(_RESULTS, "separable_hp_sweep_test.csv"))
    print(test_df.round(4).to_string())

    winner = top[0]  # selection is by validation, not by test
    print(f"\npobjednik po kriteriju odabira (skup za vrednovanje): {winner}  "
          f"test macro-F1 {test_df.loc[winner, 'test_f1']:.4f}")
    if test_df["test_f1"].idxmax() != winner:
        print(f"  napomena: najvisi test macro-F1 ima {test_df['test_f1'].idxmax()}, "
              f"ali odabir se po protokolu ne mijenja")

    winner_cfg = [c for c in CONFIGS if c[0] == winner][0]
    _, lr_w, bs_w, l2_w, sd_w, dd_w, ls_w = winner_cfg

    # ---- 5-fold GroupKFold over all 24 subjects, winner only -----------------
    if not args.no_cv:
        print("\nunakrsna provjera s pet preklopa ...")
        Xall, yall, gall = split(range(24))
        scores = []
        for fold, (tr, te) in enumerate(GroupKFold(5).split(Xall, yall, groups=gall), 1):
            tf.keras.backend.clear_session()
            tf.random.set_seed(SEED)
            np.random.seed(SEED)
            m = build_separable_param((WINDOW, n_chan), l2=l2_w, spatial_dropout=sd_w,
                                      dense_dropout=dd_w)
            if ls_w > 0:
                loss = losses.CategoricalCrossentropy(label_smoothing=ls_w)
                y_fit = tf.one_hot(yall[tr], depth=6).numpy()
            else:
                loss = losses.SparseCategoricalCrossentropy()
                y_fit = yall[tr]
            m.compile(optimizer=keras.optimizers.Adam(lr_w), loss=loss, metrics=["accuracy"])
            cwf = compute_class_weight("balanced", classes=np.arange(6), y=yall[tr])
            m.fit(Xall[tr], y_fit, epochs=25, batch_size=bs_w, verbose=0,
                  class_weight={int(i): float(w) for i, w in enumerate(cwf)})
            s = float(f1_score(yall[te], m.predict(Xall[te], verbose=0).argmax(axis=1),
                               average="macro"))
            scores.append(s)
            print(f"  preklop {fold}: {s:.4f}")
        pd.DataFrame([{"name": winner, "cv_mean": float(np.mean(scores)),
                       "cv_std": float(np.std(scores)),
                       "folds": " ".join(f"{s:.4f}" for s in scores)}]).to_csv(
            os.path.join(_RESULTS, "separable_hp_sweep_cv.csv"), index=False)
        print(f"  -> {np.mean(scores):.4f} +/- {np.std(scores):.4f}")

    # ---- twelve labelled recordings, reported for the top-k ------------------
    print("\ndvanaest oznacenih snimaka ...")
    labels = pd.read_csv(crc._ITW_LABELS_CSV)
    sessions = {}
    for _, meta in labels.iterrows():
        W = sep_base.session_windows(crc, meta["session_dir"], normalize_window)
        if len(W):
            sessions[meta["session_dir"]] = (W, int(meta["activity_id"]),
                                             meta["pocket_orientation"])
    itw_rows, itw_sessions = [], []
    for name in top:
        correct = total = majority_ok = 0
        for session, (W, gt, orient) in sessions.items():
            p = trained[name].predict(W, verbose=0).argmax(axis=1)
            c = int((p == gt).sum())
            modal = int(np.bincount(p, minlength=6).argmax())
            correct += c
            total += len(p)
            majority_ok += int(modal == gt)
            itw_sessions.append({"name": name, "session": session, "orientation": orient,
                                 "true": ACT_LABELS[gt], "correct_frac": c / len(p),
                                 "majority": ACT_LABELS[modal], "n_windows": len(p)})
        itw_rows.append({"name": name, "window_acc": correct / total,
                         "session_acc": majority_ok / len(sessions),
                         "n_windows": total, "n_sessions": len(sessions)})
        print(f"  {name:14s} po prozoru {correct / total:.4f}  "
              f"po sesiji {majority_ok / len(sessions):.4f}")
    pd.DataFrame(itw_rows).to_csv(
        os.path.join(_RESULTS, "separable_hp_sweep_in_the_wild.csv"), index=False)
    pd.DataFrame(itw_sessions).to_csv(
        os.path.join(_RESULTS, "separable_hp_sweep_in_the_wild_per_session.csv"), index=False)

    # ---- app sessions: dump per-window predictions, score later --------------
    if args.user_sessions:
        print("\nsesije aplikacije ...")
        svo = _load_module("streaming_vs_offline_user_sessions.py", "_svo")
        paths = sorted(glob.glob(os.path.join(args.user_sessions, "session_*.json")))
        if not paths:
            print(f"  nema session_*.json u {args.user_sessions}")
        out_rows = []
        for path in paths:
            with open(path, encoding="utf-8") as fh:
                session_json = json.load(fh)
            if not session_json.get("rawSamples"):
                continue
            df_raw = svo.load_raw_samples(session_json)
            derived = compute_walking_frame_features_v2(
                df_raw, fs_hz=crc.FS_HZ, smooth_seconds=crc.SMOOTH_SECONDS,
                group_cols=None, keep_meta=False)
            channels = derived[WALKING_FRAME_V2_COLS].to_numpy()
            n = max(0, (len(channels) - WINDOW) // STEP + 1)
            if n == 0:
                continue
            W = np.stack([normalize_window(channels[i * STEP: i * STEP + WINDOW])
                          for i in range(n)]).astype(np.float32)
            ends = [i * STEP + WINDOW - 1 for i in range(n)]
            core = svo.core_window_mask(len(df_raw), ends)
            for name in top:
                p = trained[name].predict(W, verbose=0).argmax(axis=1)
                for k, (lab, end, is_core) in enumerate(zip(p, ends, core)):
                    out_rows.append({
                        "name": name, "session": os.path.basename(path),
                        "window_index": k, "end_sample_index": end,
                        "n_samples": len(df_raw), "core_3s": bool(is_core),
                        "pred": ACT_LABELS[int(lab)],
                    })
            print(f"  {os.path.basename(path):<45s} prozora {n:3d}")
        if out_rows:
            pd.DataFrame(out_rows).to_csv(
                os.path.join(_RESULTS, "separable_hp_sweep_user_session_windows.csv"),
                index=False)
            print(f"  -> {len(out_rows)} redaka po prozoru spremljeno")

    # ---- save the winner so nothing has to be retrained ----------------------
    os.makedirs(_MODELS, exist_ok=True)
    out_path = os.path.join(_MODELS, f"cnn_separable_hp_{winner}.keras")
    trained[winner].save(out_path)
    with open(out_path.replace(".keras", ".preproc.json"), "w", encoding="utf-8") as fh:
        json.dump({
            "variant": f"separable__{winner}",
            "lr": lr_w, "batch_size": int(bs_w), "l2": l2_w,
            "spatial_dropout": sd_w, "dense_dropout": dd_w, "label_smoothing": ls_w,
            "channel_order": list(WALKING_FRAME_V2_COLS),
            "class_labels": ACT_LABELS,
            "window_size": WINDOW, "step": STEP, "fs_hz": crc.FS_HZ,
            "smooth_seconds": crc.SMOOTH_SECONDS,
            "feature_module": "utils.orientation_invariant_features.compute_walking_frame_features_v2",
            "all_dynamic_zscore": True,
        }, fh, indent=2)
    print(f"\nspremljeno {out_path}")


if __name__ == "__main__":
    main()
