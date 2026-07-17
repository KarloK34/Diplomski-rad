import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:gait_sense/models/sensor_sample.dart';
import 'package:gait_sense/utils/basic_statistics.dart' as stats;
import 'package:gait_sense/utils/gait_cadence.dart';
import 'package:gait_sense/utils/gait_signal_segments.dart';
import 'package:gait_sense/utils/sensor_conversion.dart';

// ---------------------------------------------------------------------------
// Reason codes
// ---------------------------------------------------------------------------

/// No cadence result was available for this segment.
const String missingCadenceResultReason = 'missing_cadence_result';

/// The cadence result for this segment was not computed.
const String cadenceNotComputedReason = 'cadence_not_computed';

/// The cadence result was computed but has low confidence.
const String lowConfidenceCadenceReason = 'low_confidence_cadence';

/// The vertical acceleration amplitude was too small to estimate displacement.
const String insufficientVerticalAmplitudeReason =
    'insufficient_vertical_amplitude';

/// The inverted-pendulum discriminant was non-positive (degenerate geometry).
const String invalidPendulumGeometryReason = 'invalid_pendulum_geometry';

/// The estimated step length was outside the plausible human range.
const String implausibleStepLengthReason = 'implausible_step_length';

// ---------------------------------------------------------------------------
// Physical constants and defaults
// ---------------------------------------------------------------------------

/// Ratio of leg length to body height.
///
/// Derived from Winter, "Biomechanics and Motor Control of Human Movement",
/// 4th ed., 2009 (Table 4.1): the distance from the greater trochanter to the
/// floor is approximately 53 % of standing height for adults.  This ratio is
/// used in the inverted-pendulum step-length model (Zijlstra & Hof, 2003,
/// https://doi.org/10.1016/S0966-6362(02)00190-X).
const double kLegLengthHeightRatio = 0.53;

/// Plausible lower bound for adult step length (m).
///
/// Steps shorter than this are treated as estimation failures.  This bound is
/// a project heuristic, not a clinically validated minimum.
const double kMinPlausibleStepLengthM = 0.20;

/// Plausible upper bound for adult step length (m).
///
/// Steps longer than this are treated as estimation failures.  This bound is
/// a project heuristic, not a clinically validated maximum.
const double kMaxPlausibleStepLengthM = 1.20;

/// Low-pass cutoff used on the vertical acceleration signal before amplitude
/// extraction.  Matches the cadence filter so both analyses see the same
/// preprocessed signal.
const double kWalkingSpeedLowPassCutoffHz = 3;

/// Near-zero guard for the vertical RMS amplitude (g).
///
/// Signals below this level are considered flat and produce no usable
/// displacement estimate.
const double kMinVerticalAmplitudeG = 1e-4;

/// High-pass cutoff applied to the doubly-integrated vertical position
/// signal, to bound integration drift.
///
/// Zijlstra & Hof (2003), https://doi.org/10.1016/S0966-6362(02)00190-X, use a
/// fourth-order zero-lag Butterworth high-pass filter at 0.1 Hz for exactly
/// this purpose. Lee et al. (2024), https://doi.org/10.2196/52166, use the
/// same order at 0.11 Hz. This implementation follows the Zijlstra & Hof
/// cutoff.
const double kVerticalDisplacementHighPassCutoffHz = 0.1;

/// Upper bound (exclusive) of Lee et al.'s short raw-step-length bin.
///
/// See [leeStepLengthCorrectionFactor] for the source and rationale.
const double kLeeShortStepLengthBoundM = 0.5;

/// Upper bound (exclusive) of Lee et al.'s medium raw-step-length bin.
///
/// See [leeStepLengthCorrectionFactor] for the source and rationale.
const double kLeeMediumStepLengthBoundM = 0.8;

/// Correction factor for a raw step-length estimate below
/// [kLeeShortStepLengthBoundM].
const double kLeeShortStepCorrectionFactor = 1.37;

/// Correction factor for a raw step-length estimate in
/// [kLeeShortStepLengthBoundM, kLeeMediumStepLengthBoundM).
const double kLeeMediumStepCorrectionFactor = 1.02;

/// Correction factor for a raw step-length estimate at or above
/// [kLeeMediumStepLengthBoundM].
const double kLeeLongStepCorrectionFactor = 0.74;

