"""Measures how much of a single training run's score is just the random seed.

On 2026-08-13 the separable architecture scored 0.9568 macro-F1 on one seed vs
the baseline's 0.9413; three more seeds on the same config gave 0.9013, 0.9178
and 0.9334 (0.9273 +/- 0.0205 across four seeds), with in-the-wild walking
recall ranging 0.476-0.878. That spread is larger than the differences ch. 3.4
draws conclusions from, so it needs reporting per architecture, not just the
one that surfaced it. Runs are merged into one CSV by (arch, config, seed).

Usage
-----
    python ml/scripts/seed_variability.py --arch baseline  --seeds 42,1,2,3
    python ml/scripts/seed_variability.py --arch separable --seeds 42,1,2,3
    python ml/scripts/seed_variability.py --arch baseline --seeds 42 \
        --user-sessions data/user_sessions

Seed 42 reproduces the published numbers: baseline 0.9413, separable 0.9568.
If it does not, something else changed and nothing below can be trusted.

Outputs (ml/results/)
---------------------
    seed_variability.csv                      one row per (arch, config, seed)
    seed_variability_user_session_windows.csv  per-window predictions, readable by
        `user_sessions_eval.py --predictions`
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
sys.path.insert(0, _ML_DIR)

WINDOW, STEP = 128, 64
ACT_LABELS = ["dws", "ups", "wlk", "jog", "std", "sit"]

# Both sweeps selected the same knob set, which is itself worth reporting.
KNOBS = {  # config -> lr, batch, l2, spatial_dropout, dense_dropout, label_smoothing
    "C12_combo_A": (1e-3, 32, 1e-4, 0.2, 0.3, 0.05),
    "C0_vanilla": (1e-3, 32, 0.0, 0.0, 0.3, 0.0),
}


def _load_module(filename: str, alias: str):
    spec = importlib.util.spec_from_file_location(alias, os.path.join(_SCRIPTS, filename))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def build_baseline_param(input_shape, n_classes=6, l2=0.0, spatial_dropout=0.0,
                         dense_dropout=0.3):
    """`build_A_baseline_param` from 13-hp-sweep-baseline.ipynb, verbatim."""
    import keras
    from keras import layers, regularizers
    reg = regularizers.l2(l2) if l2 > 0 else None
    inp = keras.Input(shape=input_shape)
    x = layers.Conv1D(64, 5, activation="relu", padding="same", kernel_regularizer=reg)(inp)
    x = layers.BatchNormalization()(x)
    if spatial_dropout > 0:
        x = layers.SpatialDropout1D(spatial_dropout)(x)
    x = layers.MaxPooling1D(2)(x)
    x = layers.Conv1D(128, 5, activation="relu", padding="same", kernel_regularizer=reg)(x)
    x = layers.BatchNormalization()(x)
    if spatial_dropout > 0:
        x = layers.SpatialDropout1D(spatial_dropout)(x)
    x = layers.MaxPooling1D(2)(x)
    x = layers.Conv1D(128, 3, activation="relu", padding="same", kernel_regularizer=reg)(x)
    x = layers.BatchNormalization()(x)
    x = layers.GlobalAveragePooling1D()(x)
    x = layers.Dense(128, activation="relu", kernel_regularizer=reg)(x)
    x = layers.Dropout(dense_dropout)(x)
    return keras.Model(inp, layers.Dense(n_classes, activation="softmax")(x),
                       name="cnn_A_baseline_param")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--arch", choices=["baseline", "separable"], required=True)
    ap.add_argument("--config", default="C12_combo_A", choices=sorted(KNOBS))
    ap.add_argument("--seeds", default="42,1,2,3")
    ap.add_argument("--user-sessions", metavar="DIR")
    args = ap.parse_args()
    seeds = [int(s) for s in args.seeds.split(",")]
    lr, batch, l2, sd, dd, ls = KNOBS[args.config]

    import tensorflow as tf
    import keras
    from keras import callbacks, losses
    from sklearn.metrics import f1_score
    from sklearn.utils.class_weight import compute_class_weight
    from utils.orientation_invariant_features import (
        WALKING_FRAME_V2_COLS, compute_walking_frame_features_v2)
    from utils.streaming_offline_compare import normalize_window

    crc = _load_module("classical_representation_comparison.py", "_crc")
    sep_base = _load_module("separable_on_wf2.py", "_sep_base")
    if args.arch == "separable":
        sweep = _load_module("separable_hp_sweep.py", "_sweep")
        builder = sweep.build_separable_param
    else:
        builder = build_baseline_param

    print(f"{args.arch} / {args.config}: lr={lr} batch={batch} l2={l2} sd={sd} dd={dd} ls={ls}")
    print(f"sjemena: {seeds}\n")

    raw = crc.load_motionsense()
    feats = compute_walking_frame_features_v2(raw, fs_hz=crc.FS_HZ,
                                              smooth_seconds=crc.SMOOTH_SECONDS)

    def split(ids):
        X, y, _ = crc.sliding_windows(feats[feats["id"].isin(ids)], WALKING_FRAME_V2_COLS)
        return np.stack([normalize_window(w) for w in X]).astype(np.float32), y.astype(int)

    Xtr, ytr = split(range(15))
    Xva, yva = split(range(15, 19))
    Xte, yte = split(range(19, 24))
    cw = compute_class_weight("balanced", classes=np.arange(6), y=ytr)
    class_weight = {int(i): float(w) for i, w in enumerate(cw)}
    n_chan = len(WALKING_FRAME_V2_COLS)

    labels = pd.read_csv(crc._ITW_LABELS_CSV)
    itw = {}
    for _, meta in labels.iterrows():
        W = sep_base.session_windows(crc, meta["session_dir"], normalize_window)
        if len(W):
            itw[meta["session_dir"]] = (W, int(meta["activity_id"]))

    user_sessions = []
    if args.user_sessions:
        svo = _load_module("streaming_vs_offline_user_sessions.py", "_svo")
        for path in sorted(glob.glob(os.path.join(args.user_sessions, "session_*.json"))):
            with open(path, encoding="utf-8") as fh:
                session_json = json.load(fh)
            if not session_json.get("rawSamples"):
                continue
            df_raw = svo.load_raw_samples(session_json)
            derived = compute_walking_frame_features_v2(
                df_raw, fs_hz=crc.FS_HZ, smooth_seconds=crc.SMOOTH_SECONDS,
                group_cols=None, keep_meta=False)
            ch = derived[WALKING_FRAME_V2_COLS].to_numpy()
            n = max(0, (len(ch) - WINDOW) // STEP + 1)
            if n == 0:
                continue
            W = np.stack([normalize_window(ch[i * STEP: i * STEP + WINDOW])
                          for i in range(n)]).astype(np.float32)
            user_sessions.append((os.path.basename(path), W,
                                  [i * STEP + WINDOW - 1 for i in range(n)], len(df_raw)))
        print(f"sesije aplikacije: {len(user_sessions)}\n")

    rows, window_rows = [], []
    for seed in seeds:
        tf.keras.backend.clear_session()
        tf.random.set_seed(seed)
        np.random.seed(seed)
        model = builder((WINDOW, n_chan), l2=l2, spatial_dropout=sd, dense_dropout=dd)
        if ls > 0:
            loss = losses.CategoricalCrossentropy(label_smoothing=ls)
            y_fit, y_val_fit = tf.one_hot(ytr, 6).numpy(), tf.one_hot(yva, 6).numpy()
        else:
            loss = losses.SparseCategoricalCrossentropy()
            y_fit, y_val_fit = ytr, yva
        model.compile(optimizer=keras.optimizers.Adam(lr), loss=loss, metrics=["accuracy"])
        t0 = time.time()
        hist = model.fit(Xtr, y_fit, validation_data=(Xva, y_val_fit), epochs=50,
                         batch_size=batch, class_weight=class_weight, verbose=0,
                         callbacks=[callbacks.EarlyStopping(monitor="val_loss", patience=10,
                                                            restore_best_weights=True),
                                    callbacks.ReduceLROnPlateau(monitor="val_loss", patience=5,
                                                                factor=0.5, min_lr=1e-6)])
        val_f1 = float(f1_score(yva, model.predict(Xva, verbose=0).argmax(axis=1), average="macro"))
        pred = model.predict(Xte, verbose=0).argmax(axis=1)
        test_f1 = float(f1_score(yte, pred, average="macro"))
        per_class = f1_score(yte, pred, average=None)

        correct = total = majority_ok = 0
        for _, (W, gt) in itw.items():
            p = model.predict(W, verbose=0).argmax(axis=1)
            correct += int((p == gt).sum())
            total += len(p)
            majority_ok += int(int(np.bincount(p, minlength=6).argmax()) == gt)

        tag = f"{args.arch}_{args.config}_seed{seed}"
        for session, W, ends, n_samples in user_sessions:
            p = model.predict(W, verbose=0).argmax(axis=1)
            for k, (lab, end) in enumerate(zip(p, ends)):
                window_rows.append({"model": tag, "session": session, "window_index": k,
                                    "end_sample_index": end, "n_samples": n_samples,
                                    "pred": ACT_LABELS[int(lab)]})

        rows.append({"arch": args.arch, "config": args.config, "seed": seed,
                     "params": int(model.count_params()), "val_f1": val_f1, "test_f1": test_f1,
                     "itw_window_acc": correct / total, "itw_session_acc": majority_ok / len(itw),
                     "epochs": len(hist.history["loss"]), "elapsed_s": round(time.time() - t0, 1),
                     **{f"F1_{a}": float(v) for a, v in zip(ACT_LABELS, per_class)}})
        print(f"  sjeme {seed:>3d}: val {val_f1:.4f}  test {test_f1:.4f}  "
              f"12 snimaka {correct / total:.4f}  epoha {len(hist.history['loss'])}")

    os.makedirs(_RESULTS, exist_ok=True)
    key = ["arch", "config", "seed"]
    out_path = os.path.join(_RESULTS, "seed_variability.csv")
    df = pd.DataFrame(rows)
    if os.path.exists(out_path):
        old = pd.read_csv(out_path)
        df = pd.concat([old, df], ignore_index=True).drop_duplicates(subset=key, keep="last")
    df.sort_values(key).to_csv(out_path, index=False)

    win_path = os.path.join(_RESULTS, "seed_variability_user_session_windows.csv")
    if window_rows:
        wdf = pd.DataFrame(window_rows)
        if os.path.exists(win_path):
            old = pd.read_csv(win_path)
            wdf = pd.concat([old[~old["model"].isin(wdf["model"].unique())], wdf],
                            ignore_index=True)
        wdf.to_csv(win_path, index=False)

    print("\nrasipanje po sjemenima, sve mjereno:")
    for (arch, config), g in df.groupby(["arch", "config"]):
        if len(g) < 2:
            print(f"  {arch}/{config}: samo {len(g)} mjerenje")
            continue
        print(f"  {arch}/{config}  n={len(g)}")
        for col, lbl in [("test_f1", "test macro-F1"), ("itw_window_acc", "12 snimaka po prozoru")]:
            print(f"      {lbl:24s} {g[col].mean():.4f} +/- {g[col].std(ddof=0):.4f}"
                  f"   raspon {g[col].min():.4f}-{g[col].max():.4f}")
    print(f"\nspremljeno {out_path}")


if __name__ == "__main__":
    main()
