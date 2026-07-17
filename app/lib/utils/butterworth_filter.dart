import 'dart:math' as math;

import 'package:gait_sense/models/sensor_sample.dart';

/// Median interval between consecutive sample timestamps.
///
/// Used to derive an effective sample rate for filter design and for
/// fixed-step numerical integration when timestamps are not perfectly
/// uniform.
Duration medianSampleInterval(List<SensorSample> samples) {
  final intervals = [
    for (var i = 1; i < samples.length; i++)
      samples[i].timestamp.difference(samples[i - 1].timestamp).inMicroseconds,
  ]..sort();
  final middle = intervals.length ~/ 2;
  final median = intervals.length.isOdd
      ? intervals[middle]
      : ((intervals[middle - 1] + intervals[middle]) / 2).round();
  return Duration(microseconds: median);
}

/// Applies the Butterworth low-pass preprocessing motivated by Susi et al.
/// (2013), https://doi.org/10.3390/s130201539.
///
/// The paper uses a 10th-order Butterworth filter at 3 Hz for step detection.
/// This app uses a fourth-order second-order-section cascade and a
/// forward/backward pass as a dependency-free project adaptation. The
/// Butterworth filter family follows Butterworth, "On the Theory of Filter
/// Amplifiers", Experimental Wireless & the Wireless Engineer, 1930.
///
/// This function is intentionally public so numerical tests and offline
/// diagnostics can verify the same filter used by `analyzeGaitCadenceSamples`
/// in gait_cadence.dart. The filtering approach is motivated by Susi et al.
/// (2013), https://doi.org/10.3390/s130201539, with the project adaptation
/// described above.
List<double> filterCadenceLowPassButterworth(
  List<SensorSample> samples,
  List<double> values, {
  required double cutoffHz,
}) {
  assert(
    samples.length == values.length,
    'samples and values must have the same length',
  );
  if (values.length < 2) return List.of(values);

  final sampleInterval = medianSampleInterval(samples);
  if (sampleInterval <= Duration.zero) return List.of(values);

  final sampleRateHz =
      Duration.microsecondsPerSecond / sampleInterval.inMicroseconds;
  if (!sampleRateHz.isFinite || sampleRateHz <= 0) return List.of(values);

  final nyquistHz = sampleRateHz / 2;
  final boundedCutoffHz = math.min(cutoffHz, nyquistHz * 0.95);
  if (boundedCutoffHz <= 0) return List.of(values);

  final sections = _butterworthFourthOrderLowPassSections(
    cutoffHz: boundedCutoffHz,
    sampleRateHz: sampleRateHz,
  );
  final forward = _applyBiquadCascade(values, sections);
  final backwardInput = forward.reversed.toList(growable: false);
  final backward = _applyBiquadCascade(backwardInput, sections);

  return backward.reversed.toList(growable: false);
}

/// Applies a fourth-order zero-lag Butterworth high-pass filter.
///
/// Used to bound double-integration drift when recovering vertical position
/// from acceleration, as done by `analyzeGaitWalkingSpeed` in
/// gait_walking_speed.dart. Zijlstra & Hof, "Assessment of spatio-temporal
/// gait parameters from trunk accelerations during human walking", Gait &
/// Posture, 2003, https://doi.org/10.1016/S0966-6362(02)00190-X, apply exactly
/// this filter (fourth-order zero-lag Butterworth, 0.1 Hz cutoff) to the
/// doubly-integrated position signal; Lee et al., "A Novel Approach for
/// Improving Gait Speed Estimation Using a Single IMU Embedded in a
/// Smartphone", JMIR mHealth uHealth, 2024, https://doi.org/10.2196/52166, use
/// the same order at a 0.11 Hz cutoff. As with
/// [filterCadenceLowPassButterworth], this is a dependency-free
/// second-order-section cascade with a forward/backward pass rather than the
/// papers' exact filter implementation.
List<double> filterZeroPhaseHighPassButterworth(
  List<SensorSample> samples,
  List<double> values, {
  required double cutoffHz,
}) {
  assert(
    samples.length == values.length,
    'samples and values must have the same length',
  );
  if (values.length < 2) return List.of(values);

  final sampleInterval = medianSampleInterval(samples);
  if (sampleInterval <= Duration.zero) return List.of(values);

  final sampleRateHz =
      Duration.microsecondsPerSecond / sampleInterval.inMicroseconds;
  if (!sampleRateHz.isFinite || sampleRateHz <= 0) return List.of(values);

  final nyquistHz = sampleRateHz / 2;
  final boundedCutoffHz = math.min(cutoffHz, nyquistHz * 0.95);
  if (boundedCutoffHz <= 0) return List.of(values);

  final sections = _butterworthFourthOrderHighPassSections(
    cutoffHz: boundedCutoffHz,
    sampleRateHz: sampleRateHz,
  );
  final forward = _applyBiquadCascade(values, sections);
  final backwardInput = forward.reversed.toList(growable: false);
  final backward = _applyBiquadCascade(backwardInput, sections);

  return backward.reversed.toList(growable: false);
}