/// Empirical correction factor for the raw (uncorrected) inverted-pendulum
/// step-length estimate, keyed by [rawStepLengthM] itself.
///
/// The raw geometric model is not a uniform under- or over-estimator: Lee et
/// al., "A Novel Approach for Improving Gait Speed Estimation Using a Single
/// Inertial Measurement Unit Embedded in a Smartphone", JMIR mHealth uHealth,
/// 2024, https://doi.org/10.2196/52166, validated the same pendulum formula
/// with the phone in the front pants pocket — matching this app's placement —
/// against a GAITRite mat, and found a slope ≠ 1 bias: *"the pendulum model
/// approach to calculating gait speed from a single IMU placed in the pocket
/// overestimated step length and therefore gait speed if the step length
/// derived from the GAITRite mat was greater than 0.8 m, yet underestimated
/// both values if the step length was less than 0.5 m."* Their fix is a
/// piecewise multiplicative correction fit to 3 raw-step-length ranges
/// (their Table 1 / Eq. 2): ×1.37 for raw estimates in [0.2, 0.5) m, ×1.02 for
/// [0.5, 0.8) m, ×0.74 for [0.8, 1.1] m — applied here instead of a single
/// fixed factor.
/// A raw estimate outside Lee et al.'s studied [0.2, 1.1] m range falls back
/// to the nearest bin's factor — an extrapolation beyond what they validated,
/// not itself literature-backed.
double leeStepLengthCorrectionFactor(double rawStepLengthM) {
  if (rawStepLengthM < kLeeShortStepLengthBoundM) {
    return kLeeShortStepCorrectionFactor;
  }
  if (rawStepLengthM < kLeeMediumStepLengthBoundM) {
    return kLeeMediumStepCorrectionFactor;
  }
  return kLeeLongStepCorrectionFactor;
}

// ---------------------------------------------------------------------------
// Status enum
// ---------------------------------------------------------------------------

/// Availability status for a walking-speed estimation attempt.
enum GaitWalkingSpeedStatus {
  /// Step length and walking speed were estimated.
  computed,

  /// No suitable signal or cadence input was available.
  unavailable,

  /// The computed values fell outside the plausible human range.
  implausible,
}

// ---------------------------------------------------------------------------
// Result class
// ---------------------------------------------------------------------------

/// Step-length and walking-speed estimate for one level-walking segment.
///
/// Uses the inverted-pendulum model of Zijlstra & Hof, "Assessment of
/// spatio-temporal gait parameters from trunk accelerations during human
/// walking", Gait & Posture, 2003,
/// https://doi.org/10.1016/S0966-6362(02)00190-X, and smartphone-based gait
/// speed estimation with a single IMU in Lee et al., "A Novel Approach for
/// Improving Gait Speed Estimation Using a Single Inertial Measurement Unit
/// Embedded in a Smartphone", JMIR mHealth, 2024,
/// https://doi.org/10.2196/52166. Both papers recover the vertical
/// center-of-mass displacement `h` by doubly integrating the vertical
/// acceleration and high-pass filtering the resulting position signal to
/// control drift; see [analyzeGaitWalkingSpeed] for this implementation's
/// version of that method.
///
/// All values are project-level estimations and are not clinically validated.
class GaitWalkingSpeedResult extends Equatable {
  /// Creates a result.
  const GaitWalkingSpeedResult({
    required this.stepLengthM,
    required this.walkingSpeedMs,
    required this.verticalAmplitudeG,
    required this.legLengthM,
    required this.status,
    required this.reason,
  });

  /// Estimated step length in metres, or 0 when unavailable.
  final double stepLengthM;

  /// Estimated walking speed in m/s, or 0 when unavailable.
  final double walkingSpeedMs;

  /// RMS amplitude of the low-pass-filtered vertical acceleration signal (g).
  final double? verticalAmplitudeG;

  /// Leg length derived from the user's height (m).
  final double? legLengthM;

  /// Availability status for this result.
  final GaitWalkingSpeedStatus status;

  /// Machine-readable reason when [status] is not
  /// [GaitWalkingSpeedStatus.computed].
  final String? reason;

  /// Whether [stepLengthM] and [walkingSpeedMs] are available.
  bool get isComputed => status == GaitWalkingSpeedStatus.computed;

