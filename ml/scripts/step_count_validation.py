"""Validates the app's step-counting pipeline against 12 hand-counted walking
sessions with known distance (20 m / 30 m) and manually counted steps -- the
first *accuracy* check (not just internal agreement) of the step-counting
math (`gait_cadence.dart` + `gait_segments.dart`'s `defaultLocomotionLabels`
path), unlike `streaming_vs_offline_user_sessions.py`'s unlabelled recordings.

Computes three step-count variants per session via `ml.utils.gait_cadence_port`
(a Python port of the Dart cadence pipeline):

1. `current`: `extractGaitSegments(labels=defaultLocomotionLabels,
   minWindows=5)`, gap_bridge=0 -- what the shipped app computes today.
2. `bridged`: gap_bridge=2 windows -- the proposed gap-tolerant segmentation,
   tested here on controlled straight-line walks rather than the turn-heavy
   recordings that originally motivated it.
3. `loosened_min_windows`: `minWindows=1`, gap_bridge=0 -- isolates the
   >=5-window candidate gate itself as a separate cause of under-count.

Reads the app's own recorded, already-smoothed `label` field per window
rather than re-running the TFLite model, so it measures the shipped pipeline
end-to-end, not a Python reconstruction of the HAR step.

Usage:
    python ml/scripts/step_count_validation.py
"""

from __future__ import annotations

import json
import os
import sys

import numpy as np
import pandas as pd

_ML_DIR = os.path.join(os.path.dirname(__file__), os.pardir)
sys.path.insert(0, os.path.abspath(_ML_DIR))

from utils.gait_cadence_port import total_step_count  # noqa: E402

# Local-only script: reads locally-exported session recordings, not part of the
# automated pipeline.
_DOWNLOADS = r"C:\Users\karlo\Downloads"
_REPO_ROOT = os.path.abspath(os.path.join(_ML_DIR, os.pardir))
_OUT_CSV = os.path.join(_REPO_ROOT, "ml", "results", "step_count_validation.csv")

# distance_m, order, filename, gt_low, gt_high, orientation, pace
# Orientation: ED=ekran-dolje (screen toward thigh, camera down), EG=ekran-gore
# (screen toward thigh, camera up), KD=kamera-dolje (camera toward thigh, down),
# KG=kamera-gore (camera toward thigh, up). Pace: normal unless brzo/sporo.
_MANIFEST = [
    (20, 1, "session_2026-07-22T14-31-33.468306.json", 22, 22, "ED", "normal"),
    (20, 2, "session_2026-07-22T14-35-18.292706.json", 23, 23, "EG", "normal"),
    (20, 3, "session_2026-07-22T14-36-54.077805.json", 22, 23, "KD", "normal"),
    (20, 4, "session_2026-07-22T14-38-05.221747.json", 22, 23, "KG", "normal"),
    (20, 5, "session_2026-07-22T14-39-41.350716.json", 21, 21, "ED", "brzo"),
    (20, 6, "session_2026-07-22T14-40-42.415662.json", 25, 25, "ED", "sporo"),
    (30, 1, "session_2026-07-22T14-41-56.856929.json", 34, 34, "ED", "normal"),
    (30, 2, "session_2026-07-22T14-43-38.229716.json", 33, 33, "EG", "normal"),
    (30, 3, "session_2026-07-22T14-44-47.287767.json", 33, 33, "KD", "normal"),
    (30, 4, "session_2026-07-22T14-45-55.828701.json", 33, 33, "KG", "normal"),
    (30, 5, "session_2026-07-22T14-47-19.853524.json", 30, 30, "ED", "brzo"),
    (30, 6, "session_2026-07-22T14-48-38.490388.json", 38, 38, "ED", "sporo"),
]


def load_raw_samples(session_json: dict) -> dict[str, np.ndarray]:
    raw = session_json["rawSamples"]
    t = pd.to_datetime([s["timestamp"] for s in raw])
    t0 = t[0]
    t_s = (t - t0).total_seconds().to_numpy()
    return {
        "t_s": t_s,
        "ux": np.array([s["userAccelerationX"] for s in raw]),
        "uy": np.array([s["userAccelerationY"] for s in raw]),
        "uz": np.array([s["userAccelerationZ"] for s in raw]),
        "rx": np.array([s["rotationRateX"] for s in raw]),
        "ry": np.array([s["rotationRateY"] for s in raw]),
        "rz": np.array([s["rotationRateZ"] for s in raw]),
    }


def gt_error(predicted: int, gt_low: int, gt_high: int) -> tuple[float, float]:
    """Signed error against the nearest ground-truth bound (0 if inside
    [gt_low, gt_high]), and the same error as % of the range midpoint."""
    if gt_low <= predicted <= gt_high:
        signed = 0.0
    elif predicted < gt_low:
        signed = float(predicted - gt_low)
    else:
        signed = float(predicted - gt_high)
    midpoint = (gt_low + gt_high) / 2
    pct = 100.0 * signed / midpoint if midpoint else float("nan")
    return signed, pct


