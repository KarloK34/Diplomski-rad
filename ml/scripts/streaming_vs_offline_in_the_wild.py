"""Measures the accuracy gap between the offline (whole-session, non-causal)
feature pipeline used for training/eval and the causal approximation
`StreamingFeatureExtractor` uses for live on-device inference -- a gap
`docs/tehnicko-objasnjenje-analize-hoda.md` §3.5/§13.3 flags as never measured
(the flagship in-the-wild numbers in `final_in_the_wild.csv` were computed
with the offline pipeline only).

Re-runs the 12 labelled Android recordings (`data/in_the_wild/labels.csv`)
through both paths with the same TFLite model, reporting offline vs streaming
window-/session-accuracy and their per-window agreement. `load_session` is
copied verbatim from notebook 14 so any measured difference is attributable
only to the causal-vs-non-causal windowing, not a divergent loader; the window
recomputation itself lives in `ml/utils/streaming_offline_compare.py`, shared
with `streaming_vs_offline_user_sessions.py`.

Run from the repo root:
    python ml/scripts/streaming_vs_offline_in_the_wild.py
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

import numpy as np
import pandas as pd

_ML_DIR = os.path.join(os.path.dirname(__file__), os.pardir)
sys.path.insert(0, os.path.abspath(_ML_DIR))

from utils.streaming_offline_compare import (
    ACT_LABELS,
    load_interpreter,
    offline_windows,
    predict,
    streaming_windows,
)

_REPO_ROOT = os.path.abspath(os.path.join(_ML_DIR, os.pardir))
_DATA_DIR = os.path.join(_REPO_ROOT, "data")
_TFLITE_MODEL = os.path.join(_REPO_ROOT, "models", "cnn_final.tflite")
_OUT_CSV = os.path.join(_REPO_ROOT, "ml", "results", "streaming_vs_offline_in_the_wild.csv")

G = 9.80665


def load_session(session_dir: str) -> pd.DataFrame:
    """Verbatim copy of `load_session` in notebook 14 §9 (Sensor Logger CSVs ->
    iOS-convention 12-channel DataFrame)."""
    base = Path(_DATA_DIR) / session_dir
    df_ori = pd.read_csv(base / "Orientation.csv").sort_values("time")
    df_grav = pd.read_csv(base / "Gravity.csv").sort_values("time")
    df_gyr = pd.read_csv(base / "Gyroscope.csv").sort_values("time")
    df_tot = pd.read_csv(base / "TotalAcceleration.csv").sort_values("time")
    df = pd.merge_asof(
        df_ori[["time", "roll", "pitch", "yaw"]],
        df_grav[["time", "x", "y", "z"]],
        on="time",
        suffixes=("", "_grav"),
    )
    df = pd.merge_asof(
        df, df_gyr[["time", "x", "y", "z"]], on="time", suffixes=("", "_gyro")
    )
    df = pd.merge_asof(
        df, df_tot[["time", "x", "y", "z"]], on="time", suffixes=("", "_tot_acc")
    )
    df.columns = [
        "time", "attitude.roll", "attitude.pitch", "attitude.yaw",
        "raw_gravity.x", "raw_gravity.y", "raw_gravity.z",
        "rotationRate.x", "rotationRate.y", "rotationRate.z",
        "raw_total_acc.x", "raw_total_acc.y", "raw_total_acc.z",
    ]
    df["time_dt"] = pd.to_datetime(df["time"])
    df = (
        df.set_index("time_dt")
        .resample("20ms")
        .mean(numeric_only=True)
        .interpolate(method="linear")
        .reset_index(drop=True)
    )
    df["raw_linear_acc.x"] = df["raw_total_acc.x"] - df["raw_gravity.x"]
    df["raw_linear_acc.y"] = df["raw_total_acc.y"] - df["raw_gravity.y"]
    df["raw_linear_acc.z"] = df["raw_total_acc.z"] - df["raw_gravity.z"]
    df["gravity.x"] = -df["raw_gravity.x"] / G
    df["gravity.y"] = -df["raw_gravity.y"] / G
    df["gravity.z"] = -df["raw_gravity.z"] / G
    df["userAcceleration.x"] = -df["raw_linear_acc.x"] / G
    df["userAcceleration.y"] = -df["raw_linear_acc.y"] / G
    df["userAcceleration.z"] = -df["raw_linear_acc.z"] / G
    df["attitude.pitch"] = -df["attitude.pitch"]
    df["attitude.yaw"] = -df["attitude.yaw"]
    df["attitude.yaw"] = df["attitude.yaw"] - df["attitude.yaw"].iloc[0]
    cols = [
        "attitude.roll", "attitude.pitch", "attitude.yaw",
        "gravity.x", "gravity.y", "gravity.z",
        "rotationRate.x", "rotationRate.y", "rotationRate.z",
        "userAcceleration.x", "userAcceleration.y", "userAcceleration.z",
    ]
    return df[cols].iloc[150:-150].reset_index(drop=True)


def main() -> None:
    labels_df = pd.read_csv(
        os.path.join(_DATA_DIR, "in_the_wild", "labels.csv")
    ).set_index("session_dir")

    interp = load_interpreter(_TFLITE_MODEL)

    rows = []
    for session, row in labels_df.iterrows():
        df_raw = load_session(session)
        gt = int(row["activity_id"])

        off_w, off_ends = offline_windows(df_raw)
        stream_w, stream_ends = streaming_windows(df_raw)
        assert off_ends == stream_ends, (
            f"{session}: offline/streaming window count mismatch "
            f"({len(off_ends)} vs {len(stream_ends)}) -- emission cadence bug"
        )

        off_pred = predict(interp, off_w)
        stream_pred = predict(interp, stream_w)

        rows.append(
            {
                "session": session,
                "orientation": row["pocket_orientation"],
                "true": ACT_LABELS[gt],
                "n_windows": len(off_pred),
                "offline_correct_frac": float((off_pred == gt).mean()),
                "streaming_correct_frac": float((stream_pred == gt).mean()),
                "offline_streaming_agreement": float((off_pred == stream_pred).mean()),
                "offline_majority": ACT_LABELS[np.bincount(off_pred, minlength=6).argmax()],
                "streaming_majority": ACT_LABELS[np.bincount(stream_pred, minlength=6).argmax()],
            }
        )
        print(
            f"{session:<10s} gt={ACT_LABELS[gt]:<4s} "
            f"offline={rows[-1]['offline_correct_frac']*100:5.1f}%  "
            f"streaming={rows[-1]['streaming_correct_frac']*100:5.1f}%  "
            f"agreement={rows[-1]['offline_streaming_agreement']*100:5.1f}%  "
            f"(n={rows[-1]['n_windows']})"
        )

    out_df = pd.DataFrame(rows).set_index("session")
    os.makedirs(os.path.dirname(_OUT_CSV), exist_ok=True)
    out_df.to_csv(_OUT_CSV)

    weights = out_df["n_windows"].to_numpy()
    off_fracs = out_df["offline_correct_frac"].to_numpy()
    stream_fracs = out_df["streaming_correct_frac"].to_numpy()
    agreement = out_df["offline_streaming_agreement"].to_numpy()

    off_win_acc = float(np.average(off_fracs, weights=weights))
    stream_win_acc = float(np.average(stream_fracs, weights=weights))
    off_sess_acc = float((off_fracs > 0.5).mean())
    stream_sess_acc = float((stream_fracs > 0.5).mean())
    overall_agreement = float(np.average(agreement, weights=weights))

    print("\n=== Aggregate ===")
    print(f"Offline    window-acc={off_win_acc:.4f}  session-acc={off_sess_acc:.4f}  "
          f"(reference: final_in_the_wild.csv reports 0.7417 / 0.8333)")
    print(f"Streaming  window-acc={stream_win_acc:.4f}  session-acc={stream_sess_acc:.4f}")
    print(f"Delta (offline - streaming): window-acc={off_win_acc - stream_win_acc:+.4f}  "
          f"session-acc={off_sess_acc - stream_sess_acc:+.4f}")
    print(f"Offline<->streaming per-window agreement (same window, both paths): "
          f"{overall_agreement:.4f}")
    print(f"\nWrote {_OUT_CSV}")


if __name__ == "__main__":
    main()
