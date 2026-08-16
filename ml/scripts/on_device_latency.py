"""On-device inference latency from the app's own session logs -- what ZM-4
("classification of one window on-device must finish before the next window
step") actually requires, unlike notebook 14 §6's desktop `tf.lite.Interpreter`
benchmark (0.05 ms mean), which doesn't cover the real phone CPU, the
background-isolate hop, or the platform-channel round trip.

Aggregates `inferenceLatencyMs`, already measured per prediction by
`HarInference.predict` (`Stopwatch`) and persisted in `session_*.json` by
`SessionLog`. The budget is one window step: 64 samples @ 50 Hz = 1.28 s. The
first prediction of each session is reported separately (interpreter warm-up,
not steady state). `Stopwatch.elapsedMilliseconds` truncates to whole ms, so a
reported 0 means "under 1 ms", and the mean should be read as +/- 0.5 ms.

Usage:
    python ml/scripts/on_device_latency.py <directory> [--pattern session_*.json]

Outputs:
    ml/results/on_device_inference_latency.csv          (per session)
    ml/results/on_device_inference_latency_summary.csv  (pooled)
"""

from __future__ import annotations

import argparse
import glob
import json
import os

import numpy as np
import pandas as pd

_ML_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), os.pardir)
_RESULTS_DIR = os.path.abspath(os.path.join(_ML_DIR, "results"))

FS_HZ = 50.0
STEP = 64
STEP_BUDGET_MS = STEP / FS_HZ * 1000.0  # 1280 ms -- the ZM-4 budget


def summarise(values: np.ndarray) -> dict:
    return {
        "n": int(values.size),
        "mean_ms": float(values.mean()),
        "median_ms": float(np.median(values)),
        "p95_ms": float(np.percentile(values, 95)),
        "p99_ms": float(np.percentile(values, 99)),
        "max_ms": int(values.max()),
        "min_ms": int(values.min()),
    }


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("directory", help="folder holding the exported session_*.json files")
    ap.add_argument("--pattern", default="session_*.json")
    args = ap.parse_args()

    paths = sorted(glob.glob(os.path.join(args.directory, args.pattern)))
    if not paths:
        raise SystemExit(f"no files matching {args.pattern} in {args.directory}")

    rows, first_of_session, steady_state, everything = [], [], [], []
    for path in paths:
        with open(path, encoding="utf-8") as fh:
            session = json.load(fh)
        latencies = [p["inferenceLatencyMs"] for p in session.get("predictions") or []
                     if "inferenceLatencyMs" in p]
        if not latencies:
            continue
        values = np.array(latencies)
        first_of_session.append(latencies[0])
        steady_state.extend(latencies[1:])
        everything.extend(latencies)
        rows.append({
            "session": os.path.basename(path),
            "startedAt": session.get("startedAt"),
            "deviceId": session.get("deviceId"),
            **summarise(values),
            "first_ms": latencies[0],
        })

    steady = np.array(steady_state)
    allv = np.array(everything)
    firsts = np.array(first_of_session)

    subsets = [
        ("all predictions", allv),
        ("steady state (first of session excluded)", steady),
        ("first prediction of each session (warm-up)", firsts),
    ]
    summary = [
        {
            "subset": name,
            **summarise(values),
            "budget_ms": STEP_BUDGET_MS,
            "frac_within_budget": float(np.mean(values < STEP_BUDGET_MS)),
        }
        for name, values in subsets
    ]

    os.makedirs(_RESULTS_DIR, exist_ok=True)
    per_session = pd.DataFrame(rows)
    summary_df = pd.DataFrame(summary)
    per_session.to_csv(os.path.join(_RESULTS_DIR, "on_device_inference_latency.csv"), index=False)
    summary_df.to_csv(os.path.join(_RESULTS_DIR, "on_device_inference_latency_summary.csv"), index=False)

    print(f"{len(rows)} sessions, {allv.size} predictions")
    print(summary_df.round(3).to_string(index=False))
    print(f"\nZM-4 budget (window step, {STEP} samples @ {FS_HZ:g} Hz): {STEP_BUDGET_MS:.0f} ms")
    print(f"slowest single inference observed: {allv.max()} ms "
          f"({STEP_BUDGET_MS / allv.max():.0f}x margin)")
    counts = pd.Series(steady).value_counts().sort_index()
    print("\nsteady-state distribution (ms: count):")
    print(counts.to_string())
    print(f"\nsaved -> ml/results/on_device_inference_latency.csv (+ _summary.csv)")


if __name__ == "__main__":
    main()
