"""Candidate replacements for `_estimate_dominant_period` (`gait_cadence_port.py`,
mirroring `gait_cadence.dart`), tested against the fast-pace step-undercounting
bug (see `cadence_period_diagnostics.py`). Not shipped -- scored by
`cadence_fix_candidates_validation.py` against the 12 ground-truth sessions
before any candidate is proposed for `gait_cadence.dart`.

Each candidate shares `_estimate_dominant_period`'s signature and reuses the
app's `MIN_CADENCE_SPM`/`MAX_CADENCE_SPM` search bounds, so the comparison
isolates the selection rule rather than the search range.
"""

from __future__ import annotations

import math

import numpy as np

from utils.gait_cadence_port import MAX_CADENCE_SPM, MIN_CADENCE_SPM


def _lag_bounds(n: int, dt: float) -> tuple[int, int] | None:
    min_period_s = 60.0 / MAX_CADENCE_SPM
    max_period_s = 60.0 / MIN_CADENCE_SPM
    min_lag = max(2, math.ceil(min_period_s / dt))
    max_lag = min(n - 2, math.floor(max_period_s / dt))
    if max_lag <= min_lag:
        return None
    return min_lag, max_lag


def current_autocorrelation(values: np.ndarray, dt: float, ratio: float = 0.7):
    """Reproduces `_estimate_dominant_period` verbatim (the shipped rule),
    used as the baseline candidates are compared against."""
    result = current_autocorrelation_with_flag(values, dt, ratio=ratio)
    if result is None:
        return None
    period_s, periodicity, _is_boundary = result
    return period_s, periodicity


def current_autocorrelation_with_flag(values: np.ndarray, dt: float, ratio: float = 0.7):
    """Same as `current_autocorrelation`, but also reports whether the selected
    lag came from the search-window boundary rule (`best_lag == max_lag`,
    correlation still rising there, i.e. never peaked inside the searched
    range). `cross_signal_boundary_aware` tests this flag as a cross-signal
    arbitration signal -- see cadence_period_diagnostics.py."""
    n = len(values)
    bounds = _lag_bounds(n, dt)
    if bounds is None:
        return None
    min_lag, max_lag = bounds
    mean = float(np.mean(values))
    centered = values - mean
    correlations = {}
    for lag in range(min_lag, max_lag + 1):
        left = centered[: n - lag]
        right = centered[lag:]
        norm = math.sqrt(float(np.dot(left, left)) * float(np.dot(right, right)))
        correlations[lag] = 0.0 if norm <= 0 else float(np.dot(left, right)) / norm
    local_maxima = []
    for lag in range(min_lag + 1, max_lag):
        prev, cur, nxt = correlations[lag - 1], correlations[lag], correlations[lag + 1]
        if cur > prev and cur >= nxt:
            local_maxima.append((lag, cur))
    boundary_added = correlations[max_lag] > correlations[max_lag - 1]
    if boundary_added:
        local_maxima.append((max_lag, correlations[max_lag]))
    preferred = [(l, v) for l, v in local_maxima if math.isfinite(v) and v > 0]
    usable = preferred or [(l, v) for l, v in correlations.items() if math.isfinite(v) and v > 0]
    if not usable:
        return None
    strongest = max(v for _, v in usable)
    comparable = strongest * ratio
    candidates = [(l, v) for l, v in usable if v >= comparable]
    best_lag, best_corr = min(candidates, key=lambda lv: lv[0])
    is_boundary_artifact = boundary_added and best_lag == max_lag
    return dt * best_lag, min(max(best_corr, 0.0), 1.0), is_boundary_artifact


def yin_cmndf(values: np.ndarray, dt: float, absolute_threshold: float = 0.1):
    """YIN's cumulative mean normalized difference function (de Cheveigne &
    Kawahara, 2002, "YIN, a fundamental frequency estimator for speech and
    music," J. Acoust. Soc. Am. 111(4), DOI 10.1121/1.1458024), restricted to
    this app's cadence-derived lag search range.

    d(tau) = sum_j (x(j) - x(j+tau))^2 over the valid overlap
    d'(tau) = d(tau) / ((1/tau) * sum_{j=1..tau} d(j)),  d'(0) = 1

    Unlike the shipped rule (shortest lag within 0.7x of the strongest
    correlation), YIN walks lags from the shortest and accepts the first
    local minimum below a fixed absolute threshold (paper recommends
    ~0.1-0.15), falling back to the global minimum otherwise. This rejects
    deep-but-not-near-zero long-lag minima, which is the shipped rule's
    observed failure mode (see cadence_period_diagnostics.py): a relative
    ratio test lets a still-rising boundary correlation out-rank a genuine
    short-lag peak, while an absolute threshold does not.

    Confidence proxy `1 - clamp(d'(tau), 0, 1)` is a project construct for
    this candidate, not part of the YIN paper.
    """
    n = len(values)
    bounds = _lag_bounds(n, dt)
    if bounds is None:
        return None
    min_lag, max_lag = bounds

    max_tau_needed = max_lag + 1
    d = np.zeros(max_tau_needed + 1)
    for tau in range(1, max_tau_needed + 1):
        diff = values[: n - tau] - values[tau:]
        d[tau] = float(np.dot(diff, diff))

    cmndf = np.ones(max_tau_needed + 1)
    running_sum = 0.0
    for tau in range(1, max_tau_needed + 1):
        running_sum += d[tau]
        cmndf[tau] = d[tau] if running_sum <= 0 else d[tau] * tau / running_sum

    search = {tau: cmndf[tau] for tau in range(min_lag, max_lag + 1)}
    local_minima = []
    for tau in range(min_lag + 1, max_lag):
        prev, cur, nxt = search[tau - 1], search[tau], search[tau + 1]
        if cur < prev and cur <= nxt:
            local_minima.append(tau)
    if not local_minima:
        best_tau = min(search, key=search.get)
    else:
        below_threshold = [tau for tau in local_minima if search[tau] < absolute_threshold]
        best_tau = min(below_threshold) if below_threshold else min(local_minima, key=lambda t: search[t])

    best_val = search[best_tau]
    confidence = 1.0 - min(max(best_val, 0.0), 1.0)
    return dt * best_tau, confidence


def multiwindow_median(
    values: np.ndarray,
    dt: float,
    window_s: float = 4.0,
    step_s: float = 2.0,
    ratio: float = 0.7,
):
    """Runs the shipped autocorrelation rule (`current_autocorrelation`) on
    overlapping sub-windows and takes the median selected period.

    Project construct, not from literature: a full-segment autocorrelation
    run can be dominated by a boundary artifact while a shorter, locally
    stationary sub-window sometimes recovers the real step-period peak
    (`cadence_stationarity_check.py`). Confidence proxy is the fraction of
    windows agreeing with the median lag within +-2 samples.
    """
    n = len(values)
    window_n = int(round(window_s / dt))
    step_n = max(1, int(round(step_s / dt)))
    if n < window_n:
        return current_autocorrelation(values, dt, ratio=ratio)

    periods = []
    for start in range(0, n - window_n + 1, step_n):
        sub = values[start : start + window_n]
        result = current_autocorrelation(sub, dt, ratio=ratio)
        if result is not None:
            periods.append(result[0])
    if not periods:
        return None

    periods_arr = np.array(periods)
    median_period = float(np.median(periods_arr))
    median_lag = median_period / dt
    agreement = float(np.mean(np.abs(periods_arr / dt - median_lag) <= 2))
    return median_period, agreement
