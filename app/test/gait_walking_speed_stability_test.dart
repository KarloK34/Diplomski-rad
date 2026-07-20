import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:gait_sense/models/activity_prediction.dart';
import 'package:gait_sense/models/sensor_sample.dart';
import 'package:gait_sense/models/session_log.dart';
import 'package:gait_sense/utils/gait_cadence.dart';
import 'package:gait_sense/utils/gait_segments.dart';
import 'package:gait_sense/utils/gait_signal_segments.dart';
import 'package:gait_sense/utils/gait_walking_speed.dart';

/// Numerical-stability tests for the double-integration + high-pass step of
/// [analyzeGaitWalkingSpeed]. The concern (see docs/pregled-aplikacije-hodne-
/// metrike.md, §4/§5): recovering vertical displacement `h` by double
/// integration and a 0.1 Hz zero-phase high-pass is fragile on short segments,
/// so the estimate could depend on segment length or on a DC offset from
/// imperfect gravity subtraction. These tests pin down that it does not, for a
/// clean synthetic signal.
///
/// A failure here is a real finding to investigate (integration/filter
/// instability), not a flaky test.
void main() {
  final start = DateTime.utc(2026, 1, 1, 12);

  SensorSample sampleAt(int index, {double verticalAcceleration = 0}) {
    // gravityZ: 1 means g_hat = [0,0,1], so aV = userAccelerationZ directly.
    return SensorSample(
      timestamp: start.add(Duration(milliseconds: index * 20)),
      gravityX: 0,
      gravityY: 0,
      gravityZ: 1,
      userAccelerationX: 0,
      userAccelerationY: 0,
      userAccelerationZ: verticalAcceleration,
      rotationRateX: 0,
      rotationRateY: 0,
      rotationRateZ: 0,
    );
  }

  /// [count] samples of a sinusoidal vertical acceleration (g units) at
  /// [frequencyHz], optionally shifted by a constant [offsetG].
  List<SensorSample> sinusoidalSamples({
    required int count,
    required double frequencyHz,
    required double amplitudeG,
    double offsetG = 0,
  }) {
    return [
      for (var i = 0; i < count; i++)
        sampleAt(
          i,
          verticalAcceleration:
              offsetG +
              amplitudeG * math.sin(2 * math.pi * frequencyHz * i * 0.02),
        ),
    ];
  }

  ActivityPrediction predictionAt(int secondsAfterStart, int endIndex) {
    return ActivityPrediction(
      label: 'wlk',
      probabilities: const [0.1, 0.1, 0.5, 0.1, 0.1, 0.1],
      timestamp: start.add(Duration(seconds: secondsAfterStart)),
      endSampleIndex: endIndex,
      inferenceLatencyMs: 10,
    );
  }

  GaitCadenceResult computedCadenceResult() {
    return const GaitCadenceResult(
      stepCount: 5,
      cadenceStepsPerMinute: 120,
      peakCadenceStepsPerMinute: 120,
      periodCadenceStepsPerMinute: 120,
      dominantPeriod: Duration(milliseconds: 500),
      periodicity: 0.9,
      adaptiveThreshold: 0.01,
      minimumPeakInterval: Duration(milliseconds: 250),
      duration: Duration(seconds: 5),
      detectedStepSampleIndices: [0, 25, 50, 75, 100],
      detectedStepOffsets: [
        Duration.zero,
        Duration(milliseconds: 500),
        Duration(milliseconds: 1000),
        Duration(milliseconds: 1500),
        Duration(milliseconds: 2000),
      ],
      status: GaitCadenceStatus.computed,
      reason: null,
      confidence: GaitCadenceConfidence.high,
      confidenceReason: null,
    );
  }

  /// Builds the first suitable signal segment from a `wlk` session whose
  /// prediction sample-index bounds span [endIndices]. With windowSize 128 the
  /// resulting raw-sample slice is [firstEnd - 127, lastEnd + 1).
  GaitSignalSegment segmentFor(
    List<SensorSample> samples,
    List<int> endIndices,
  ) {
    final session = SessionLog(
      startedAt: start,
      stoppedAt: start.add(const Duration(seconds: 30)),
      modelInfo: const {},
      rawSamples: samples,
      predictions: [
        for (var i = 0; i < endIndices.length; i++)
          predictionAt(3 + i, endIndices[i]),
      ],
    );
    final gaitSegments = extractGaitSegments(session);
    final signalSegments = extractGaitSignalSegments(
      session,
      gaitSegments: gaitSegments,
    );
    return signalSegments.first;
  }

  group('analyzeGaitWalkingSpeed numerical stability', () {
    test(
      'step length is insensitive to a DC offset in the vertical signal',
      () {
        // A DC offset models imperfect gravity subtraction; mean removal in
        // the estimator should absorb it, leaving the estimate essentially
        // unchanged.
        const endIndices = [191, 255, 319, 383, 447];
        final clean = sinusoidalSamples(
          count: 500,
          frequencyHz: 2,
          amplitudeG: 0.2,
        );
        final offset = sinusoidalSamples(
          count: 500,
          frequencyHz: 2,
          amplitudeG: 0.2,
          offsetG: 0.05,
        );

        final cleanResult = analyzeGaitWalkingSpeed(
          segmentFor(clean, endIndices),
          cadenceResult: computedCadenceResult(),
          userHeightCm: 175,
        );
        final offsetResult = analyzeGaitWalkingSpeed(
          segmentFor(offset, endIndices),
          cadenceResult: computedCadenceResult(),
          userHeightCm: 175,
        );

        expect(cleanResult.isComputed, isTrue);
        expect(offsetResult.isComputed, isTrue);
        expect(
          offsetResult.stepLengthM,
          closeTo(cleanResult.stepLengthM, cleanResult.stepLengthM * 0.05),
        );
      },
    );

    test(
      'step length is consistent across a short and a long clean segment',
      () {
        // Same 2 Hz signal, same detected steps (first 2 s), but a ~7.7 s vs a
        // ~15.4 s segment. Only the length of the doubly-integrated, high-pass-
        // filtered position signal differs, so this isolates the estimate's
        // sensitivity to segment length / filter edge effects.
        final samples = sinusoidalSamples(
          count: 900,
          frequencyHz: 2,
          amplitudeG: 0.2,
        );

        final shortResult = analyzeGaitWalkingSpeed(
          segmentFor(samples, const [191, 255, 319, 383, 447]),
          cadenceResult: computedCadenceResult(),
          userHeightCm: 175,
        );
        final longResult = analyzeGaitWalkingSpeed(
          segmentFor(
            samples,
            const [191, 255, 319, 383, 447, 511, 575, 639, 703, 767, 831],
          ),
          cadenceResult: computedCadenceResult(),
          userHeightCm: 175,
        );

        expect(shortResult.isComputed, isTrue);
        expect(longResult.isComputed, isTrue);
        // If this bound fails, the double-integration/high-pass step is
        // length-sensitive and the speed estimate should not be trusted on
        // short recordings without a fix.
        expect(
          longResult.stepLengthM,
          closeTo(shortResult.stepLengthM, shortResult.stepLengthM * 0.25),
        );
      },
    );
  });
}
