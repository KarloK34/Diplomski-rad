"""Streaming-vs-offline comparison on personal `session_*.json` recordings
exported from the app's `SessionLog`, as a second dataset alongside
`streaming_vs_offline_in_the_wild.py` (curated, labelled scripted recordings).

These exports carry no ground-truth activity label, so this measures
*agreement*, not accuracy, two ways: (1) offline vs streaming recomputed from
the same raw samples, restated on longer everyday-use recordings, and (2)
simulated streaming vs the actual on-device predictions the app recorded live
(`rawLabel`, pre-smoothing argmax) -- a real-device parity check for the
Python simulation in `streaming_offline_compare.py`, which the in-the-wild
study assumed but never verified against a genuine device run.

`rawSamples` are already in iOS-convention units (`SessionLog` persists
post-`SensorConversion` samples), so unlike the in-the-wild Sensor Logger
CSVs, only a column rename is needed here, no Android-to-iOS conversion.

Sessions recorded before commit `f19dc23` (2026-07-17) have every
`endSampleIndex` inflated by a constant probe/countdown offset, because
`StreamingFeatureExtractor.reset()` wasn't yet called at the recording-start
event while `rawSamples` persistence already was; this script detects and
corrects that offset per session (see `recorded_raw_labels`) instead of
mismatching windows or discarding the affected exports.

Ground truth is approximate: the recordings' owner reports each session is a
continuous walk except possibly the first/last few seconds. Windows within
`_BOUNDARY_SECONDS` (3.0 s, comfortably more than one window's 2.56 s span)
of either end are "edge" (transition expected, excluded); the rest are "core"
and expected to read `wlk`.

Usage:
    python ml/scripts/streaming_vs_offline_user_sessions.py <directory> [--pattern session_*.json]
"""

from __future__ import annotations

import argparse
import glob
import json
import os
import sys

import numpy as np
import pandas as pd

_ML_DIR = os.path.join(os.path.dirname(__file__), os.pardir)
sys.path.insert(0, os.path.abspath(_ML_DIR))

from utils.streaming_offline_compare import (
    ACT_LABELS,
    WINDOW_SIZE,
    load_interpreter,
    offline_windows,
    predict,
    streaming_windows,
)

_REPO_ROOT = os.path.abspath(os.path.join(_ML_DIR, os.pardir))
_TFLITE_MODEL = os.path.join(_REPO_ROOT, "models", "cnn_final.tflite")
_OUT_CSV = os.path.join(
    _REPO_ROOT, "ml", "results", "streaming_vs_offline_user_sessions.csv"
)

_BOUNDARY_SECONDS = 3.0
_FS_HZ = 50.0

# SessionLog rawSamples field -> compute_walking_frame_features_v2 column.
_RAW_SAMPLE_COLS = {
    "gravityX": "gravity.x", "gravityY": "gravity.y", "gravityZ": "gravity.z",
    "userAccelerationX": "userAcceleration.x",
    "userAccelerationY": "userAcceleration.y",
    "userAccelerationZ": "userAcceleration.z",
    "rotationRateX": "rotationRate.x",
    "rotationRateY": "rotationRate.y",
    "rotationRateZ": "rotationRate.z",
}


def load_raw_samples(session_json: dict) -> pd.DataFrame:
    raw = session_json["rawSamples"]
    df = pd.DataFrame(raw).rename(columns=_RAW_SAMPLE_COLS)
    # SessionLog doesn't persist attitude; the v2 feature validator requires the
    # column to exist even though the math never reads it -- zero-filled placeholder.
    for col in ("attitude.roll", "attitude.pitch", "attitude.yaw"):
        df[col] = 0.0
    return df[list(_RAW_SAMPLE_COLS.values()) + ["attitude.roll", "attitude.pitch", "attitude.yaw"]]


def core_window_mask(n_samples: int, ends: list[int]) -> list[bool]:
    """True for window end-indices at least `_BOUNDARY_SECONDS` from both ends
    of the recording -- the "core" windows expected to read `wlk`."""
    boundary_samples = _BOUNDARY_SECONDS * _FS_HZ
    return [
        boundary_samples <= e <= (n_samples - 1) - boundary_samples
        for e in ends
    ]


