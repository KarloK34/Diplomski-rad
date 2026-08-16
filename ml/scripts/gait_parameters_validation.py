"""Validates walking speed, step length, and temporal gait parameters (step
time, stride time, cadence CV, regularity) against the 12 hand-counted
sessions used in `step_count_validation.py`.

Ground truth only covers distance and step count, so only speed/step length
are checked numerically; walking speed additionally needs a `wlk`-only
segment (level-gait model), absent/truncated in 5 of 12 sessions where the
HAR model mislabels flat walking as `ups`. `USER_HEIGHT_CM` must match the
real height entered in the app -- step length and speed scale directly with it.

Usage:
    python ml/scripts/gait_parameters_validation.py
"""

from __future__ import annotations

import json
import os
import sys

import numpy as np
import pandas as pd

_ML_DIR = os.path.join(os.path.dirname(__file__), os.pardir)
sys.path.insert(0, os.path.abspath(_ML_DIR))

from utils.gait_cadence_port import (  # noqa: E402
    analyze_gait_cadence_samples,
    analyze_gait_walking_speed,
    extract_cadence_segments,
    extract_level_walking_segments,
    summarize_temporal_parameters,
)

# Local-only script: reads locally-exported session recordings, not part of the
# automated pipeline.
_DOWNLOADS = r"C:\Users\karlo\Downloads"
_REPO_ROOT = os.path.abspath(os.path.join(_ML_DIR, os.pardir))
_OUT_CSV = os.path.join(_REPO_ROOT, "ml", "results", "gait_parameters_validation.csv")

# PLACEHOLDER -- replace with the real height entered in the app.
USER_HEIGHT_CM = 187.0

_MANIFEST = [
    (20, 1, "session_2026-07-22T14-31-33.468306.json", 22, "ED", "normal"),
    (20, 2, "session_2026-07-22T14-35-18.292706.json", 23, "EG", "normal"),
    (20, 3, "session_2026-07-22T14-36-54.077805.json", 22.5, "KD", "normal"),
    (20, 4, "session_2026-07-22T14-38-05.221747.json", 22.5, "KG", "normal"),
    (20, 5, "session_2026-07-22T14-39-41.350716.json", 21, "ED", "brzo"),
    (20, 6, "session_2026-07-22T14-40-42.415662.json", 25, "ED", "sporo"),
    (30, 1, "session_2026-07-22T14-41-56.856929.json", 34, "ED", "normal"),
    (30, 2, "session_2026-07-22T14-43-38.229716.json", 33, "EG", "normal"),
    (30, 3, "session_2026-07-22T14-44-47.287767.json", 33, "KD", "normal"),
    (30, 4, "session_2026-07-22T14-45-55.828701.json", 33, "KG", "normal"),
    (30, 5, "session_2026-07-22T14-47-19.853524.json", 30, "ED", "brzo"),
    (30, 6, "session_2026-07-22T14-48-38.490388.json", 38, "ED", "sporo"),
]


def load_raw(session_json: dict) -> dict[str, np.ndarray]:
    raw = session_json["rawSamples"]
    t = pd.to_datetime([s["timestamp"] for s in raw])
    t_s = (t - t[0]).total_seconds().to_numpy()
    return {
        "t_s": t_s,
        "ux": np.array([s["userAccelerationX"] for s in raw]),
        "uy": np.array([s["userAccelerationY"] for s in raw]),
        "uz": np.array([s["userAccelerationZ"] for s in raw]),
        "rx": np.array([s["rotationRateX"] for s in raw]),
        "ry": np.array([s["rotationRateY"] for s in raw]),
        "rz": np.array([s["rotationRateZ"] for s in raw]),
        "gx": np.array([s["gravityX"] for s in raw]),
        "gy": np.array([s["gravityY"] for s in raw]),
        "gz": np.array([s["gravityZ"] for s in raw]),
    }


