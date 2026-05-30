"""Export numerical-parity fixtures for the Dart walking-frame v2 pipeline.

For each chosen MotionSense session this writes a JSON file containing:
  - ``input``   : the raw 9-channel IMU samples used by the v2 feature math
                  (gravity, userAcceleration, rotationRate), already in iOS
                  CoreMotion convention because MotionSense is iOS-native.
  - ``windows`` : the expected normalized 8-channel windows (shape
                  [n_windows, 128, 8]) the model is fed at inference time.

The expected windows are produced by the *exact* training-time pipeline:
``compute_walking_frame_features_v2`` over the whole session block, then
``sliding_windows`` (w=128, s=64), then ``normalize_dyn`` (instance Z-score,
population std, +1e-8) -- the functions used in notebooks 11 and 14. The Dart
implementation in ``app/lib/services/feature_pipeline.dart`` must reproduce
these windows to < 1e-4 max absolute error.

Walking (``wlk_7/sub_5``) exercises the normal walking-direction branch; the
static session (``sit_5/sub_5``) exercises the ``mean_dir_norm < 1e-3``
fallback branch of the walking-frame computation.

Run from the repo root:
    python ml/scripts/export_parity_fixtures.py
"""

from __future__ import annotations

import json
import os
import sys

import numpy as np
import pandas as pd

# Make ``utils`` importable when run from the repo root.
_ML_DIR = os.path.join(os.path.dirname(__file__), os.pardir)
sys.path.insert(0, os.path.abspath(_ML_DIR))

from utils.orientation_invariant_features import (
    WALKING_FRAME_V2_COLS,
    compute_walking_frame_features_v2,
)

# Class order matches cnn_final.preproc.json.class_labels.
ACT_LABELS = ["dws", "ups", "wlk", "jog", "std", "sit"]

# The 9 raw channels the v2 feature math actually consumes, in the order the
# Dart SensorSample exposes them. Attitude is intentionally excluded: the v2
# pipeline never reads it (see ml/utils/orientation_invariant_features.py).
RAW_INPUT_COLS = [
    "gravity.x", "gravity.y", "gravity.z",
    "userAcceleration.x", "userAcceleration.y", "userAcceleration.z",
    "rotationRate.x", "rotationRate.y", "rotationRate.z",
]

_REPO_ROOT = os.path.abspath(os.path.join(_ML_DIR, os.pardir))
_DATA_DIR = os.path.join(_REPO_ROOT, "data", "A_DeviceMotion_data")
_OUT_DIR = os.path.join(_REPO_ROOT, "app", "test", "fixtures", "parity")


def sliding_windows(
    data: pd.DataFrame,
    feature_cols: list[str],
    w: int = 128,
    s: int = 64,
) -> np.ndarray:
    """Verbatim copy of the notebook 11/14 windowing (single-group safe)."""
    windows = []
    for (_sid, _act, _trial), block in data.groupby(
        ["id", "act", "trial"], sort=False
    ):
        v = block[feature_cols].to_numpy()
        for st in range(0, len(v) - w + 1, s):
            windows.append(v[st : st + w])
    return np.array(windows)


def normalize_dyn(x: np.ndarray, eps: float = 1e-8) -> np.ndarray:
    """Verbatim copy of the notebook 11/14 instance Z-score normalization."""
    out = x.copy().astype(np.float32)
    return (out - out.mean(axis=1, keepdims=True)) / (
        out.std(axis=1, keepdims=True) + eps
    )


def build_fixture(act: str, trial: int, sub: int) -> dict:
    csv_path = os.path.join(_DATA_DIR, f"{act}_{trial}", f"sub_{sub}.csv")
    raw = pd.read_csv(csv_path).drop(columns=["Unnamed: 0"])

    # compute_walking_frame_features_v2 groups by (id, act, trial); for a single
    # session these constants put every row in one group, matching how the model
    # was trained (whole-session smoothing context).
    df = raw.copy()
    df["id"] = sub - 1
    df["act"] = ACT_LABELS.index(act)
    df["trial"] = trial

    feats = compute_walking_frame_features_v2(df, fs_hz=50.0, smooth_seconds=5.0)
    windows = sliding_windows(feats, WALKING_FRAME_V2_COLS)
    windows_norm = normalize_dyn(windows)

    return {
        "meta": {
            "source": f"{act}_{trial}/sub_{sub}.csv",
            "input_channel_order": RAW_INPUT_COLS,
            "output_channel_order": WALKING_FRAME_V2_COLS,
            "window_size": 128,
            "step": 64,
            "fs_hz": 50.0,
            "smooth_seconds": 5.0,
            "n_samples": int(len(raw)),
            "n_windows": int(windows_norm.shape[0]),
        },
        "input": raw[RAW_INPUT_COLS].to_numpy().tolist(),
        "windows": windows_norm.astype(float).tolist(),
    }


def main() -> None:
    os.makedirs(_OUT_DIR, exist_ok=True)
    targets = [
        ("wlk", 7, 5),  # walking: normal forward-direction branch
        ("sit", 5, 5),  # sitting: static-fallback branch (mean_dir_norm < 1e-3)
    ]
    for act, trial, sub in targets:
        fixture = build_fixture(act, trial, sub)
        out_path = os.path.join(_OUT_DIR, f"{act}_{trial}_sub_{sub}.json")
        with open(out_path, "w", encoding="utf-8") as fh:
            json.dump(fixture, fh)
        meta = fixture["meta"]
        print(
            f"wrote {out_path}  "
            f"({meta['n_samples']} samples -> {meta['n_windows']} windows)"
        )


if __name__ == "__main__":
    main()