def recorded_raw_labels(session_json: dict) -> tuple[dict[int, str], int]:
    """Maps endSampleIndex -> pre-smoothing argmax label (`rawLabel`) the app
    predicted live. Also returns the detected probe-phase offset.

    A correctly-reset session's first emitted window always ends at local
    index `WINDOW_SIZE - 1` (127); sessions recorded before commit `f19dc23`
    (2026-07-17) inflate every `endSampleIndex` by the pre-recording probe/
    countdown sample count instead (`StreamingFeatureExtractor.reset()` wasn't
    yet called at that point), empirically a constant 256 samples across the
    affected exports here. The difference from 127 is that offset and is
    subtracted so these sessions can still be compared instead of discarded."""
    raw = {
        pr["endSampleIndex"]: pr["rawLabel"]
        for pr in session_json["predictions"]
        if "endSampleIndex" in pr
    }
    if not raw:
        return raw, 0
    offset = min(raw) - (WINDOW_SIZE - 1)
    if offset == 0:
        return raw, 0
    return {k - offset: v for k, v in raw.items()}, offset


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", help="Folder containing session_*.json exports")
    parser.add_argument("--pattern", default="session_*.json")
    args = parser.parse_args()

    paths = sorted(glob.glob(os.path.join(args.directory, args.pattern)))
    if not paths:
        raise SystemExit(f"No files matching {args.pattern!r} in {args.directory}")

    interp = load_interpreter(_TFLITE_MODEL)

    rows = []
    skipped = []
    for path in paths:
        name = os.path.basename(path)
        with open(path, "r", encoding="utf-8") as fh:
            session_json = json.load(fh)

        if not session_json.get("rawSamples"):
            skipped.append(name)
            print(f"{name:<45s} SKIPPED (no rawSamples in export)")
            continue

        df_raw = load_raw_samples(session_json)
        off_w, off_ends = offline_windows(df_raw)
        stream_w, stream_ends = streaming_windows(df_raw)
        assert off_ends == stream_ends, (
            f"{name}: offline/streaming window count mismatch "
            f"({len(off_ends)} vs {len(stream_ends)}) -- emission cadence bug"
        )

        off_pred = predict(interp, off_w)
        stream_pred = predict(interp, stream_w)
        off_labels = [ACT_LABELS[p] for p in off_pred]
        stream_labels = [ACT_LABELS[p] for p in stream_pred]

        recorded, offset = recorded_raw_labels(session_json)
        matched_ends = [e for e in off_ends if e in recorded]
        n_unmatched = len(recorded) - len(matched_ends)
        recorded_at_matched = [recorded[e] for e in matched_ends]
        stream_at_matched = [
            stream_labels[off_ends.index(e)] for e in matched_ends
        ]
        off_at_matched = [off_labels[off_ends.index(e)] for e in matched_ends]

        n = len(off_ends)
        offline_streaming_agreement = float(
            np.mean([a == b for a, b in zip(off_labels, stream_labels)])
        )
        streaming_recorded_agreement = (
            float(np.mean([a == b for a, b in zip(stream_at_matched, recorded_at_matched)]))
            if matched_ends else float("nan")
        )
        offline_recorded_agreement = (
            float(np.mean([a == b for a, b in zip(off_at_matched, recorded_at_matched)]))
            if matched_ends else float("nan")
        )

        core_mask = core_window_mask(len(df_raw), off_ends)
        n_core = sum(core_mask)
        off_core_wlk = (
            float(np.mean([lbl == "wlk" for lbl, c in zip(off_labels, core_mask) if c]))
            if n_core else float("nan")
        )
        stream_core_wlk = (
            float(np.mean([lbl == "wlk" for lbl, c in zip(stream_labels, core_mask) if c]))
            if n_core else float("nan")
        )
        core_by_end = dict(zip(off_ends, core_mask))
        recorded_core = [
            lbl for e, lbl in zip(matched_ends, recorded_at_matched) if core_by_end[e]
        ]
        recorded_core_wlk = (
            float(np.mean([lbl == "wlk" for lbl in recorded_core]))
            if recorded_core else float("nan")
        )

        def majority(labels: list[str]) -> str:
            return pd.Series(labels).mode().iloc[0]

        rows.append(
            {
                "session": name,
                "n_windows": n,
                "endsampleindex_offset_corrected": offset,
                "n_recorded_matched": len(matched_ends),
                "n_recorded_unmatched": n_unmatched,
                "offline_streaming_agreement": offline_streaming_agreement,
                "streaming_recorded_agreement": streaming_recorded_agreement,
                "offline_recorded_agreement": offline_recorded_agreement,
                "offline_majority": majority(off_labels),
                "streaming_majority": majority(stream_labels),
                "recorded_majority": majority(recorded_at_matched) if matched_ends else "",
                "n_core_windows": n_core,
                "n_recorded_core": len(recorded_core),
                "offline_core_wlk_frac": off_core_wlk,
                "streaming_core_wlk_frac": stream_core_wlk,
                "recorded_core_wlk_frac": recorded_core_wlk,
            }
        )
        offset_note = f"  [endSampleIndex offset {offset} corrected -- pre-f19dc23 export]" if offset else ""
        print(
            f"{name:<45s} n={n:3d} core={n_core:3d}  "
            f"offline<->streaming={offline_streaming_agreement*100:5.1f}%  "
            f"streaming<->recorded={streaming_recorded_agreement*100:5.1f}%  "
            f"core-wlk off/stream/rec={off_core_wlk*100:5.1f}%/{stream_core_wlk*100:5.1f}%/"
            f"{recorded_core_wlk*100:5.1f}%  "
            f"(matched={len(matched_ends)}, unmatched={n_unmatched}){offset_note}"
        )

    if not rows:
        print("\nNo sessions had rawSamples -- nothing to compare.")
        return

    out_df = pd.DataFrame(rows).set_index("session")
    os.makedirs(os.path.dirname(_OUT_CSV), exist_ok=True)
    out_df.to_csv(_OUT_CSV)

    weights = out_df["n_windows"].to_numpy()
    off_stream = out_df["offline_streaming_agreement"].to_numpy()
    match_weights = out_df["n_recorded_matched"].to_numpy()
    stream_rec = out_df["streaming_recorded_agreement"].to_numpy()
    off_rec = out_df["offline_recorded_agreement"].to_numpy()

    core_weights = out_df["n_core_windows"].to_numpy()
    off_core_wlk = out_df["offline_core_wlk_frac"].to_numpy()
    stream_core_wlk = out_df["streaming_core_wlk_frac"].to_numpy()
    rec_core_weights = out_df["n_recorded_core"].to_numpy()
    rec_core_wlk = out_df["recorded_core_wlk_frac"].to_numpy()

    print("\n=== Aggregate ===")
    print(f"Sessions compared: {len(rows)}  (skipped, no rawSamples: {len(skipped)})")
    print(f"Total windows: {int(weights.sum())}  (core, >= {_BOUNDARY_SECONDS:.0f}s from either "
          f"edge: {int(core_weights.sum())})")
    print(f"Offline<->streaming agreement (all sessions): "
          f"{np.average(off_stream, weights=weights):.4f}")
    if match_weights.sum() > 0:
        print(f"Streaming<->recorded-on-device agreement (matched windows only, "
              f"n={int(match_weights.sum())}): {np.average(stream_rec, weights=match_weights):.4f}")
        print(f"Offline<->recorded-on-device agreement (matched windows only): "
              f"{np.average(off_rec, weights=match_weights):.4f}")
    print(f"\nApproximate accuracy assuming core windows == 'wlk' (owner-reported, unlabelled):")
    print(f"  Offline core wlk-fraction:    {np.average(off_core_wlk, weights=core_weights):.4f}")
    print(f"  Streaming core wlk-fraction:  {np.average(stream_core_wlk, weights=core_weights):.4f}")
    if rec_core_weights.sum() > 0:
        print(f"  Recorded core wlk-fraction:   "
              f"{np.average(rec_core_wlk, weights=rec_core_weights):.4f}  (n={int(rec_core_weights.sum())})")
    print(f"\nWrote {_OUT_CSV}")


if __name__ == "__main__":
    main()