def main() -> None:
    rows = []
    for distance_m, order, filename, gt_low, gt_high, orientation, pace in _MANIFEST:
        path = os.path.join(_DOWNLOADS, filename)
        with open(path, "r", encoding="utf-8") as fh:
            session_json = json.load(fh)

        raw = load_raw_samples(session_json)
        predictions = session_json["predictions"]
        label_counts: dict[str, int] = {}
        for p in predictions:
            label_counts[p["label"]] = label_counts.get(p["label"], 0) + 1

        current, current_results, current_segments = total_step_count(
            raw, predictions, min_windows=5, gap_bridge_windows=0
        )
        bridged, _, bridged_segments = total_step_count(
            raw, predictions, min_windows=5, gap_bridge_windows=2
        )
        loosened, _, loosened_segments = total_step_count(
            raw, predictions, min_windows=1, gap_bridge_windows=0
        )

        current_err, current_pct = gt_error(current, gt_low, gt_high)
        bridged_err, bridged_pct = gt_error(bridged, gt_low, gt_high)
        loosened_err, loosened_pct = gt_error(loosened, gt_low, gt_high)

        n_suitable_current = sum(1 for s in current_segments if s.is_suitable)
        n_suitable_bridged = sum(1 for s in bridged_segments if s.is_suitable)
        n_computed_current = sum(1 for r in current_results if r.is_computed)

        rows.append(
            {
                "distance_m": distance_m,
                "order": order,
                "session": filename,
                "orientation": orientation,
                "pace": pace,
                "gt_low": gt_low,
                "gt_high": gt_high,
                "gt_mid": (gt_low + gt_high) / 2,
                "predicted_current": current,
                "error_current": current_err,
                "error_pct_current": current_pct,
                "predicted_bridged_gap2": bridged,
                "error_bridged_gap2": bridged_err,
                "error_pct_bridged_gap2": bridged_pct,
                "predicted_loosened_minw1": loosened,
                "error_loosened_minw1": loosened_err,
                "error_pct_loosened_minw1": loosened_pct,
                "n_suitable_segments_current": n_suitable_current,
                "n_suitable_segments_bridged": n_suitable_bridged,
                "n_computed_cadence_results": n_computed_current,
                "dominant_label": max(label_counts, key=label_counts.get),
                "label_counts": label_counts,
            }
        )

        gt_str = f"{gt_low}" if gt_low == gt_high else f"{gt_low}-{gt_high}"
        print(
            f"{distance_m:2d}m #{order} {orientation:2s} {pace:6s} "
            f"gt={gt_str:6s} current={current:3d} (err {current_err:+.0f}, {current_pct:+.1f}%)  "
            f"bridged={bridged:3d} (err {bridged_err:+.0f})  "
            f"minw1={loosened:3d} (err {loosened_err:+.0f})  "
            f"segs(cur/bridged)={n_suitable_current}/{n_suitable_bridged}  "
            f"labels={label_counts}"
        )

    out_df = pd.DataFrame(rows)
    os.makedirs(os.path.dirname(_OUT_CSV), exist_ok=True)
    out_df.to_csv(_OUT_CSV, index=False)

    def summarize(col_err: str, col_pct: str, name: str) -> None:
        mae = out_df[col_err].abs().mean()
        mape = out_df[col_pct].abs().mean()
        bias = out_df[col_err].mean()
        n_exact = int((out_df[col_err] == 0).sum())
        print(
            f"  {name:22s} MAE={mae:.2f} steps  MAPE={mape:.1f}%  "
            f"bias={bias:+.2f} steps  exact/within-range={n_exact}/{len(out_df)}"
        )

    print("\n=== Aggregate (all 12 sessions) ===")
    summarize("error_current", "error_pct_current", "current (shipped)")
    summarize("error_bridged_gap2", "error_pct_bridged_gap2", "gap-bridge <=2 windows")
    summarize("error_loosened_minw1", "error_pct_loosened_minw1", "minWindows=1")

    print("\n=== By orientation (normal pace only, n=4 distances x 2 = 8) ===")
    normal = out_df[out_df["pace"] == "normal"]
    for orientation, group in normal.groupby("orientation"):
        mae = group["error_current"].abs().mean()
        bias = group["error_current"].mean()
        print(
            f"  {orientation}: MAE={mae:.2f} steps, bias={bias:+.2f}, n={len(group)}, "
            f"sessions={list(group['session'])}"
        )

    print("\n=== By pace (ED orientation only) ===")
    ed = out_df[out_df["orientation"] == "ED"]
    for pace, group in ed.groupby("pace"):
        mae = group["error_current"].abs().mean()
        bias = group["error_current"].mean()
        print(f"  {pace:6s}: MAE={mae:.2f} steps, bias={bias:+.2f}, n={len(group)}")

    print("\n=== Sessions where the model never/rarely predicted 'wlk' ===")
    for row in rows:
        wlk_frac = row["label_counts"].get("wlk", 0) / sum(row["label_counts"].values())
        if wlk_frac < 0.3:
            print(
                f"  {row['session']}: wlk-fraction={wlk_frac:.2f}, "
                f"dominant={row['dominant_label']}, labels={row['label_counts']}"
            )

    print(f"\nWrote {_OUT_CSV}")


if __name__ == "__main__":
    main()