def main() -> None:
    rows = []
    for distance_m, order, filename, gt_steps, orientation, pace in _MANIFEST:
        path = os.path.join(_DOWNLOADS, filename)
        with open(path, "r", encoding="utf-8") as fh:
            session_json = json.load(fh)
        raw = load_raw(session_json)
        predictions = session_json["predictions"]

        # --- cadence segments (broad locomotion set) for temporal params ---
        cadence_segments = [
            s for s in extract_cadence_segments(predictions) if s.is_suitable
        ]
        cadence_results = []
        for seg in cadence_segments:
            s0, s1 = seg.start_sample_index, seg.end_sample_index_exclusive
            cadence_results.append(
                analyze_gait_cadence_samples(
                    raw["t_s"][s0:s1], raw["ux"][s0:s1], raw["uy"][s0:s1], raw["uz"][s0:s1],
                    raw["rx"][s0:s1], raw["ry"][s0:s1], raw["rz"][s0:s1],
                )
            )
        temporal = summarize_temporal_parameters(cadence_results)

        total_duration_s = (
            (raw["t_s"][cadence_segments[-1].end_sample_index_exclusive - 1]
             - raw["t_s"][cadence_segments[0].start_sample_index])
            if cadence_segments else float("nan")
        )
        gt_speed_ms = distance_m / total_duration_s if total_duration_s else float("nan")
        gt_step_length_m = distance_m / gt_steps

        # --- wlk-only segments for the level-gait walking-speed model ---
        level_segments = [
            s for s in extract_level_walking_segments(predictions) if s.is_suitable
        ]
        if not level_segments:
            speed_status = "unavailable"
            speed_reason = "no_suitable_wlk_only_segment"
            speed_ms = step_len_m = float("nan")
        else:
            seg = max(level_segments, key=lambda s: s.windows)  # longest, matches app's duration-weighting intent
            s0, s1 = seg.start_sample_index, seg.end_sample_index_exclusive
            cad = analyze_gait_cadence_samples(
                raw["t_s"][s0:s1], raw["ux"][s0:s1], raw["uy"][s0:s1], raw["uz"][s0:s1],
                raw["rx"][s0:s1], raw["ry"][s0:s1], raw["rz"][s0:s1],
            )
            speed_result = analyze_gait_walking_speed(
                raw["t_s"][s0:s1], raw["ux"][s0:s1], raw["uy"][s0:s1], raw["uz"][s0:s1],
                raw["gx"][s0:s1], raw["gy"][s0:s1], raw["gz"][s0:s1],
                cad, USER_HEIGHT_CM,
            )
            speed_status = speed_result.status
            speed_reason = speed_result.reason
            speed_ms = speed_result.walking_speed_ms if speed_result.is_computed else float("nan")
            step_len_m = speed_result.step_length_m if speed_result.is_computed else float("nan")

        rows.append({
            "distance_m": distance_m, "order": order, "session": filename,
            "orientation": orientation, "pace": pace,
            "gt_speed_ms": gt_speed_ms, "gt_step_length_m": gt_step_length_m,
            "n_wlk_only_segments": len(level_segments),
            "speed_status": speed_status, "speed_reason": speed_reason,
            "predicted_speed_ms": speed_ms, "predicted_step_length_m": step_len_m,
            "step_time_mean_s": temporal.mean_step_time_s if temporal else float("nan"),
            "step_time_cv": temporal.step_time_cv if temporal else float("nan"),
            "gait_regularity": temporal.gait_regularity if temporal else float("nan"),
        })

        speed_str = (
            f"{speed_ms:.2f} m/s, step={step_len_m:.2f}m"
            if speed_status == "computed" else f"UNAVAILABLE ({speed_reason})"
        )
        print(
            f"{distance_m:2d}m #{order} {orientation:2s} {pace:6s} "
            f"gt_speed={gt_speed_ms:.2f}m/s gt_step={gt_step_length_m:.2f}m  |  "
            f"predicted: {speed_str}  "
            f"(wlk-only segs={len(level_segments)})  |  "
            f"step_time={temporal.mean_step_time_s:.2f}s CV={temporal.step_time_cv:.2f} "
            f"regularity={temporal.gait_regularity:.2f}" if temporal else "no cadence result"
        )

    out_df = pd.DataFrame(rows)
    os.makedirs(os.path.dirname(_OUT_CSV), exist_ok=True)
    out_df.to_csv(_OUT_CSV, index=False)

    computed = out_df[out_df["speed_status"] == "computed"]
    print(f"\n=== Walking speed/step length: computed for {len(computed)}/12 sessions ===")
    if len(computed):
        speed_err_pct = (
            (computed["predicted_speed_ms"] - computed["gt_speed_ms"]) / computed["gt_speed_ms"] * 100
        )
        step_err_pct = (
            (computed["predicted_step_length_m"] - computed["gt_step_length_m"])
            / computed["gt_step_length_m"] * 100
        )
        print(f"  speed MAPE={speed_err_pct.abs().mean():.1f}%  bias={speed_err_pct.mean():+.1f}%")
        print(f"  step-length MAPE={step_err_pct.abs().mean():.1f}%  bias={step_err_pct.mean():+.1f}%")
    print("\nUnavailable sessions (reason):")
    for _, r in out_df[out_df["speed_status"] != "computed"].iterrows():
        print(f"  {r['session']}: {r['speed_reason']}")

    print(f"\n(NOTE: USER_HEIGHT_CM={USER_HEIGHT_CM} is a placeholder -- rerun with the real height.)")
    print(f"Wrote {_OUT_CSV}")


if __name__ == "__main__":
    main()
