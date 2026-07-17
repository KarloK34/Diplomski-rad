import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:gait_sense/models/activity_prediction.dart';
import 'package:gait_sense/models/sensor_sample.dart';
import 'package:gait_sense/models/session_log.dart';
import 'package:gait_sense/utils/gait_cadence.dart';
import 'package:gait_sense/utils/gait_segments.dart';
import 'package:gait_sense/utils/gait_signal_segments.dart';
import 'package:gait_sense/utils/gait_walking_speed.dart';
import 'package:gait_sense/utils/sensor_conversion.dart';

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
    GaitCadenceConfidence confidence = GaitCadenceConfidence.high,
    String? confidenceReason,
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
      confidence: confidence,
      confidenceReason: confidenceReason,
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

    test('returns unavailable when cadence confidence is low', () {
      final samples = sinusoidalSamples(
        count: 300,
        frequencyHz: 2,
        amplitudeG: 0.08,
      );
      final segment = segmentFromSamples(samples);

      final result = analyzeGaitWalkingSpeed(
        segment,
        cadenceResult: computedCadenceResult(
          confidence: GaitCadenceConfidence.low,
          confidenceReason: cadenceEstimatesDisagreeReason,
        ),
        userHeightCm: 175,
      );

      expect(result.isComputed, isFalse);
      expect(result.status, GaitWalkingSpeedStatus.unavailable);
      expect(result.reason, lowConfidenceCadenceReason);
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
      // 2 Hz vertical acceleration with a 120 spm cadence (frequencyHz here is
      // the step frequency, cadenceSpm / 60 — one CoM oscillation per step,
      // per Zijlstra & Hof, https://doi.org/10.1016/S0966-6362(02)00190-X).
      const frequencyHz = 2.0;
      const amplitudeG = 0.20;
      const cadenceStepsPerMinute = 120.0;
      const userHeightCm = 175.0;

      final samples = sinusoidalSamples(
        count: 500,
        frequencyHz: frequencyHz,
        amplitudeG: amplitudeG,
      );
      final segment = segmentFromSamples(samples);

      final result = analyzeGaitWalkingSpeed(
        segment,
        cadenceResult: computedCadenceResult(),
        userHeightCm: userHeightCm,
      );

      expect(result.isComputed, isTrue);

      // Independent ground truth from the underlying physics, not from the
      // implementation under test: for a clean sinusoidal vertical
      // acceleration a(t) = amplitudeG*g*sin(2*pi*f*t), the peak-to-peak
      // vertical displacement is h = 2*a_peak/omega^2 (SHO relationship,
      // using the peak amplitude and the signal's own angular frequency —
      // not RMS and not cadence/2).
      // Measured against this reference, the double-integration
      // implementation agrees to within ~1-2% for this synthetic signal, so
      // the 5% tolerance below is tight enough to catch a regression to the
      // pre-fix RMS/omega-halving/uncorrected formula: reconstructing that
      // formula from the same measured rmsAmplitude gives a step length only
      // ~7% away from this expected value (not the much larger miss a naive
      // dimensional-analysis estimate suggests), which is what this bound is
      // sized to reject.
      const legLengthM = userHeightCm / 100.0 * kLegLengthHeightRatio;
      const omega = 2 * math.pi * frequencyHz;
      const amplitudeMs2 = amplitudeG * kStandardGravity;
      const expectedH = 2 * amplitudeMs2 / (omega * omega);
      const expectedDiscriminant =
          2 * legLengthM * expectedH - expectedH * expectedH;
      final expectedRawStepLengthM = 2 * math.sqrt(expectedDiscriminant);
      final expectedStepLengthM =
          expectedRawStepLengthM *
          leeStepLengthCorrectionFactor(expectedRawStepLengthM);
      final expectedSpeedMs =
          expectedStepLengthM * cadenceStepsPerMinute / 60.0;

      expect(
        result.stepLengthM,
        closeTo(expectedStepLengthM, expectedStepLengthM * 0.05),
      );
      expect(
        result.walkingSpeedMs,
        closeTo(expectedSpeedMs, expectedSpeedMs * 0.05),
      );
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

    test(
      'leeStepLengthCorrectionFactor matches Lee et al. (2024) per-range '
      'coefficients',
      () {
        // Table 1 / Eq. 2 of Lee et al., https://doi.org/10.2196/52166:
        // raw estimate in [0.2, 0.5) m -> x1.37, [0.5, 0.8) m -> x1.02,
        // [0.8, 1.1] m -> x0.74.
        expect(leeStepLengthCorrectionFactor(0.35), 1.37);
        expect(leeStepLengthCorrectionFactor(0.65), 1.02);
        expect(leeStepLengthCorrectionFactor(0.95), 0.74);
      },
    );

    test('leeStepLengthCorrectionFactor bin boundaries are half-open', () {
      expect(
        leeStepLengthCorrectionFactor(kLeeShortStepLengthBoundM),
        kLeeMediumStepCorrectionFactor,
      );
      expect(
        leeStepLengthCorrectionFactor(kLeeMediumStepLengthBoundM),
        kLeeLongStepCorrectionFactor,
      );
    });

    test(
      'kVerticalDisplacementHighPassCutoffHz is 0.1 Hz (Zijlstra & Hof, 2003)',
      () {
        expect(kVerticalDisplacementHighPassCutoffHz, 0.1);
      },
    );
  });
}
