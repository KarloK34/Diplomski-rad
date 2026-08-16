"""Scores models on the app's own `session_*.json` recordings, now that they
carry an approximate ground truth: each of the 24 recordings is a single
continuous outdoor walk except for the first/last few pocket-handling
windows. Under that assumption, the share of usable windows predicted `wlk`
is a real recall metric for the walking class -- never call it "accuracy",
since a model that always answers `wlk` would score 1.0 here. It's meaningful
read alongside the MotionSense test set and the 12 labelled recordings, which
do carry other classes, and it tracks the failure mode `gait_segments.dart`
is sensitive to (walking speed/step length derive from `wlk` alone).

A window is usable if its end index is >= `--boundary` seconds from both ends
of the recording. Runs 3/5/7 s by default since "only the first/last few
windows are pocket handling" is an estimate; agreement across all three means
the model ranking doesn't depend on it. Recordings left with too few usable
windows are dropped and listed, not silently.

Usage
-----
    python ml/scripts/user_sessions_eval.py --model models/cnn_final.tflite
    python ml/scripts/user_sessions_eval.py \
        --model models/cnn_final.tflite \
        --model models/cnn_separable_hp_C12_combo_A.keras \
        --predictions ml/results/separable_hp_sweep_user_session_windows.csv

`--predictions` re-scores a CSV of per-window predictions produced by
`separable_hp_sweep.py`, so no model has to be retrained or reloaded.

Outputs (ml/results/)
---------------------
    user_sessions_labelled_eval.csv              one row per model x boundary
    user_sessions_labelled_eval_per_session.csv  one row per model x boundary x session
"""

from __future__ import annotations

import argparse
import collections
import glob
import importlib.util
import json
import os
import sys

import numpy as np
import pandas as pd

_SCRIPTS = os.path.dirname(os.path.abspath(__file__))
_ML_DIR = os.path.abspath(os.path.join(_SCRIPTS, os.pardir))
_REPO_ROOT = os.path.abspath(os.path.join(_ML_DIR, os.pardir))
_RESULTS = os.path.join(_ML_DIR, "results")
_SESSIONS_DIR = os.path.join(_REPO_ROOT, "data", "user_sessions")
sys.path.insert(0, _ML_DIR)

WINDOW, STEP = 128, 64
FS_HZ = 50.0
ACT_LABELS = ["dws", "ups", "wlk", "jog", "std", "sit"]
DEFAULT_BOUNDARIES = (3.0, 5.0, 7.0)


def _load_module(filename: str, alias: str):
    spec = importlib.util.spec_from_file_location(alias, os.path.join(_SCRIPTS, filename))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def usable_mask(n_samples: int, ends, boundary_s: float):
    b = boundary_s * FS_HZ
    return [b <= e <= (n_samples - 1) - b for e in ends]