List<_BiquadCoefficients> _butterworthFourthOrderLowPassSections({
  required double cutoffHz,
  required double sampleRateHz,
}) {
  return [
    _lowPassBiquad(
      cutoffHz: cutoffHz,
      sampleRateHz: sampleRateHz,
      qualityFactor: 0.541196100146197,
    ),
    _lowPassBiquad(
      cutoffHz: cutoffHz,
      sampleRateHz: sampleRateHz,
      qualityFactor: 1.3065629648763766,
    ),
  ];
}

_BiquadCoefficients _lowPassBiquad({
  required double cutoffHz,
  required double sampleRateHz,
  required double qualityFactor,
}) {
  final omega = 2 * math.pi * cutoffHz / sampleRateHz;
  final sinOmega = math.sin(omega);
  final cosOmega = math.cos(omega);
  final alpha = sinOmega / (2 * qualityFactor);
  final b0 = (1 - cosOmega) / 2;
  final b1 = 1 - cosOmega;
  final b2 = (1 - cosOmega) / 2;
  final a0 = 1 + alpha;
  final a1 = -2 * cosOmega;
  final a2 = 1 - alpha;

  return _BiquadCoefficients(
    b0: b0 / a0,
    b1: b1 / a0,
    b2: b2 / a0,
    a1: a1 / a0,
    a2: a2 / a0,
  );
}

List<_BiquadCoefficients> _butterworthFourthOrderHighPassSections({
  required double cutoffHz,
  required double sampleRateHz,
}) {
  return [
    _highPassBiquad(
      cutoffHz: cutoffHz,
      sampleRateHz: sampleRateHz,
      qualityFactor: 0.541196100146197,
    ),
    _highPassBiquad(
      cutoffHz: cutoffHz,
      sampleRateHz: sampleRateHz,
      qualityFactor: 1.3065629648763766,
    ),
  ];
}

_BiquadCoefficients _highPassBiquad({
  required double cutoffHz,
  required double sampleRateHz,
  required double qualityFactor,
}) {
  final omega = 2 * math.pi * cutoffHz / sampleRateHz;
  final sinOmega = math.sin(omega);
  final cosOmega = math.cos(omega);
  final alpha = sinOmega / (2 * qualityFactor);
  final b0 = (1 + cosOmega) / 2;
  final b1 = -(1 + cosOmega);
  final b2 = (1 + cosOmega) / 2;
  final a0 = 1 + alpha;
  final a1 = -2 * cosOmega;
  final a2 = 1 - alpha;

  return _BiquadCoefficients(
    b0: b0 / a0,
    b1: b1 / a0,
    b2: b2 / a0,
    a1: a1 / a0,
    a2: a2 / a0,
  );
}

List<double> _applyBiquadCascade(
  List<double> values,
  List<_BiquadCoefficients> sections,
) {
  var filtered = List<double>.of(values, growable: false);
  for (final section in sections) {
    filtered = _applyBiquad(filtered, section);
  }
  return filtered;
}

List<double> _applyBiquad(
  List<double> values,
  _BiquadCoefficients coefficients,
) {
  final filtered = List<double>.filled(values.length, 0);
  var z1 = 0.0;
  var z2 = 0.0;
  for (var i = 0; i < values.length; i++) {
    final input = values[i];
    final output = coefficients.b0 * input + z1;
    z1 = coefficients.b1 * input - coefficients.a1 * output + z2;
    z2 = coefficients.b2 * input - coefficients.a2 * output;
    filtered[i] = output.isFinite ? output : 0;
  }
  return filtered;
}

class _BiquadCoefficients {
  const _BiquadCoefficients({
    required this.b0,
    required this.b1,
    required this.b2,
    required this.a1,
    required this.a2,
  });

  final double b0;
  final double b1;
  final double b2;
  final double a1;
  final double a2;
}
