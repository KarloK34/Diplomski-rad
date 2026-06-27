import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:gait_sense/models/activity_prediction.dart';
import 'package:gait_sense/models/sensor_sample.dart';
import 'package:gait_sense/models/session_log.dart';
import 'package:gait_sense/utils/gait_cadence.dart';
import 'package:gait_sense/utils/gait_segments.dart';
import 'package:gait_sense/utils/gait_signal_segments.dart';
import 'package:gait_sense/utils/gait_walking_speed.dart';

void main() {
  final start = DateTime.utc(2026, 1, 1, 12);

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  // gravityZ: 1 means g_hat = [0,0,1], so aV = userAccelerationZ directly.
  SensorSample sampleAt(
    int index, {
    double verticalAcceleration = 0,
  }) {
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

  /// Generates [count] samples with a sinusoidal vertical acceleration at
  /// [frequencyHz]. The amplitude [amplitudeG] is in standard gravity units.
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

  GaitCadenceResult computedCadenceResult({
    double cadenceStepsPerMinute = 120,
    Duration duration = const Duration(seconds: 5),
  }) {
    return GaitCadenceResult(
      stepCount: 10,
      cadenceStepsPerMinute: cadenceStepsPerMinute,
      peakCadenceStepsPerMinute: cadenceStepsPerMinute,
      periodCadenceStepsPerMinute: cadenceStepsPerMinute,
      dominantPeriod: const Duration(milliseconds: 500),
      periodicity: 0.9,
      adaptiveThreshold: 0.01,
      minimumPeakInterval: const Duration(milliseconds: 250),
      duration: duration,
      detectedStepSampleIndices: const [0, 25, 50, 75, 100],
      detectedStepOffsets: const [
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

  /// Builds a [GaitSignalSegment] with [samples] directly (bypasses the full
  /// SessionLog pipeline so tests can control signal contents precisely).
  GaitSignalSegment segmentFromSamples(List<SensorSample> samples) {
    final session = SessionLog(
      startedAt: start,
      stoppedAt: start.add(const Duration(seconds: 30)),
      modelInfo: const {},
      rawSamples: samples,
      predictions: [
        predictionAt(3, 127 + 64),
        predictionAt(4, 127 + 128),
        predictionAt(5, 127 + 192),
        predictionAt(6, 127 + 256),
        predictionAt(8, 127 + 320),
      ],
    );
    final gaitSegments = extractGaitSegments(session);
    final signalSegments = extractGaitSignalSegments(
      session,
      gaitSegments: gaitSegments,
    );
    // Return first suitable segment, or a synthetic empty one for failure
    // tests.
    if (signalSegments.isNotEmpty) return signalSegments.first;
    return GaitSignalSegment(
      gaitSegment: gaitSegments.first,
      samples: samples,
      startSampleIndex: 0,
      endSampleIndexExclusive: samples.length,
      boundarySource: GaitSignalSegmentBoundarySource.sampleIndex,
      emptyReason: null,
    );
  }

  // ---------------------------------------------------------------------------
  // analyzeGaitWalkingSpeed
  // ---------------------------------------------------------------------------

  group('analyzeGaitWalkingSpeed', () {
    test('returns unavailable when cadence result is not computed', () {
      final samples = sinusoidalSamples(
        count: 300,
        frequencyHz: 2,
        amplitudeG: 0.08,
      );
      final segment = segmentFromSamples(samples);

      // Force a not-computed cadence result.
      const notComputedResult = GaitCadenceResult(
        stepCount: 0,
        cadenceStepsPerMinute: 0,
        peakCadenceStepsPerMinute: null,
        periodCadenceStepsPerMinute: null,
        dominantPeriod: null,
        periodicity: null,
        adaptiveThreshold: null,
        minimumPeakInterval: null,
        duration: Duration.zero,
        detectedStepSampleIndices: [],
        detectedStepOffsets: [],
        status: GaitCadenceStatus.empty,
        reason: 'empty_signal',
        confidence: GaitCadenceConfidence.low,
        confidenceReason: 'empty_signal',
      );

      final result = analyzeGaitWalkingSpeed(
        segment,
        cadenceResult: notComputedResult,
        userHeightCm: 175,
      );

      expect(result.isComputed, isFalse);
      expect(result.status, GaitWalkingSpeedStatus.unavailable);
      expect(result.reason, cadenceNotComputedReason);
    });

    test('returns unavailable when segment has no samples', () {
      final samples = sinusoidalSamples(
        count: 300,
        frequencyHz: 2,
        amplitudeG: 0.08,
      );
      final segment = segmentFromSamples(samples);
      final emptySegment = GaitSignalSegment(
        gaitSegment: segment.gaitSegment,
        samples: const [],
        startSampleIndex: null,
        endSampleIndexExclusive: null,
        boundarySource: null,
        emptyReason: 'missing_raw_samples',
      );

      final result = analyzeGaitWalkingSpeed(
        emptySegment,
        cadenceResult: computedCadenceResult(),
        userHeightCm: 175,
      );

      expect(result.isComputed, isFalse);
      expect(result.status, GaitWalkingSpeedStatus.unavailable);
    });

    test('returns unavailable when vertical amplitude is too small', () {
      // Flat signal: no vertical movement.
      final samples = [
        for (var i = 0; i < 500; i++) sampleAt(i),
      ];
      final segment = segmentFromSamples(samples);
      final result = analyzeGaitWalkingSpeed(
        segment,
        cadenceResult: computedCadenceResult(),
        userHeightCm: 175,
      );
      expect(result.isComputed, isFalse);
      expect(result.reason, insufficientVerticalAmplitudeReason);
    });

    test('produces a plausible speed for a synthetic 2 Hz walking signal', () {
      // 2 Hz vertical acceleration with a 120 spm cadence.
      // For height 175 cm, leg length is about 0.928 m.
      // At reasonable amplitude the inverted pendulum should yield a step
      // length in [0.4, 0.9 m] and speed in [0.8, 1.8 m/s].
      final samples = sinusoidalSamples(
        count: 500,
        frequencyHz: 2,
        amplitudeG: 0.20,
      );
      final segment = segmentFromSamples(samples);

      final result = analyzeGaitWalkingSpeed(
        segment,
        cadenceResult: computedCadenceResult(),
        userHeightCm: 175,
      );

      expect(result.isComputed, isTrue);
      expect(result.stepLengthM, greaterThan(kMinPlausibleStepLengthM));
      expect(result.stepLengthM, lessThan(kMaxPlausibleStepLengthM));
      expect(result.walkingSpeedMs, greaterThan(0.5));
      expect(result.walkingSpeedMs, lessThan(3.0));
    });

    test('legLengthM is 0.53 times userHeightCm / 100', () {
      final samples = sinusoidalSamples(
        count: 500,
        frequencyHz: 2,
        amplitudeG: 0.20,
      );
      final segment = segmentFromSamples(samples);

      final result = analyzeGaitWalkingSpeed(
        segment,
        cadenceResult: computedCadenceResult(),
        userHeightCm: 180,
      );

      expect(result.isComputed, isTrue);
      expect(
        result.legLengthM,
        closeTo(180 / 100 * kLegLengthHeightRatio, 1e-9),
      );
    });

    test('taller user produces longer estimated step length', () {
      final samples = sinusoidalSamples(
        count: 500,
        frequencyHz: 2,
        amplitudeG: 0.20,
      );
      final segment = segmentFromSamples(samples);

      final short = analyzeGaitWalkingSpeed(
        segment,
        cadenceResult: computedCadenceResult(),
        userHeightCm: 160,
      );
      final tall = analyzeGaitWalkingSpeed(
        segment,
        cadenceResult: computedCadenceResult(),
        userHeightCm: 190,
      );

      expect(short.isComputed, isTrue);
      expect(tall.isComputed, isTrue);
      // Taller person means longer leg and longer step for the same
      // displacement.
      expect(tall.stepLengthM, greaterThan(short.stepLengthM));
    });
  });

  // ---------------------------------------------------------------------------
  // Constants
  // ---------------------------------------------------------------------------

  group('constants', () {
    test('kLegLengthHeightRatio is 0.53', () {
      expect(kLegLengthHeightRatio, 0.53);
    });

    test('plausible step length range is sane', () {
      expect(kMinPlausibleStepLengthM, lessThan(kMaxPlausibleStepLengthM));
      expect(kMinPlausibleStepLengthM, greaterThan(0));
    });
  });
}