def session_windows(df_raw, crc, normalize_window):
    from utils.orientation_invariant_features import (
        WALKING_FRAME_V2_COLS, compute_walking_frame_features_v2)
    derived = compute_walking_frame_features_v2(
        df_raw, fs_hz=crc.FS_HZ, smooth_seconds=crc.SMOOTH_SECONDS,
        group_cols=None, keep_meta=False)
    channels = derived[WALKING_FRAME_V2_COLS].to_numpy()
    n = max(0, (len(channels) - WINDOW) // STEP + 1)
    if n == 0:
        return np.empty((0, WINDOW, len(WALKING_FRAME_V2_COLS)), dtype=np.float32), []
    W = np.stack([normalize_window(channels[i * STEP: i * STEP + WINDOW]) for i in range(n)])
    ends = [i * STEP + WINDOW - 1 for i in range(n)]
    return W.astype(np.float32), ends


class KerasModel:
    def __init__(self, path):
        import keras
        self.name = os.path.basename(path)
        self.model = keras.saving.load_model(path, compile=False)

    def predict(self, W):
        return self.model.predict(W, verbose=0).argmax(axis=1)


class TFLiteModel:
    def __init__(self, path):
        import tensorflow as tf
        self.name = os.path.basename(path)
        self.interp = tf.lite.Interpreter(model_path=path)
        self.interp.allocate_tensors()
        self.inp = self.interp.get_input_details()[0]
        self.out = self.interp.get_output_details()[0]

    def predict(self, W):
        preds = []
        for w in W:
            self.interp.set_tensor(self.inp["index"], w[None, ...].astype(np.float32))
            self.interp.invoke()
            preds.append(int(self.interp.get_tensor(self.out["index"])[0].argmax()))
        return np.array(preds)


def load_model(path):
    if path.endswith(".tflite"):
        return TFLiteModel(path)
    return KerasModel(path)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--model", action="append", default=[],
                    help="path to a .keras or .tflite model; repeatable")
    ap.add_argument("--predictions", action="append", default=[],
                    help="CSV of per-window predictions from separable_hp_sweep.py; repeatable")
    ap.add_argument("--sessions-dir", default=_SESSIONS_DIR)
    ap.add_argument("--labels", default=os.path.join(_SESSIONS_DIR, "labels.csv"))
    ap.add_argument("--boundary", type=float, action="append", default=[],
                    help="seconds trimmed at each end; repeatable (default 3, 5, 7)")
    ap.add_argument("--min-windows", type=int, default=5,
                    help="drop a recording left with fewer usable windows")
    args = ap.parse_args()
    boundaries = args.boundary or list(DEFAULT_BOUNDARIES)

    if not args.model and not args.predictions:
        raise SystemExit("nothing to score: pass --model and/or --predictions")

    labels_df = pd.read_csv(args.labels)
    truth = dict(zip(labels_df["session"], labels_df["activity"]))
    print(f"oznake: {len(truth)} sesija iz {args.labels}")

    crc = _load_module("classical_representation_comparison.py", "_crc")
    svo = _load_module("streaming_vs_offline_user_sessions.py", "_svo")

    # ---- per-window predictions, either replayed or read from CSV -----------
    # frame: model, session, window_index, end_sample_index, n_samples, pred
    frames = []

    paths = sorted(glob.glob(os.path.join(args.sessions_dir, "session_*.json")))
    if args.model:
        from utils.streaming_offline_compare import normalize_window
        models = [load_model(p) for p in args.model]
        print(f"modeli: {[m.name for m in models]}")
        for path in paths:
            base = os.path.basename(path)
            if base not in truth:
                continue
            with open(path, encoding="utf-8") as fh:
                session_json = json.load(fh)
            if not session_json.get("rawSamples"):
                print(f"  preskocena {base}: nema rawSamples")
                continue
            df_raw = svo.load_raw_samples(session_json)
            W, ends = session_windows(df_raw, crc, normalize_window)
            if len(W) == 0:
                print(f"  preskocena {base}: prekratka za jedan prozor")
                continue
            for m in models:
                pred = m.predict(W)
                frames.append(pd.DataFrame({
                    "model": m.name, "session": base,
                    "window_index": np.arange(len(pred)),
                    "end_sample_index": ends, "n_samples": len(df_raw),
                    "pred": [ACT_LABELS[int(p)] for p in pred],
                }))
            print(f"  {base:<45s} prozora {len(W):3d}")

    for csv_path in args.predictions:
        df = pd.read_csv(csv_path)
        df = df.rename(columns={"name": "model"})
        missing = {"model", "session", "end_sample_index", "n_samples", "pred"} - set(df.columns)
        if missing:
            raise SystemExit(f"{csv_path}: nedostaju stupci {sorted(missing)}")
        frames.append(df)
        print(f"ucitano {len(df)} redaka iz {os.path.basename(csv_path)}")

    allpred = pd.concat(frames, ignore_index=True)
    allpred = allpred[allpred["session"].isin(truth)]

    # ---- score ---------------------------------------------------------------
    summary, per_session = [], []
    for boundary in boundaries:
        for model, mdf in allpred.groupby("model"):
            used_num = used_den = 0
            dropped = []
            confusion = collections.Counter()
            for session, sdf in mdf.groupby("session"):
                gt = truth[session]
                n_samples = int(sdf["n_samples"].iloc[0])
                mask = usable_mask(n_samples, sdf["end_sample_index"].tolist(), boundary)
                used = sdf[pd.Series(mask, index=sdf.index)]
                if len(used) < args.min_windows:
                    dropped.append((session, len(used)))
                    continue
                hit = int((used["pred"] == gt).sum())
                confusion.update(used.loc[used["pred"] != gt, "pred"].tolist())
                used_num += hit
                used_den += len(used)
                per_session.append({
                    "model": model, "boundary_s": boundary, "session": session,
                    "ground_truth": gt, "n_windows": len(sdf), "n_used": len(used),
                    "recall": hit / len(used),
                    "top_error": (used.loc[used["pred"] != gt, "pred"].mode().iloc[0]
                                  if hit < len(used) else ""),
                })
            row = {
                "model": model, "boundary_s": boundary,
                "wlk_recall_weighted": used_num / used_den if used_den else float("nan"),
                "n_sessions": len(mdf["session"].unique()) - len(dropped),
                "n_used_windows": used_den,
                "n_dropped_sessions": len(dropped),
                "dropped": " ".join(s for s, _ in dropped),
            }
            for cls in ACT_LABELS:
                row[f"err_{cls}"] = confusion.get(cls, 0) / used_den if used_den else 0.0
            summary.append(row)

    sum_df = pd.DataFrame(summary).sort_values(["boundary_s", "wlk_recall_weighted"],
                                               ascending=[True, False])
    ps_df = pd.DataFrame(per_session)
    os.makedirs(_RESULTS, exist_ok=True)
    sum_df.to_csv(os.path.join(_RESULTS, "user_sessions_labelled_eval.csv"), index=False)
    ps_df.to_csv(os.path.join(_RESULTS, "user_sessions_labelled_eval_per_session.csv"),
                 index=False)

    print("\nodziv razreda hodanja (nije tocnost, skup nema drugih razreda):")
    cols = ["boundary_s", "model", "wlk_recall_weighted", "n_sessions", "n_used_windows",
            "err_ups", "err_std", "err_dws"]
    print(sum_df[cols].round(4).to_string(index=False))
    for _, r in sum_df.iterrows():
        if r["n_dropped_sessions"]:
            print(f"  prag {r['boundary_s']:.0f} s, {r['model']}: izbaceno "
                  f"{int(r['n_dropped_sessions'])} snimaka ({r['dropped']})")
    print("\nspremljeno u ml/results/user_sessions_labelled_eval{,_per_session}.csv")


if __name__ == "__main__":
    main()
