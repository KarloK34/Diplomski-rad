"""Python re-implementation of the app's step-counting pipeline (cadence math
has no other Python counterpart), for offline validation against manual
ground truth (`ml/scripts/step_count_validation.py`). Ports
`butterworth_filter.dart`, `gait_cadence.dart`, `gait_segments.dart`,
`gait_walking_speed.dart`, and `gait_temporal_parameters.dart` verbatim (same
coefficients, gates, tie-break rules); thresholds and citations (Susi et al.
2013, DOI 10.3390/s130201539; Wu & Urbanek 2023, DOI 10.1088/1361-6579/accefe;
Lee, Choi & Lee 2015, DOI 10.3390/s151027230) are copied from those files, not
re-derived here.

Faithful, not byte-exact: Dart's microsecond-integer Duration arithmetic is
done here in float seconds, and `_zeroPhaseFilter`'s rounding is followed but
not bit-verified against the Dart runtime -- doesn't change which peaks are
accepted at 50 Hz sampling (cross-checked in `step_count_validation.py`).
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field

import numpy as np

# ---------------------------------------------------------------------------
# gait_cadence_constants.dart
# ---------------------------------------------------------------------------

MIN_DURATION_S = 2.0
LOWPASS_CUTOFF_HZ = 3.0
MIN_CADENCE_SPM = 60.0
MAX_CADENCE_SPM = 210.0
MIN_PEAK_INTERVAL_FRACTION = 0.75
PEAK_THRESHOLD_STD_MULT = 0.5
MIN_PERIODICITY = 0.2
REPORTABLE_PERIODICITY_FRACTION = 0.75
MODERATE_PERIODICITY = 0.35
HIGH_PERIODICITY = 0.55
MAX_ESTIMATE_DISAGREEMENT = 0.15
STRONG_ESTIMATE_AGREEMENT = 0.05
CONSISTENT_ESTIMATE_MIN_STEPS = 12
COMPARABLE_PERIODICITY_RATIO = 0.7
MIN_DETECTED_STEPS = 2

# gait_segments.dart / session_summary.dart
LOCOMOTION_LABELS = {"wlk", "ups", "dws", "jog"}
GAIT_CANDIDATE_MIN_WINDOWS = 5
WINDOW_SIZE = 128  # FeatureWindow.windowSize

_BUTTERWORTH_Q = (0.541196100146197, 1.3065629648763766)


# ---------------------------------------------------------------------------
# butterworth_filter.dart
# ---------------------------------------------------------------------------


def _lowpass_biquad(cutoff_hz: float, fs_hz: float, q: float) -> tuple[float, ...]:
    omega = 2 * math.pi * cutoff_hz / fs_hz
    sin_o, cos_o = math.sin(omega), math.cos(omega)
    alpha = sin_o / (2 * q)
    b0 = (1 - cos_o) / 2
    b1 = 1 - cos_o
    b2 = (1 - cos_o) / 2
    a0 = 1 + alpha
    a1 = -2 * cos_o
    a2 = 1 - alpha
    return (b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0)


def _apply_biquad(values: np.ndarray, coeffs: tuple[float, ...]) -> np.ndarray:
    b0, b1, b2, a1, a2 = coeffs
    z1 = z2 = 0.0
    out = np.empty(len(values), dtype=float)
    for i, x in enumerate(values):
        y = b0 * x + z1
        z1 = b1 * x - a1 * y + z2
        z2 = b2 * x - a2 * y
        out[i] = y if np.isfinite(y) else 0.0
    return out


def _apply_cascade(values: np.ndarray, sections: list[tuple[float, ...]]) -> np.ndarray:
    out = values
    for section in sections:
        out = _apply_biquad(out, section)
    return out


def _pad_length(n: int, cutoff_hz: float, fs_hz: float) -> int:
    samples_per_time_constant = fs_hz / (2 * math.pi * cutoff_hz)
    nominal = math.ceil(3 * samples_per_time_constant)
    return max(0, min(nominal, n - 1))


def _odd_extend(values: np.ndarray, pad: int) -> np.ndarray:
    n = len(values)
    first, last = values[0], values[-1]
    left = np.array([2 * first - values[pad - i] for i in range(pad)])
    right = np.array([2 * last - values[n - 2 - i] for i in range(pad)])
    return np.concatenate([left, values, right])


def _zero_phase_filter(
    values: np.ndarray,
    sections: list[tuple[float, ...]],
    cutoff_hz: float,
    fs_hz: float,
) -> np.ndarray:
    n = len(values)
    pad = _pad_length(n, cutoff_hz, fs_hz)
    padded = _odd_extend(values, pad) if pad > 0 else values
    forward = _apply_cascade(padded, sections)
    backward = _apply_cascade(forward[::-1], sections)
    result = backward[::-1]
    return result[pad : pad + n] if pad > 0 else result


def filter_lowpass_butterworth(
    values: np.ndarray, fs_hz: float, cutoff_hz: float = LOWPASS_CUTOFF_HZ
) -> np.ndarray:
    """Fourth-order zero-phase Butterworth low-pass (`filterCadenceLowPassButterworth`)."""
    values = np.asarray(values, dtype=float)
    if len(values) < 2 or fs_hz <= 0 or not np.isfinite(fs_hz):
        return values
    nyquist_hz = fs_hz / 2
    bounded_cutoff = min(cutoff_hz, nyquist_hz * 0.95)
    if bounded_cutoff <= 0:
        return values
    sections = [_lowpass_biquad(bounded_cutoff, fs_hz, q) for q in _BUTTERWORTH_Q]
    return _zero_phase_filter(values, sections, bounded_cutoff, fs_hz)


def _highpass_biquad(cutoff_hz: float, fs_hz: float, q: float) -> tuple[float, ...]:
    omega = 2 * math.pi * cutoff_hz / fs_hz
    sin_o, cos_o = math.sin(omega), math.cos(omega)
    alpha = sin_o / (2 * q)
    b0 = (1 + cos_o) / 2
    b1 = -(1 + cos_o)
    b2 = (1 + cos_o) / 2
    a0 = 1 + alpha
    a1 = -2 * cos_o
    a2 = 1 - alpha
    return (b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0)


def filter_highpass_butterworth(
    values: np.ndarray, fs_hz: float, cutoff_hz: float
) -> np.ndarray:
    """Fourth-order zero-phase Butterworth high-pass (`filterZeroPhaseHighPassButterworth`),
    used to bound double-integration drift when recovering vertical position
    (Zijlstra & Hof 2003, DOI 10.1016/S0966-6362(02)00190-X)."""
    values = np.asarray(values, dtype=float)
    if len(values) < 2 or fs_hz <= 0 or not np.isfinite(fs_hz):
        return values
    nyquist_hz = fs_hz / 2
    bounded_cutoff = min(cutoff_hz, nyquist_hz * 0.95)
    if bounded_cutoff <= 0:
        return values
    sections = [_highpass_biquad(bounded_cutoff, fs_hz, q) for q in _BUTTERWORTH_Q]
    return _zero_phase_filter(values, sections, bounded_cutoff, fs_hz)


# ---------------------------------------------------------------------------
# gait_cadence.dart
# ---------------------------------------------------------------------------


@dataclass
class CadenceResult:
    step_count: int = 0
    cadence_spm: float = 0.0
    peak_cadence_spm: float | None = None
    period_cadence_spm: float | None = None
    periodicity: float | None = None
    duration_s: float = 0.0
    step_offsets_s: list[float] = field(default_factory=list)
    status: str = "empty"  # computed | empty | insufficient_signal | invalid_timestamps
    reason: str | None = None
    confidence: str = "low"  # low | moderate | high
    signal: str | None = None  # user_acceleration | angular_velocity
    is_boundary_artifact: bool = False

    @property
    def is_computed(self) -> bool:
        return self.status == "computed"


def _median_interval_s(t_s: np.ndarray) -> float:
    diffs = np.diff(t_s)
    if len(diffs) == 0:
        return 0.0
    return float(np.median(diffs))


def _estimate_dominant_period(
    values: np.ndarray, sample_interval_s: float
) -> tuple[float, float, bool] | None:
    """Autocorrelation period search -- project heuristic cross-checking peak
    cadence against periodicity, motivated by (not sourced from) Wu & Urbanek
    (2023), DOI 10.1088/1361-6579/accefe. See `_estimateDominantPeriod` in
    gait_cadence.dart for the full citation caveat.

    Returns `(period_s, periodicity, is_boundary_artifact)`; the artifact flag
    is true when the selected lag is `max_lag` only because correlation was
    still rising at that edge, never an interior local maximum -- see
    `_better_candidate`, which demotes such a candidate against the other
    signal channel (docs/plan-popravka-kadence-brzog-hoda.md)."""
    n = len(values)
    if n < 3 or sample_interval_s <= 0:
        return None

    min_period_s = 60.0 / MAX_CADENCE_SPM
    max_period_s = 60.0 / MIN_CADENCE_SPM
    min_lag = max(2, math.ceil(min_period_s / sample_interval_s))
    max_lag = min(n - 2, math.floor(max_period_s / sample_interval_s))
    if max_lag <= min_lag:
        return None

    mean = float(np.mean(values))
    centered = values - mean
    correlations: dict[int, float] = {}
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
    usable = preferred or [
        (l, v) for l, v in correlations.items() if math.isfinite(v) and v > 0
    ]
    if not usable:
        return None

    strongest = max(v for _, v in usable)
    comparable = strongest * COMPARABLE_PERIODICITY_RATIO
    candidates = [(l, v) for l, v in usable if v >= comparable]
    best_lag, best_corr = min(candidates, key=lambda lv: lv[0])
    is_boundary_artifact = boundary_added and best_lag == max_lag
    return sample_interval_s * best_lag, min(max(best_corr, 0.0), 1.0), is_boundary_artifact


def _detect_peaks(
    t_s: np.ndarray, values: np.ndarray, threshold: float, min_peak_interval_s: float
) -> list[int]:
    candidates = [
        (i, values[i])
        for i in range(1, len(values) - 1)
        if values[i] > values[i - 1] and values[i] >= values[i + 1] and values[i] >= threshold
    ]
    strongest_first = sorted(candidates, key=lambda iv: (-iv[1], iv[0]))
    accepted: list[int] = []
    for i, _ in strongest_first:
        if all(abs(t_s[i] - t_s[j]) >= min_peak_interval_s for j in accepted):
            accepted.append(i)
    accepted.sort()
    return accepted


def _assess_confidence(
    peak_count: int, periodicity: float, disagreement: float, reportable_periodicity: float
) -> str:
    strong_internal_consistency = (
        peak_count >= CONSISTENT_ESTIMATE_MIN_STEPS
        and periodicity >= reportable_periodicity
        and disagreement <= STRONG_ESTIMATE_AGREEMENT
    )
    if periodicity < MIN_PERIODICITY and not strong_internal_consistency:
        return "low"
    if disagreement > MAX_ESTIMATE_DISAGREEMENT:
        return "low"
    if periodicity < MODERATE_PERIODICITY and not strong_internal_consistency:
        return "low"
    if peak_count < 4:
        return "low"
    if (
        periodicity >= MIN_PERIODICITY
        and periodicity >= HIGH_PERIODICITY
        and disagreement <= MAX_ESTIMATE_DISAGREEMENT * 2 / 3
        and peak_count >= 6
    ):
        return "high"
    return "moderate"


def _analyze_signal(
    t_s: np.ndarray, magnitude: np.ndarray, signal_name: str, duration_s: float
) -> CadenceResult:
    fs_hz = 1.0 / _median_interval_s(t_s) if _median_interval_s(t_s) > 0 else 0.0
    filtered = filter_lowpass_butterworth(magnitude, fs_hz)
    filtered_mean = float(np.mean(filtered))
    filtered_std = float(np.std(filtered))  # population std, matches basic_statistics.dart
    threshold = filtered_mean + filtered_std * PEAK_THRESHOLD_STD_MULT

    if filtered_std <= 1e-9:
        return CadenceResult(
            duration_s=duration_s,
            status="insufficient_signal",
            reason="too_few_detected_steps",
            signal=signal_name,
        )

    sample_interval_s = _median_interval_s(t_s)
    reportable_periodicity = MIN_PERIODICITY * REPORTABLE_PERIODICITY_FRACTION
    period_estimate = _estimate_dominant_period(filtered, sample_interval_s)
    if period_estimate is None:
        return CadenceResult(
            duration_s=duration_s,
            status="insufficient_signal",
            reason="low_periodicity",
            signal=signal_name,
        )
    period_s, periodicity, is_boundary_artifact = period_estimate
    if periodicity < reportable_periodicity:
        return CadenceResult(
            duration_s=duration_s,
            periodicity=periodicity,
            status="insufficient_signal",
            reason="low_periodicity",
            signal=signal_name,
            is_boundary_artifact=is_boundary_artifact,
        )

    min_peak_interval_s = period_s * MIN_PEAK_INTERVAL_FRACTION
    peaks = _detect_peaks(t_s, filtered, threshold, min_peak_interval_s)
    period_cadence = 60.0 / period_s

    if len(peaks) < MIN_DETECTED_STEPS:
        return CadenceResult(
            step_count=len(peaks),
            period_cadence_spm=period_cadence,
            periodicity=periodicity,
            duration_s=duration_s,
            status="insufficient_signal",
            reason="too_few_detected_steps",
            confidence="low",
            signal=signal_name,
            is_boundary_artifact=is_boundary_artifact,
        )

    peak_span = t_s[peaks[-1]] - t_s[peaks[0]]
    if peak_span <= 0:
        return CadenceResult(
            duration_s=duration_s,
            periodicity=periodicity,
            status="invalid_timestamps",
            reason="invalid_timestamps",
            signal=signal_name,
            is_boundary_artifact=is_boundary_artifact,
        )

    peak_intervals = np.diff(t_s[peaks])
    median_peak_interval_s = float(np.median(peak_intervals))
    peak_cadence = 60.0 / median_peak_interval_s
    disagreement = abs(peak_cadence - period_cadence) / period_cadence
    confidence = _assess_confidence(len(peaks), periodicity, disagreement, reportable_periodicity)

    return CadenceResult(
        step_count=len(peaks),
        cadence_spm=peak_cadence,
        peak_cadence_spm=peak_cadence,
        period_cadence_spm=period_cadence,
        periodicity=periodicity,
        duration_s=duration_s,
        step_offsets_s=[t_s[i] - t_s[0] for i in peaks],
        status="computed",
        reason=None,
        confidence=confidence,
        signal=signal_name,
        is_boundary_artifact=is_boundary_artifact,
    )


_CONFIDENCE_RANK = {"low": 0, "moderate": 1, "high": 2}


def _better_candidate(left: CadenceResult, right: CadenceResult) -> CadenceResult:
    if left.is_boundary_artifact != right.is_boundary_artifact:
        # Still-rising boundary correlation means the search range may have
        # truncated the true peak -- weaker evidence than a candidate whose
        # period actually peaked inside the search. Project heuristic; see
        # gait_cadence.dart's `_betterCadenceCandidate`.
        return right if left.is_boundary_artifact else left

    by_confidence = _CONFIDENCE_RANK[left.confidence] - _CONFIDENCE_RANK[right.confidence]
    if by_confidence != 0:
        return left if by_confidence > 0 else right

    left_p, right_p = left.periodicity or 0, right.periodicity or 0
    if abs(left_p - right_p) > 0.05:
        return left if left_p > right_p else right

    def disagreement(r: CadenceResult) -> float:
        if r.peak_cadence_spm is None or not r.period_cadence_spm:
            return float("inf")
        return abs(r.peak_cadence_spm - r.period_cadence_spm) / r.period_cadence_spm

    left_d, right_d = disagreement(left), disagreement(right)
    if abs(left_d - right_d) > 0.05:
        return left if left_d < right_d else right

    if left.signal == "user_acceleration":
        return left
    if right.signal == "user_acceleration":
        return right
    return left


def analyze_gait_cadence_samples(
    t_s: np.ndarray,
    ux: np.ndarray,
    uy: np.ndarray,
    uz: np.ndarray,
    rx: np.ndarray,
    ry: np.ndarray,
    rz: np.ndarray,
) -> CadenceResult:
    """Port of `analyzeGaitCadenceSamples` (gait_cadence.dart): picks the
    better of user-acceleration-magnitude and angular-velocity-magnitude peak
    detection for one raw-sample slice."""
    if len(t_s) == 0:
        return CadenceResult(status="empty", reason="empty_signal")
    if len(t_s) < 2:
        return CadenceResult(status="insufficient_signal", reason="signal_too_short")

    duration_s = float(t_s[-1] - t_s[0])
    if duration_s <= 0 or np.any(np.diff(t_s) <= 0):
        return CadenceResult(status="invalid_timestamps", reason="invalid_timestamps")
    if duration_s < MIN_DURATION_S:
        return CadenceResult(
            duration_s=duration_s, status="insufficient_signal", reason="signal_too_short"
        )

    acc_mag = np.sqrt(ux**2 + uy**2 + uz**2)
    gyro_mag = np.sqrt(rx**2 + ry**2 + rz**2)
    acc_mag = np.where(np.isfinite(acc_mag), acc_mag, 0.0)
    gyro_mag = np.where(np.isfinite(gyro_mag), gyro_mag, 0.0)

    candidates = [
        _analyze_signal(t_s, acc_mag, "user_acceleration", duration_s),
        _analyze_signal(t_s, gyro_mag, "angular_velocity", duration_s),
    ]
    computed = [c for c in candidates if c.is_computed]
    if not computed:
        return candidates[0]
    best = computed[0]
    for c in computed[1:]:
        best = _better_candidate(best, c)
    return best


# ---------------------------------------------------------------------------
# gait_segments.dart (cadence-labels variant only -- defaultLocomotionLabels)
# ---------------------------------------------------------------------------


@dataclass
class CadenceSegment:
    start_pred_index: int
    end_pred_index_exclusive: int
    windows: int
    start_sample_index: int | None
    end_sample_index_exclusive: int | None
    is_suitable: bool


def extract_cadence_segments(
    predictions: list[dict],
    labels: set[str] = LOCOMOTION_LABELS,
    min_windows: int = GAIT_CANDIDATE_MIN_WINDOWS,
    gap_bridge_windows: int = 0,
) -> list[CadenceSegment]:
    """Port of `extractGaitSegments(session, labels: defaultLocomotionLabels)`.

    `gap_bridge_windows` is not part of the shipped Dart algorithm (which
    always uses 0 -- any non-matching-label window ends the run immediately).
    It exists so `step_count_validation.py` can measure gap-tolerant
    segmentation before that change lands in `extractGaitSegments`.
    """
    runs: list[tuple[int, int]] = []
    run_start = -1
    n = len(predictions)
    for i in range(n):
        if predictions[i]["label"] in labels:
            if run_start < 0:
                run_start = i
        else:
            if run_start >= 0:
                runs.append((run_start, i))
                run_start = -1
    if run_start >= 0:
        runs.append((run_start, n))

    if gap_bridge_windows > 0 and len(runs) > 1:
        merged: list[tuple[int, int]] = [runs[0]]
        for start, end in runs[1:]:
            prev_start, prev_end = merged[-1]
            if start - prev_end <= gap_bridge_windows:
                merged[-1] = (prev_start, end)
            else:
                merged.append((start, end))
        runs = merged

    segments = []
    for start, end in runs:
        windows = end - start
        first_end = predictions[start].get("endSampleIndex")
        last_end = predictions[end - 1].get("endSampleIndex")
        start_sample = None
        end_sample_excl = None
        if first_end is not None and last_end is not None:
            candidate_start = first_end - WINDOW_SIZE + 1
            candidate_end = last_end + 1
            if candidate_start >= 0 and candidate_end > candidate_start:
                start_sample, end_sample_excl = candidate_start, candidate_end
        segments.append(
            CadenceSegment(
                start_pred_index=start,
                end_pred_index_exclusive=end,
                windows=windows,
                start_sample_index=start_sample,
                end_sample_index_exclusive=end_sample_excl,
                is_suitable=windows >= min_windows,
            )
        )
    return segments


def extract_level_walking_segments(
    predictions: list[dict], min_windows: int = GAIT_CANDIDATE_MIN_WINDOWS
) -> list[CadenceSegment]:
    """Port of `extractGaitSegments(session)` with its default
    `labels: {defaultLevelWalkingLabel}` (`wlk` only) -- the segment set the
    shipped app actually feeds to `analyzeGaitWalkingSpeed` (level-gait
    inverted-pendulum model), narrower than `extract_cadence_segments`'s
    `defaultLocomotionLabels`. See `gait_segments.dart`'s doc comment for why
    the two label sets differ."""
    return extract_cadence_segments(
        predictions, labels={"wlk"}, min_windows=min_windows, gap_bridge_windows=0
    )


def total_step_count(
    raw_samples: dict[str, np.ndarray],
    predictions: list[dict],
    min_windows: int = GAIT_CANDIDATE_MIN_WINDOWS,
    gap_bridge_windows: int = 0,
) -> tuple[int, list[CadenceResult], list[CadenceSegment]]:
    """Port of the cadence half of `computeSessionQualitySummary` +
    `summarizeGaitCadence`: sum `stepCount` over every suitable segment whose
    cadence result reached `status == computed` (segments that don't compute
    contribute 0, even if they detected a couple of below-gate peaks --
    matches `summarizeGaitCadence`'s `computedResults`-only fold)."""
    segments = extract_cadence_segments(
        predictions, min_windows=min_windows, gap_bridge_windows=gap_bridge_windows
    )
    results = []
    total = 0
    for seg in segments:
        if not seg.is_suitable or seg.start_sample_index is None:
            continue
        s, e = seg.start_sample_index, seg.end_sample_index_exclusive
        if s < 0 or e > len(raw_samples["t_s"]) or e <= s:
            continue
        result = analyze_gait_cadence_samples(
            raw_samples["t_s"][s:e],
            raw_samples["ux"][s:e],
            raw_samples["uy"][s:e],
            raw_samples["uz"][s:e],
            raw_samples["rx"][s:e],
            raw_samples["ry"][s:e],
            raw_samples["rz"][s:e],
        )
        results.append(result)
        if result.is_computed:
            total += result.step_count
    return total, results, segments


# ---------------------------------------------------------------------------
# gait_walking_speed.dart
# ---------------------------------------------------------------------------

K_LEG_LENGTH_HEIGHT_RATIO = 0.53  # Drillis & Contini (1966), via Winter Fig. 4.1
K_MIN_PLAUSIBLE_STEP_LENGTH_M = 0.20
K_MAX_PLAUSIBLE_STEP_LENGTH_M = 1.20
K_WALKING_SPEED_LOWPASS_CUTOFF_HZ = 3.0
K_MIN_VERTICAL_AMPLITUDE_G = 1e-4
K_VERTICAL_DISPLACEMENT_HIGHPASS_CUTOFF_HZ = 0.1
K_STANDARD_GRAVITY = 9.80665
K_LEE_SHORT_BOUND_M = 0.5
K_LEE_MEDIUM_BOUND_M = 0.8
K_LEE_SHORT_FACTOR = 1.37
K_LEE_MEDIUM_FACTOR = 1.02
K_LEE_LONG_FACTOR = 0.74


def lee_step_length_correction_factor(raw_step_length_m: float) -> float:
    """Lee et al. (2024), DOI 10.2196/52166, Table 1 / Eq. 2 piecewise
    pocket-placement correction (see gait_walking_speed.dart doc comment)."""
    if raw_step_length_m < K_LEE_SHORT_BOUND_M:
        return K_LEE_SHORT_FACTOR
    if raw_step_length_m < K_LEE_MEDIUM_BOUND_M:
        return K_LEE_MEDIUM_FACTOR
    return K_LEE_LONG_FACTOR


@dataclass
class WalkingSpeedResult:
    step_length_m: float = 0.0
    walking_speed_ms: float = 0.0
    vertical_amplitude_g: float | None = None
    leg_length_m: float | None = None
    status: str = "unavailable"  # computed | unavailable | implausible
    reason: str | None = None

    @property
    def is_computed(self) -> bool:
        return self.status == "computed"


def _vertical_acceleration(ux, uy, uz, gx, gy, gz) -> np.ndarray:
    g_norm = np.sqrt(gx**2 + gy**2 + gz**2)
    out = (ux * gx + uy * gy + uz * gz) / np.where(g_norm < 1e-9, np.nan, g_norm)
    return np.where(g_norm < 1e-9, 0.0, out)


def _cumulative_trapz(values: np.ndarray, dt_s: float) -> np.ndarray:
    out = np.zeros(len(values))
    acc = 0.0
    for i in range(1, len(values)):
        acc += (values[i] + values[i - 1]) / 2 * dt_s
        out[i] = acc
    return out


def _local_step_indices(t_s: np.ndarray, step_offsets_s: list[float]) -> list[int]:
    if len(t_s) == 0 or not step_offsets_s:
        return []
    indices = []
    search = 0
    for offset in step_offsets_s:
        target = t_s[0] + offset
        while search < len(t_s) - 1 and t_s[search] < target:
            search += 1
        indices.append(search)
    return indices


def _per_step_peak_to_peak(position_m: np.ndarray, step_indices: list[int]) -> list[float]:
    heights = []
    for i in range(1, len(step_indices)):
        start, end = step_indices[i - 1], step_indices[i]
        if end <= start:
            continue
        window = position_m[start : end + 1]
        heights.append(float(window.max() - window.min()))
    return heights


def analyze_gait_walking_speed(
    t_s: np.ndarray,
    ux: np.ndarray,
    uy: np.ndarray,
    uz: np.ndarray,
    gx: np.ndarray,
    gy: np.ndarray,
    gz: np.ndarray,
    cadence_result: CadenceResult,
    user_height_cm: float,
) -> WalkingSpeedResult:
    """Port of `analyzeGaitWalkingSpeed` (gait_walking_speed.dart): inverted-
    pendulum step length (Zijlstra & Hof 2003) + Lee et al. (2024) pocket
    correction. Only valid for level-gait (`wlk`-only) segments -- see that
    file's module doc comment for the level-gait assumption this depends on."""
    if not cadence_result.is_computed:
        return WalkingSpeedResult(status="unavailable", reason="cadence_not_computed")
    if cadence_result.confidence == "low":
        return WalkingSpeedResult(status="unavailable", reason="low_confidence_cadence")
    if len(t_s) == 0:
        return WalkingSpeedResult(status="unavailable", reason="missing_cadence_result")

    leg_length_m = user_height_cm / 100.0 * K_LEG_LENGTH_HEIGHT_RATIO
    vertical_raw = _vertical_acceleration(ux, uy, uz, gx, gy, gz)
    fs_hz = 1.0 / _median_interval_s(t_s)
    vertical_filtered = filter_lowpass_butterworth(
        vertical_raw, fs_hz, K_WALKING_SPEED_LOWPASS_CUTOFF_HZ
    )

    mean = float(np.mean(vertical_filtered))
    centred = vertical_filtered - mean
    rms_amplitude = float(np.sqrt(np.mean(centred**2)))
    if rms_amplitude < K_MIN_VERTICAL_AMPLITUDE_G:
        return WalkingSpeedResult(
            vertical_amplitude_g=rms_amplitude,
            leg_length_m=leg_length_m,
            status="unavailable",
            reason="insufficient_vertical_amplitude",
        )

    dt_s = _median_interval_s(t_s)
    vertical_accel_ms2 = centred * K_STANDARD_GRAVITY
    velocity_ms = _cumulative_trapz(vertical_accel_ms2, dt_s)
    velocity_centred = velocity_ms - np.mean(velocity_ms)
    position_m = _cumulative_trapz(velocity_centred, dt_s)
    position_filtered = filter_highpass_butterworth(
        position_m, fs_hz, K_VERTICAL_DISPLACEMENT_HIGHPASS_CUTOFF_HZ
    )

    step_indices = _local_step_indices(t_s, cadence_result.step_offsets_s)
    step_heights_m = _per_step_peak_to_peak(position_filtered, step_indices)
    if not step_heights_m:
        return WalkingSpeedResult(
            vertical_amplitude_g=rms_amplitude,
            leg_length_m=leg_length_m,
            status="unavailable",
            reason="insufficient_vertical_amplitude",
        )
    h_m = float(np.median(step_heights_m))

    discriminant = 2 * leg_length_m * h_m - h_m**2
    if discriminant <= 0:
        return WalkingSpeedResult(
            vertical_amplitude_g=rms_amplitude,
            leg_length_m=leg_length_m,
            status="unavailable",
            reason="invalid_pendulum_geometry",
        )

    cadence_spm = cadence_result.cadence_spm
    raw_step_length_m = 2 * math.sqrt(discriminant)
    step_length_m = raw_step_length_m * lee_step_length_correction_factor(raw_step_length_m)

    if not (K_MIN_PLAUSIBLE_STEP_LENGTH_M <= step_length_m <= K_MAX_PLAUSIBLE_STEP_LENGTH_M):
        return WalkingSpeedResult(
            step_length_m=step_length_m,
            vertical_amplitude_g=rms_amplitude,
            leg_length_m=leg_length_m,
            status="implausible",
            reason="implausible_step_length",
        )

    walking_speed_ms = step_length_m * cadence_spm / 60.0
    return WalkingSpeedResult(
        step_length_m=step_length_m,
        walking_speed_ms=walking_speed_ms,
        vertical_amplitude_g=rms_amplitude,
        leg_length_m=leg_length_m,
        status="computed",
        reason=None,
    )


# ---------------------------------------------------------------------------
# gait_temporal_parameters.dart
# ---------------------------------------------------------------------------

TEMPORAL_INTERVAL_LOWER_MEDIAN_RATIO = 0.5
TEMPORAL_INTERVAL_UPPER_MEDIAN_RATIO = 1.5


@dataclass
class TemporalParameters:
    step_interval_count: int
    mean_step_time_s: float
    median_step_time_s: float
    step_time_std_s: float
    step_time_cv: float
    stride_interval_count: int
    mean_stride_time_s: float | None
    stride_time_cv: float | None
    mean_instant_cadence_spm: float
    instant_cadence_cv: float
    gait_regularity: float | None


def _filter_temporal_intervals(intervals_s: list[float]) -> list[float]:
    if len(intervals_s) < 5:
        return intervals_s
    median_s = float(np.median(intervals_s))
    if median_s <= 0:
        return intervals_s
    lower = median_s * TEMPORAL_INTERVAL_LOWER_MEDIAN_RATIO
    upper = median_s * TEMPORAL_INTERVAL_UPPER_MEDIAN_RATIO
    filtered = [x for x in intervals_s if lower < x < upper]
    if len(filtered) < math.ceil(len(intervals_s) / 2):
        return intervals_s
    return filtered


def _interval_stats(intervals_s: list[float]) -> dict | None:
    if not intervals_s:
        return None
    mean_s = float(np.mean(intervals_s))
    if mean_s <= 0:
        return None
    std_s = float(np.std(intervals_s))
    return {
        "mean": mean_s,
        "median": float(np.median(intervals_s)),
        "std": std_s,
        "cv": std_s / mean_s,
    }


def summarize_temporal_parameters(
    results: list[CadenceResult],
) -> TemporalParameters | None:
    """Port of `summarizeGaitTemporalParameters`: pools step/stride intervals
    across segments (no artificial interval created across segment gaps) and
    duration-weights the periodicity-based regularity score."""
    interval_s: list[float] = []
    stride_interval_s: list[float] = []
    weighted_regularity = 0.0
    regularity_weight = 0

    for result in results:
        if not result.is_computed:
            continue
        offsets = result.step_offsets_s
        step_ivals = [offsets[i] - offsets[i - 1] for i in range(1, len(offsets))]
        step_ivals = [x for x in step_ivals if x > 0]
        filtered = _filter_temporal_intervals(step_ivals)
        interval_s.extend(filtered)

        stride_ivals = [offsets[i] - offsets[i - 2] for i in range(2, len(offsets))]
        stride_ivals = [x for x in stride_ivals if x > 0]
        stride_interval_s.extend(_filter_temporal_intervals(stride_ivals))

        if result.periodicity is not None and filtered:
            weighted_regularity += result.periodicity * len(filtered)
            regularity_weight += len(filtered)

    if not interval_s:
        return None
    step_stats = _interval_stats(interval_s)
    if step_stats is None:
        return None
    stride_stats = _interval_stats(stride_interval_s)

    instant_cadence = [60.0 / x for x in interval_s]
    mean_instant = float(np.mean(instant_cadence))
    std_instant = float(np.std(instant_cadence))

    return TemporalParameters(
        step_interval_count=len(interval_s),
        mean_step_time_s=step_stats["mean"],
        median_step_time_s=step_stats["median"],
        step_time_std_s=step_stats["std"],
        step_time_cv=step_stats["cv"],
        stride_interval_count=len(stride_interval_s),
        mean_stride_time_s=stride_stats["mean"] if stride_stats else None,
        stride_time_cv=stride_stats["cv"] if stride_stats else None,
        mean_instant_cadence_spm=mean_instant,
        instant_cadence_cv=(std_instant / mean_instant) if mean_instant > 0 else 0.0,
        gait_regularity=(
            weighted_regularity / regularity_weight if regularity_weight else None
        ),
    )
