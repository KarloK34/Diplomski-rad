"""Export numerical-parity fixtures for the Dart walking-frame v2 pipeline.

Writes 3 fixture families per MotionSense session, sharing the same raw
9-channel ``input`` block (gravity, userAcceleration, rotationRate, iOS
CoreMotion convention):

1. ``<name>.json`` -- offline path (whole-session
   ``compute_walking_frame_features_v2`` -> ``sliding_windows`` ->
   ``normalize_dyn``), validated by ``test/feature_pipeline_test.dart``.
2. ``<name>.streaming.json`` -- causal on-device path via
   ``utils.streaming_offline_compare.streaming_windows``, validated by
   ``test/feature_pipeline_streaming_parity_test.dart``.
3. ``<name>.infer.json`` -- offline windows plus expected TFLite output,
   for ``integration_test/``.

``app/lib/services/feature_pipeline.dart`` must reproduce every fixture to
< 1e-4 max absolute error. Walking (``wlk_7/sub_5``) exercises the normal
branch; static (``sit_5/sub_5``) covers the low-amplitude ``smooth_norm <
eps`` guard but not the rarer block-level ``mean_dir_norm < 1e-3`` fallback
(``sit_5/sub_23`` would cover that if a dedicated fixture is ever added).

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
from utils.streaming_offline_compare import CONTEXT_SAMPLES, streaming_windows

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
_TFLITE_MODEL = os.path.join(_REPO_ROOT, "models", "cnn_final.tflite")

# Truncation for the on-device inference fixtures. The full-session fixtures are
# 4-8 MB each (they store every window); an on-device test must bundle its data
# as an app asset, so the inference fixtures are truncated to a short prefix.
# Parity holds regardless of length because Dart and Python see the *same* input
# block -- the comparison is Dart==Python, not a match to a "complete" session.
# 768 samples (15.36 s @ 50 Hz) -> (768-128)//64 + 1 = 11 windows per session,
# enough to exercise both branches and give a meaningful per-window agreement.
_INFER_MAX_SAMPLES = 768

# Truncation for the streaming fixtures. Lossless here (unlike the offline
# path): the causal path never looks back further than CONTEXT_SAMPLES, so a
# prefix produces bit-identical windows to the full session. 768 samples
# covers the whole buffer ramp (128 -> 192 -> 256 -> 320 -> 378) plus six
# steady-state windows -- the range where a regression would show first.
_STREAMING_MAX_SAMPLES = 768


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


def build_streaming_fixture(act: str, trial: int, sub: int) -> dict:
    """Fixture for the causal live path (`StreamingFeatureExtractor`).

    Delegates to ``utils.streaming_offline_compare.streaming_windows``, the
    same causal replay used by ``streaming_vs_offline_in_the_wild.py`` and
    ``streaming_vs_offline_user_sessions.py``, so feeding the Dart extractor
    the same ``input`` sample by sample must reproduce ``windows`` and
    ``end_sample_indices`` exactly. Normalizes in float64 (matching the live
    Dart path) rather than float32 as the offline fixture does; the 1e-4
    tolerance covers the difference either way.
    """
    csv_path = os.path.join(_DATA_DIR, f"{act}_{trial}", f"sub_{sub}.csv")
    raw = (
        pd.read_csv(csv_path)
        .drop(columns=["Unnamed: 0"])
        .iloc[:_STREAMING_MAX_SAMPLES]
        .reset_index(drop=True)
    )

    windows, ends = streaming_windows(raw)

    return {
        "meta": {
            "source": f"{act}_{trial}/sub_{sub}.csv",
            "path": "streaming",
            "input_channel_order": RAW_INPUT_COLS,
            "output_channel_order": WALKING_FRAME_V2_COLS,
            "window_size": 128,
            "step": 64,
            "fs_hz": 50.0,
            "smooth_seconds": 5.0,
            "context_samples": int(CONTEXT_SAMPLES),
            "truncated_to_samples": int(len(raw)),
            "n_windows": int(windows.shape[0]),
        },
        "input": raw[RAW_INPUT_COLS].to_numpy().tolist(),
        "windows": windows.astype(float).tolist(),
        "end_sample_indices": [int(i) for i in ends],
    }


def _tflite_probabilities(windows_norm: np.ndarray) -> np.ndarray:
    """Runs cnn_final.tflite over normalized windows, returning the [n, 6]
    softmax outputs. Mirrors the interpreter call in notebook 14 exactly
    (single FP32 input per window, ``get_tensor`` of the output), so the Dart
    on-device interpreter is validated against the same numbers the model was
    evaluated with."""
    import tensorflow as tf  # local import: full-session fixtures don't need TF

    interp = tf.lite.Interpreter(model_path=_TFLITE_MODEL)
    interp.allocate_tensors()
    in_idx = interp.get_input_details()[0]["index"]
    out_idx = interp.get_output_details()[0]["index"]
    probs = np.zeros((len(windows_norm), len(ACT_LABELS)), dtype=np.float32)
    for i, w in enumerate(windows_norm):
        interp.set_tensor(in_idx, w[None].astype(np.float32))
        interp.invoke()
        probs[i] = interp.get_tensor(out_idx)[0]
    return probs


def build_inference_fixture(act: str, trial: int, sub: int) -> dict:
    """Small fixture for the Dart on-device inference parity test: a truncated
    raw-input prefix plus the expected normalized windows AND the expected
    TFLite probabilities/labels. The device test re-runs the Dart pipeline +
    interpreter on this input and must match both."""
    csv_path = os.path.join(_DATA_DIR, f"{act}_{trial}", f"sub_{sub}.csv")
    raw = (
        pd.read_csv(csv_path)
        .drop(columns=["Unnamed: 0"])
        .iloc[:_INFER_MAX_SAMPLES]
        .reset_index(drop=True)
    )

    df = raw.copy()
    df["id"] = sub - 1
    df["act"] = ACT_LABELS.index(act)
    df["trial"] = trial

    feats = compute_walking_frame_features_v2(df, fs_hz=50.0, smooth_seconds=5.0)
    windows = sliding_windows(feats, WALKING_FRAME_V2_COLS)
    windows_norm = normalize_dyn(windows)
    probs = _tflite_probabilities(windows_norm)
    pred = probs.argmax(axis=1)

    return {
        "meta": {
            "source": f"{act}_{trial}/sub_{sub}.csv",
            "input_channel_order": RAW_INPUT_COLS,
            "output_channel_order": WALKING_FRAME_V2_COLS,
            "class_labels": ACT_LABELS,
            "window_size": 128,
            "step": 64,
            "fs_hz": 50.0,
            "smooth_seconds": 5.0,
            "truncated_to_samples": int(len(raw)),
            "n_windows": int(windows_norm.shape[0]),
        },
        "input": raw[RAW_INPUT_COLS].to_numpy().tolist(),
        "windows": windows_norm.astype(float).tolist(),
        "probabilities": probs.astype(float).tolist(),
        "pred_labels": pred.astype(int).tolist(),
        "pred_label_names": [ACT_LABELS[i] for i in pred],
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

    # Causal (on-device) path fixtures. Written before the inference fixtures so
    # that a missing TensorFlow install still leaves both TF-free families on
    # disk.
    for act, trial, sub in targets:
        fixture = build_streaming_fixture(act, trial, sub)
        out_path = os.path.join(
            _OUT_DIR, f"{act}_{trial}_sub_{sub}.streaming.json"
        )
        with open(out_path, "w", encoding="utf-8") as fh:
            json.dump(fixture, fh)
        meta = fixture["meta"]
        print(
            f"wrote {out_path}  "
            f"({meta['truncated_to_samples']} samples -> {meta['n_windows']} "
            f"windows; context {meta['context_samples']} samples)"
        )

    # On-device inference fixtures (truncated; carry expected TFLite outputs).
    for act, trial, sub in targets:
        fixture = build_inference_fixture(act, trial, sub)
        out_path = os.path.join(_OUT_DIR, f"{act}_{trial}_sub_{sub}.infer.json")
        with open(out_path, "w", encoding="utf-8") as fh:
            json.dump(fixture, fh)
        meta = fixture["meta"]
        labels = "".join(str(x) for x in fixture["pred_labels"])
        print(
            f"wrote {out_path}  "
            f"({meta['truncated_to_samples']} samples -> {meta['n_windows']} "
            f"windows; pred argmax per window: {labels})"
        )


if __name__ == "__main__":
    main()
