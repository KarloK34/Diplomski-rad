import 'dart:math';

import 'package:equatable/equatable.dart';
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
/// Motivated by the inverted-pendulum model of Zijlstra & Hof, "Assessment of
/// spatio-temporal gait parameters from trunk accelerations during human
/// walking", Gait & Posture, 2003,
/// https://doi.org/10.1016/S0966-6362(02)00190-X, and smartphone-based gait
/// speed estimation with a single IMU in Lee et al., "A Novel Approach for
/// Improving Gait Speed Estimation Using a Single Inertial Measurement Unit
/// Embedded in a Smartphone", JMIR mHealth, 2024,
/// https://doi.org/10.2196/52166.
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
  final mean = _mean(verticalFiltered);
  final centred = [for (final v in verticalFiltered) v - mean];
  final rmsAmplitude = _rms(centred);

  if (rmsAmplitude < kMinVerticalAmplitudeG) {
    return _notComputed(
      verticalAmplitudeG: rmsAmplitude,
      legLengthM: legLengthM,
      reason: insufficientVerticalAmplitudeReason,
    );
  }

  // --- Inverted-pendulum step length -----------------------------------
  // Convert amplitude from g to metres, then apply the Zijlstra & Hof
  // geometric formula:
  //   step_length = 2 × √(2 × l × h − h²)
  // where l is leg length and h is the vertical CoM displacement per step.
  //
  // h is approximated from the signal amplitude and the step angular
  // frequency using the simple harmonic oscillator relationship:
  //   h ≈ A / ω²
  // where A is amplitude in m/s² and ω = 2π × f_step [rad/s].
  // f_step = cadence_spm / 60 / 2 because cadence counts individual steps
  // while the CoM oscillates once per two steps (one full gait cycle).
  //
  // This is a project approximation motivated by Lee et al. (2024), not a
  // clinically validated reproduction of their full method.
  final cadenceSpm = cadenceResult.cadenceStepsPerMinute;
  final fStepHz = cadenceSpm / 60.0 / 2.0; // CoM frequency [Hz]
  final omega = 2 * pi * fStepHz; // [rad/s]
  final amplitudeMs2 = rmsAmplitude * kStandardGravity; // convert g → m/s²
  final hM = amplitudeMs2 / (omega * omega); // vertical displacement [m]

  final discriminant = 2 * legLengthM * hM - hM * hM;
  if (discriminant <= 0) {
    return _notComputed(
      verticalAmplitudeG: rmsAmplitude,
      legLengthM: legLengthM,
      reason: invalidPendulumGeometryReason,
    );
  }

  final stepLengthM = 2 * sqrt(discriminant);

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

double _mean(List<double> values) {
  if (values.isEmpty) return 0;
  return values.fold<double>(0, (sum, v) => sum + v) / values.length;
}

double _rms(List<double> values) {
  if (values.isEmpty) return 0;
  final meanSquare =
      values.fold<double>(0, (sum, v) => sum + v * v) / values.length;
  return sqrt(meanSquare);
}