  @override
  List<Object?> get props => [
    stepLengthM,
    walkingSpeedMs,
    verticalAmplitudeG,
    legLengthM,
    status,
    reason,
  ];
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Estimates step length and walking speed for [segment] using the inverted-
/// pendulum model.
///
/// [cadenceResult] must be the result of [analyzeGaitCadence] for the same
/// segment — the cadence value and step locations are reused directly to avoid
/// recomputing them here.
///
/// [userHeightCm] is the user's standing height in centimetres, used to derive
/// leg length via [kLegLengthHeightRatio].
GaitWalkingSpeedResult analyzeGaitWalkingSpeed(
  GaitSignalSegment segment, {
  required GaitCadenceResult cadenceResult,
  required double userHeightCm,
  double lowPassCutoffHz = kWalkingSpeedLowPassCutoffHz,
}) {
  if (!cadenceResult.isComputed) {
    return _notComputed(reason: cadenceNotComputedReason);
  }

  // Spatial estimates are downstream of accepted step events and cadence.
  // Zijlstra & Hof (2003), https://doi.org/10.1016/S0966-6362(02)00190-X,
  // estimate spatio-temporal parameters from trunk accelerations after gait
  // event identification. With a pocket phone this app keeps speed unavailable
  // when the upstream cadence evidence is weak.
  if (cadenceResult.confidence == GaitCadenceConfidence.low) {
    return _notComputed(reason: lowConfidenceCadenceReason);
  }

  if (!segment.hasSamples) {
    return _notComputed(reason: missingCadenceResultReason);
  }

  final samples = segment.samples;
  final legLengthM = userHeightCm / 100.0 * kLegLengthHeightRatio;

  // --- Vertical signal -------------------------------------------------
  // Compute the vertical acceleration component for every sample using the
  // shared helper, then apply the same Butterworth low-pass filter used by
  // the cadence analyser so both analyses operate on the same preprocessed
  // signal.
  final verticalRaw = [
    for (final s in samples) verticalAcceleration(s),
  ];
  final verticalFiltered = filterCadenceLowPassButterworth(
    samples,
    verticalRaw,
    cutoffHz: lowPassCutoffHz,
  );

  // --- Amplitude estimate ----------------------------------------------
  // RMS of the filtered signal is a robust amplitude proxy that is
  // insensitive to signal timing offset and avoids the need for per-step peak
  // detection.
  // The RMS is taken after removing the mean so DC bias (imperfect gravity
  // subtraction) does not inflate the estimate.
  final mean = stats.mean(verticalFiltered);
  final centred = [for (final v in verticalFiltered) v - mean];
  final rmsAmplitude = _rms(centred);

  if (rmsAmplitude < kMinVerticalAmplitudeG) {
    return _notComputed(
      verticalAmplitudeG: rmsAmplitude,
      legLengthM: legLengthM,
      reason: insufficientVerticalAmplitudeReason,
    );
  }

  // --- Vertical displacement (h) via double integration -----------------
  // Zijlstra & Hof (2003) and Lee et al. (2024) both recover h — the
  // peak-to-peak vertical CoM excursion during a step — by doubly
  // integrating vertical acceleration and high-pass filtering the resulting
  // position signal to control drift. The centred, low-pass-filtered signal
  // above is reused here so the integration starts from the same
  // gravity-corrected, denoised input as the amplitude gate.
  final sampleInterval = medianSampleInterval(samples);
  final dtSeconds =
      sampleInterval.inMicroseconds / Duration.microsecondsPerSecond;

  final verticalAccelerationMs2 = [
    for (final v in centred) v * kStandardGravity,
  ];
  final velocityMs = _cumulativeTrapezoidalIntegral(
    verticalAccelerationMs2,
    dtSeconds,
  );
  // A single numerically-integrated sinusoid does not average to zero
  // velocity (the zero initial condition pins the *value*, not the mean),
  // so a residual DC term otherwise integrates into an unbounded linear
  // drift in position. Removing the velocity-stage mean bounds that before
  // the position-stage filter below runs. This intermediate step is a
  // project addition needed for numerical stability, not part of the cited
  // method.
  final velocityCentred = _removeMean(velocityMs);
  final positionM = _cumulativeTrapezoidalIntegral(velocityCentred, dtSeconds);
  final positionFiltered = filterZeroPhaseHighPassButterworth(
    samples,
    positionM,
    cutoffHz: kVerticalDisplacementHighPassCutoffHz,
  );

  final stepIndices = _localStepIndices(
    samples,
    cadenceResult.detectedStepOffsets,
  );
  final stepHeightsM = _perStepPeakToPeak(positionFiltered, stepIndices);
  if (stepHeightsM.isEmpty) {
    return _notComputed(
      verticalAmplitudeG: rmsAmplitude,
      legLengthM: legLengthM,
      reason: insufficientVerticalAmplitudeReason,
    );
  }
  // The segment yields one h per step-to-step interval; the median is used
  // to summarise them into the single h the inverted-pendulum formula below
  // expects. Aggregating multiple steps this way is a project display
  // choice, not specified by Zijlstra & Hof or Lee.
  final hM = stats.median(stepHeightsM);

  // --- Inverted-pendulum step length -----------------------------------
  // Zijlstra & Hof geometric formula:
  //   step_length = 2 × √(2 × l × h − h²)
  // where l is leg length and h is the vertical CoM displacement per step.
  final discriminant = 2 * legLengthM * hM - hM * hM;
  if (discriminant <= 0) {
    return _notComputed(
      verticalAmplitudeG: rmsAmplitude,
      legLengthM: legLengthM,
      reason: invalidPendulumGeometryReason,
    );
  }

  final cadenceSpm = cadenceResult.cadenceStepsPerMinute;
  final rawStepLengthM = 2 * sqrt(discriminant);
  final stepLengthM =
      rawStepLengthM * leeStepLengthCorrectionFactor(rawStepLengthM);

  if (stepLengthM < kMinPlausibleStepLengthM ||
      stepLengthM > kMaxPlausibleStepLengthM) {
    return GaitWalkingSpeedResult(
      stepLengthM: stepLengthM,
      walkingSpeedMs: 0,
      verticalAmplitudeG: rmsAmplitude,
      legLengthM: legLengthM,
      status: GaitWalkingSpeedStatus.implausible,
      reason: implausibleStepLengthReason,
    );
  }

  // walking_speed [m/s] = step_length [m] × cadence [steps/min] / 60
  // (cadence counts individual steps, step_length is per step, so no ÷2)
  final walkingSpeedMs = stepLengthM * cadenceSpm / 60.0;

  return GaitWalkingSpeedResult(
    stepLengthM: stepLengthM,
    walkingSpeedMs: walkingSpeedMs,
    verticalAmplitudeG: rmsAmplitude,
    legLengthM: legLengthM,
    status: GaitWalkingSpeedStatus.computed,
    reason: null,
  );
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

GaitWalkingSpeedResult _notComputed({
  required String reason,
  double? verticalAmplitudeG,
  double? legLengthM,
}) {
  return GaitWalkingSpeedResult(
    stepLengthM: 0,
    walkingSpeedMs: 0,
    verticalAmplitudeG: verticalAmplitudeG,
    legLengthM: legLengthM,
    status: GaitWalkingSpeedStatus.unavailable,
    reason: reason,
  );
}

double _rms(List<double> values) {
  if (values.isEmpty) return 0;
  final meanSquare =
      values.fold<double>(0, (sum, v) => sum + v * v) / values.length;
  return sqrt(meanSquare);
}

/// Cumulative trapezoidal integral, starting at zero.
List<double> _cumulativeTrapezoidalIntegral(
  List<double> values,
  double dtSeconds,
) {
  final integral = List<double>.filled(values.length, 0);
  var accumulator = 0.0;
  for (var i = 1; i < values.length; i++) {
    accumulator += (values[i] + values[i - 1]) / 2 * dtSeconds;
    integral[i] = accumulator;
  }
  return integral;
}

List<double> _removeMean(List<double> values) {
  final mean = stats.mean(values);
  return [for (final v in values) v - mean];
}

/// Maps [stepOffsets] (durations from `samples.first.timestamp`, as produced
/// by [GaitCadenceResult.detectedStepOffsets] for this same sample list) to
/// indices into [samples].
List<int> _localStepIndices(
  List<SensorSample> samples,
  List<Duration> stepOffsets,
) {
  if (samples.isEmpty || stepOffsets.isEmpty) return const [];

  final firstTimestamp = samples.first.timestamp;
  final indices = <int>[];
  var searchIndex = 0;
  for (final offset in stepOffsets) {
    final target = firstTimestamp.add(offset);
    while (searchIndex < samples.length - 1 &&
        samples[searchIndex].timestamp.isBefore(target)) {
      searchIndex++;
    }
    indices.add(searchIndex);
  }
  return indices;
}

/// Peak-to-peak excursion of [positionM] within each consecutive pair of
/// [stepIndices], i.e. h per Zijlstra & Hof's "difference between highest and
/// lowest position during a step cycle".
List<double> _perStepPeakToPeak(
  List<double> positionM,
  List<int> stepIndices,
) {
  final heights = <double>[];
  for (var i = 1; i < stepIndices.length; i++) {
    final start = stepIndices[i - 1];
    final end = stepIndices[i];
    if (end <= start) continue;

    var minPosition = positionM[start];
    var maxPosition = positionM[start];
    for (var j = start + 1; j <= end; j++) {
      final value = positionM[j];
      if (value < minPosition) minPosition = value;
      if (value > maxPosition) maxPosition = value;
    }
    heights.add(maxPosition - minPosition);
  }
  return heights;
}
