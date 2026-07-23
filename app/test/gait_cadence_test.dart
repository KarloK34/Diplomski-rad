import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:gait_sense/models/activity_prediction.dart';
import 'package:gait_sense/models/sensor_sample.dart';
import 'package:gait_sense/models/session_log.dart';
import 'package:gait_sense/utils/gait_cadence.dart';
import 'package:gait_sense/utils/gait_segments.dart';
import 'package:gait_sense/utils/gait_signal_segments.dart';
import 'package:gait_sense/utils/gait_temporal_parameters.dart';
import 'package:gait_sense/utils/gait_walking_speed.dart'
    show kVerticalDisplacementHighPassCutoffHz;

void main() {
  final start = DateTime.utc(2026, 1, 1, 12);

  SensorSample sampleAt(
    int index, {
    DateTime? timestamp,
    double projectedAcceleration = 0,
    double rotationRateZ = 0,
  }) {
    return SensorSample(
      timestamp: timestamp ?? start.add(Duration(milliseconds: index * 20)),
      gravityX: 0,
      gravityY: 0,
      gravityZ: 1,
      userAccelerationX: 0,
      userAccelerationY: 0,
      userAccelerationZ: projectedAcceleration,
      rotationRateX: 0,
      rotationRateY: 0,
      rotationRateZ: rotationRateZ,
    );
  }

  List<SensorSample> periodicSamples(int count) {
    return [
      for (var i = 0; i < count; i++)
        sampleAt(
          i,
          projectedAcceleration:
              0.06 + 0.08 * (1 + math.sin(2 * math.pi * 2 * i * 0.02)) / 2,
        ),
    ];
  }

  List<SensorSample> stepPulseSamples({
    required int stepCount,
    required double stepPeriodSeconds,
    required double secondaryPeakOffsetSeconds,
    double secondaryPeakScale = 0.7,
  }) {
    const samplePeriodSeconds = 0.02;
    const firstStepSeconds = 0.8;
    const pulseWidthSeconds = 0.045;
    final durationSeconds =
        firstStepSeconds + (stepCount - 1) * stepPeriodSeconds + 0.8;
    final sampleCount = (durationSeconds / samplePeriodSeconds).ceil() + 1;

    double pulse(double time, double center) {
      final normalized = (time - center) / pulseWidthSeconds;
      return math.exp(-0.5 * normalized * normalized);
    }

    return [
      for (var i = 0; i < sampleCount; i++)
        sampleAt(
          i,
          projectedAcceleration: () {
            final time = i * samplePeriodSeconds;
            var magnitude = 0.01;
            for (var step = 0; step < stepCount; step++) {
              final primary = firstStepSeconds + step * stepPeriodSeconds;
              magnitude += pulse(time, primary);
              magnitude +=
                  secondaryPeakScale *
                  pulse(time, primary + secondaryPeakOffsetSeconds);
            }
            return magnitude;
          }(),
        ),
    ];
  }

  List<SensorSample> pocketSwingSamples({
    required int stepCount,
    required double stepPeriodSeconds,
  }) {
    const samplePeriodSeconds = 0.02;
    const firstStepSeconds = 0.7;
    const pulseWidthSeconds = 0.05;
    final durationSeconds =
        firstStepSeconds + (stepCount - 1) * stepPeriodSeconds + 0.9;
    final sampleCount = (durationSeconds / samplePeriodSeconds).ceil() + 1;

    double pulse(double time, double center) {
      final normalized = (time - center) / pulseWidthSeconds;
      return math.exp(-0.5 * normalized * normalized);
    }

    return [
      for (var i = 0; i < sampleCount; i++)
        sampleAt(
          i,
          projectedAcceleration: () {
            final time = i * samplePeriodSeconds;
            var magnitude = 0.01;
            for (var step = 0; step < stepCount; step += 2) {
              final center = firstStepSeconds + step * stepPeriodSeconds;
              magnitude += 0.9 * pulse(time, center);
            }
            return magnitude;
          }(),
          rotationRateZ: () {
            final time = i * samplePeriodSeconds;
            var magnitude = 0.02;
            for (var step = 0; step < stepCount; step++) {
              final center = firstStepSeconds + step * stepPeriodSeconds;
              magnitude += 2.5 * pulse(time, center);
            }
            return magnitude;
          }(),
        ),
    ];
  }

  List<SensorSample> boundaryArtifactSamples({
    required int sampleCount,
    required double accelerationPeriodSeconds,
    required int gyroStepCount,
    required double gyroStepPeriodSeconds,
  }) {
    const samplePeriodSeconds = 0.02;
    const gyroFirstStepSeconds = 0.5;
    const gyroPulseWidthSeconds = 0.045;

    double gyroPulse(double time, double center) {
      final normalized = (time - center) / gyroPulseWidthSeconds;
      return math.exp(-0.5 * normalized * normalized);
    }

    return [
      for (var i = 0; i < sampleCount; i++)
        sampleAt(
          i,
          projectedAcceleration:
              0.06 +
              0.1 *
                  math.sin(
                    2 *
                        math.pi *
                        i *
                        samplePeriodSeconds /
                        accelerationPeriodSeconds,
                  ),
          rotationRateZ: () {
            final time = i * samplePeriodSeconds;
            var magnitude = 0.02;
            for (var step = 0; step < gyroStepCount; step++) {
              final center =
                  gyroFirstStepSeconds + step * gyroStepPeriodSeconds;
              magnitude += 2.0 * gyroPulse(time, center);
            }
            return magnitude;
          }(),
        ),
    ];
  }

  ActivityPrediction predictionAt(int millisecondsAfterStart, int endIndex) {
    return ActivityPrediction(
      label: 'wlk',
      probabilities: const [0.1, 0.1, 0.5, 0.1, 0.1, 0.1],
      timestamp: start.add(Duration(milliseconds: millisecondsAfterStart)),
      endSampleIndex: endIndex,
      inferenceLatencyMs: 10,
    );
  }

  GaitCadenceResult computedResultFromOffsets(
    List<Duration> offsets, {
    double periodicity = 0.5,
  }) {
    final duration = offsets.isEmpty ? Duration.zero : offsets.last;
    return GaitCadenceResult(
      stepCount: offsets.length,
      cadenceStepsPerMinute: 0,
      peakCadenceStepsPerMinute: null,
      periodCadenceStepsPerMinute: null,
      dominantPeriod: null,
      periodicity: periodicity,
      adaptiveThreshold: null,
      minimumPeakInterval: null,
      duration: duration,
      detectedStepSampleIndices: [
        for (var i = 0; i < offsets.length; i++) i,
      ],
      detectedStepOffsets: offsets,
      status: GaitCadenceStatus.computed,
      reason: null,
      confidence: GaitCadenceConfidence.moderate,
      confidenceReason: null,
    );
  }

  List<SensorSample> timestampSamples(int count) {
    return [for (var i = 0; i < count; i++) sampleAt(i)];
  }

  List<double> sineSignal({
    required int count,
    required double frequencyHz,
    double samplePeriodSeconds = 0.02,
  }) {
    return [
      for (var i = 0; i < count; i++)
        math.sin(2 * math.pi * frequencyHz * i * samplePeriodSeconds),
    ];
  }

  double trimmedRms(List<double> values, {required int trim}) {
    final trimmed = values.sublist(trim, values.length - trim);
    final meanSquare =
        trimmed
            .map((value) => value * value)
            .reduce((left, right) => left + right) /
        trimmed.length;
    return math.sqrt(meanSquare);
  }

  int maxIndex(List<double> values) {
    var selectedIndex = 0;
    var selectedValue = values.first;
    for (var i = 1; i < values.length; i++) {
      if (values[i] > selectedValue) {
        selectedIndex = i;
        selectedValue = values[i];
      }
    }
    return selectedIndex;
  }

  test('returns empty and insufficient results for unusable input', () {
    final empty = analyzeGaitCadenceSamples(const []);

    expect(empty.status, GaitCadenceStatus.empty);
    expect(empty.reason, emptyCadenceSignalReason);
    expect(empty.stepCount, 0);
    expect(empty.duration, Duration.zero);

    final tooShort = analyzeGaitCadenceSamples([
      sampleAt(0),
      sampleAt(1),
    ]);

    expect(tooShort.status, GaitCadenceStatus.insufficientSignal);
    expect(tooShort.reason, cadenceSignalTooShortReason);
    expect(tooShort.stepCount, 0);
    expect(tooShort.duration, const Duration(milliseconds: 20));
  });

  test('computes temporal parameters from uniform step intervals', () {
    final result = computedResultFromOffsets(
      [
        Duration.zero,
        const Duration(milliseconds: 500),
        const Duration(milliseconds: 1000),
        const Duration(milliseconds: 1500),
        const Duration(milliseconds: 2000),
      ],
      periodicity: 0.42,
    );

    final temporal = computeGaitTemporalParameters(result);

    expect(temporal, isNotNull);
    expect(temporal!.stepIntervalCount, 4);
    expect(temporal.meanStepTime, const Duration(milliseconds: 500));
    expect(temporal.medianStepTime, const Duration(milliseconds: 500));
    expect(temporal.stepTimeStandardDeviation, Duration.zero);
    expect(temporal.stepTimeCoefficientOfVariation, closeTo(0, 1e-12));
    expect(temporal.minimumStepTime, const Duration(milliseconds: 500));
    expect(temporal.maximumStepTime, const Duration(milliseconds: 500));
    expect(temporal.strideIntervalCount, 3);
    expect(temporal.meanStrideTime, const Duration(milliseconds: 1000));
    expect(temporal.strideTimeStandardDeviation, Duration.zero);
    expect(temporal.strideTimeCoefficientOfVariation, closeTo(0, 1e-12));
    expect(temporal.meanInstantCadenceStepsPerMinute, closeTo(120, 1e-9));
    expect(
      temporal.instantCadenceStandardDeviationStepsPerMinute,
      closeTo(0, 1e-12),
    );
    expect(temporal.instantCadenceCoefficientOfVariation, closeTo(0, 1e-12));
    expect(temporal.gaitRegularity, closeTo(0.42, 1e-12));
  });

  test(
    'strideIntervalCount stays below the minimum stride-interval threshold '
    'for a short recording and reaches it for a long one',
    () {
      final shortResult = computedResultFromOffsets([
        Duration.zero,
        const Duration(milliseconds: 500),
        const Duration(milliseconds: 1000),
        const Duration(milliseconds: 1500),
        const Duration(milliseconds: 2000),
      ]);
      final shortTemporal = computeGaitTemporalParameters(shortResult);

      expect(shortTemporal, isNotNull);
      expect(
        shortTemporal!.strideIntervalCount,
        lessThan(defaultTemporalVariabilityMinimumStrideIntervals),
      );

      final longOffsets = [
        for (
          var i = 0;
          i <= defaultTemporalVariabilityMinimumStrideIntervals + 2;
          i++
        )
          Duration(milliseconds: 500 * i),
      ];
      final longResult = computedResultFromOffsets(longOffsets);
      final longTemporal = computeGaitTemporalParameters(longResult);

      expect(longTemporal, isNotNull);
      expect(
        longTemporal!.strideIntervalCount,
        greaterThanOrEqualTo(defaultTemporalVariabilityMinimumStrideIntervals),
      );
    },
  );

  test('computes temporal variability from uneven step intervals', () {
    final result = computedResultFromOffsets(
      [
        Duration.zero,
        const Duration(milliseconds: 500),
        const Duration(milliseconds: 1100),
        const Duration(milliseconds: 1800),
      ],
    );

    final temporal = computeGaitTemporalParameters(result);

    expect(temporal, isNotNull);
    expect(temporal!.stepIntervalCount, 3);
    expect(temporal.meanStepTime, const Duration(milliseconds: 600));
    expect(temporal.medianStepTime, const Duration(milliseconds: 600));
    expect(
      temporal.stepTimeStandardDeviation.inMicroseconds,
      closeTo(81650, 1),
    );
    expect(
      temporal.stepTimeCoefficientOfVariation,
      closeTo(0.136083, 1e-6),
    );
    expect(temporal.minimumStepTime, const Duration(milliseconds: 500));
    expect(temporal.maximumStepTime, const Duration(milliseconds: 700));
    expect(temporal.strideIntervalCount, 2);
    expect(temporal.meanStrideTime, const Duration(milliseconds: 1200));
    expect(
      temporal.strideTimeStandardDeviation,
      const Duration(milliseconds: 100),
    );
    expect(
      temporal.strideTimeCoefficientOfVariation,
      closeTo(1 / 12, 1e-6),
    );
    expect(
      temporal.meanInstantCadenceStepsPerMinute,
      closeTo(101.9047619, 1e-6),
    );
  });

  test('aggregates temporal parameters without crossing segment gaps', () {
    final first = computedResultFromOffsets(
      [
        Duration.zero,
        const Duration(milliseconds: 500),
        const Duration(milliseconds: 1000),
      ],
      periodicity: 0.4,
    );
    final second = computedResultFromOffsets(
      [
        Duration.zero,
        const Duration(milliseconds: 600),
        const Duration(milliseconds: 1200),
        const Duration(milliseconds: 1800),
      ],
      periodicity: 0.7,
    );

    final temporal = summarizeGaitTemporalParameters([first, second]);

    expect(temporal, isNotNull);
    expect(temporal!.stepIntervalCount, 5);
    expect(temporal.meanStepTime, const Duration(milliseconds: 560));
    expect(temporal.minimumStepTime, const Duration(milliseconds: 500));
    expect(temporal.maximumStepTime, const Duration(milliseconds: 600));
    expect(temporal.strideIntervalCount, 3);
    expect(temporal.meanStrideTime, const Duration(microseconds: 1133333));
    expect(temporal.gaitRegularity, closeTo(0.58, 1e-12));
  });

  test('returns no temporal parameters without consecutive steps', () {
    final result = computedResultFromOffsets([Duration.zero]);

    expect(computeGaitTemporalParameters(result), isNull);
    expect(summarizeGaitTemporalParameters([result]), isNull);
  });

  test('leaves stride metrics empty without same-side intervals', () {
    final result = computedResultFromOffsets([
      Duration.zero,
      const Duration(milliseconds: 500),
    ]);

    final temporal = computeGaitTemporalParameters(result);

    expect(temporal, isNotNull);
    expect(temporal!.stepIntervalCount, 1);
    expect(temporal.strideIntervalCount, 0);
    expect(temporal.meanStrideTime, isNull);
    expect(temporal.strideTimeStandardDeviation, isNull);
    expect(temporal.strideTimeCoefficientOfVariation, isNull);
  });

  test('filters isolated temporal outliers from variability summaries', () {
    final result = computedResultFromOffsets([
      Duration.zero,
      const Duration(milliseconds: 500),
      const Duration(milliseconds: 1000),
      const Duration(milliseconds: 1500),
      const Duration(milliseconds: 2000),
      const Duration(milliseconds: 3000),
      const Duration(milliseconds: 3500),
    ]);

    final temporal = computeGaitTemporalParameters(result);

    expect(temporal, isNotNull);
    expect(temporal!.stepIntervalCount, 5);
    expect(temporal.meanStepTime, const Duration(milliseconds: 500));
    expect(temporal.stepTimeStandardDeviation, Duration.zero);
    expect(temporal.strideIntervalCount, 3);
    expect(temporal.meanStrideTime, const Duration(milliseconds: 1000));
  });

  test('Butterworth preprocessing has the expected low-pass response', () {
    const sampleCount = 2000;
    const trim = 250;
    final samples = timestampSamples(sampleCount);

    double responseRatio(double frequencyHz) {
      final input = sineSignal(count: sampleCount, frequencyHz: frequencyHz);
      final output = filterCadenceLowPassButterworth(
        samples,
        input,
        cutoffHz: defaultCadenceLowPassCutoffHz,
      );
      return trimmedRms(output, trim: trim) / trimmedRms(input, trim: trim);
    }

    final passbandRatio = responseRatio(1);
    final cutoffRatio = responseRatio(defaultCadenceLowPassCutoffHz);
    final stopbandRatio = responseRatio(5);

    expect(passbandRatio, closeTo(1, 0.02));
    expect(cutoffRatio, closeTo(0.5, 0.06));
    expect(stopbandRatio, lessThan(0.05));
    expect(passbandRatio, greaterThan(cutoffRatio));
    expect(cutoffRatio, greaterThan(stopbandRatio));
  });

  test('forward backward preprocessing keeps a centered pulse aligned', () {
    const sampleCount = 801;
    const centerIndex = sampleCount ~/ 2;
    final samples = timestampSamples(sampleCount);
    final input = [
      for (var i = 0; i < sampleCount; i++)
        math.exp(-0.5 * math.pow((i - centerIndex) / 8, 2)),
    ];

    final output = filterCadenceLowPassButterworth(
      samples,
      input,
      cutoffHz: defaultCadenceLowPassCutoffHz,
    );

    expect(maxIndex(output), closeTo(centerIndex, 1));
  });

  test('zero-phase high-pass preprocessing has the expected response', () {
    // Uses the production vertical-displacement cutoff (0.1 Hz) so this
    // characterizes the filter as it is actually applied in
    // gait_walking_speed.dart to bound double-integration drift (W1,
    // docs/audit-hodne-metrike.md).
    const cutoffHz = kVerticalDisplacementHighPassCutoffHz;
    const sampleCount = 20000; // 400 s at 50 Hz — several cycles at 0.02 Hz.
    const trim = 2000;
    final samples = timestampSamples(sampleCount);

    double responseRatio(double frequencyHz) {
      final input = sineSignal(count: sampleCount, frequencyHz: frequencyHz);
      final output = filterZeroPhaseHighPassButterworth(
        samples,
        input,
        cutoffHz: cutoffHz,
      );
      return trimmedRms(output, trim: trim) / trimmedRms(input, trim: trim);
    }

    final passbandRatio = responseRatio(0.5);
    final cutoffRatio = responseRatio(cutoffHz);
    final stopbandRatio = responseRatio(0.02);

    expect(passbandRatio, closeTo(1, 0.02));
    expect(cutoffRatio, closeTo(0.5, 0.06));
    expect(stopbandRatio, lessThan(0.01));
    expect(passbandRatio, greaterThan(cutoffRatio));
    expect(cutoffRatio, greaterThan(stopbandRatio));
  });

  test(
    'detects expected steps in a synthetic periodic acceleration signal',
    () {
      final result = analyzeGaitCadenceSamples(periodicSamples(300));

      expect(result.status, GaitCadenceStatus.computed);
      expect(result.reason, isNull);
      expect(
        result.stepCount,
        12,
        reason:
            'period=${result.dominantPeriod}, '
            'periodicity=${result.periodicity}, '
            'minimumInterval=${result.minimumPeakInterval}',
      );
      expect(result.detectedStepSampleIndices, hasLength(12));
      expect(result.detectedStepOffsets, hasLength(12));
      expect(result.duration, const Duration(milliseconds: 5980));
      expect(result.cadenceStepsPerMinute, closeTo(120, 1));
    },
  );

  test('preserves cadence in a noisy synthetic acceleration signal', () {
    final samples = [
      for (var i = 0; i < 300; i++)
        sampleAt(
          i,
          projectedAcceleration:
              0.06 +
              0.08 * (1 + math.sin(2 * math.pi * 2 * i * 0.02)) / 2 +
              0.025 * math.sin(2 * math.pi * 12 * i * 0.02),
        ),
    ];

    final result = analyzeGaitCadenceSamples(samples);

    expect(result.status, GaitCadenceStatus.computed);
    expect(result.stepCount, 12);
    expect(result.cadenceStepsPerMinute, closeTo(120, 1));
  });

  List<SensorSample> broadbandNoisePeriodicSamples({
    required int count,
    required int seed,
    required double noiseAmplitude,
  }) {
    final random = math.Random(seed);
    return [
      for (var i = 0; i < count; i++)
        sampleAt(
          i,
          projectedAcceleration:
              0.06 +
              0.08 * (1 + math.sin(2 * math.pi * 2 * i * 0.02)) / 2 +
              noiseAmplitude * (random.nextDouble() * 2 - 1),
        ),
    ];
  }

  test(
    'does not over-count steps under added broadband noise at the '
    'default threshold',
    () {
      // Per-sample uniform noise on [-0.05, 0.05] g against a 0.08 g
      // peak-to-trough base signal (a ~60% stress relative to the clean
      // signal used above), across independent seeds. This checks the
      // mechanism argument in `defaultCadencePeakThresholdStdMultiplier`'s
      // doc comment: acceptance also requires a strict local maximum and
      // strongest-first, period-spaced selection, so the low `k = 0.5`
      // threshold should not by itself inflate the step count.
      for (final seed in [1, 2, 3, 4, 5]) {
        final result = analyzeGaitCadenceSamples(
          broadbandNoisePeriodicSamples(
            count: 300,
            seed: seed,
            noiseAmplitude: 0.05,
          ),
        );

        expect(result.status, GaitCadenceStatus.computed, reason: 'seed=$seed');
        expect(
          result.stepCount,
          12,
          reason:
              'seed=$seed, period=${result.dominantPeriod}, '
              'periodicity=${result.periodicity}, '
              'minimumInterval=${result.minimumPeakInterval}',
        );
      }
    },
  );

  test(
    'keeps the same step count as the threshold multiplier is lowered '
    'toward zero',
    () {
      // Demonstrates that count is bounded by the period-derived minimum
      // spacing between accepted peaks, not by k: even with almost no
      // amplitude gate, the same noisy signal yields the same step count.
      final samples = broadbandNoisePeriodicSamples(
        count: 300,
        seed: 1,
        noiseAmplitude: 0.05,
      );

      final lenient = analyzeGaitCadenceSamples(
        samples,
        peakThresholdStdMultiplier: 0.01,
      );

      expect(lenient.status, GaitCadenceStatus.computed);
      expect(lenient.stepCount, 12);
    },
  );

  test('rejects secondary peaks in a nine-step synthetic signal', () {
    final result = analyzeGaitCadenceSamples(
      stepPulseSamples(
        stepCount: 9,
        stepPeriodSeconds: 0.62,
        secondaryPeakOffsetSeconds: 0.32,
      ),
    );

    expect(result.status, GaitCadenceStatus.computed);
    expect(result.stepCount, 9);
    expect(result.detectedStepSampleIndices, hasLength(9));
    expect(result.minimumPeakInterval, isNotNull);
    expect(
      result.minimumPeakInterval!.inMilliseconds,
      greaterThan(300),
    );
    expect(result.cadenceStepsPerMinute, closeTo(60 / 0.62, 3));
  });

  test('keeps a low-confidence result when peak evidence is available', () {
    final baseline = analyzeGaitCadenceSamples(
      stepPulseSamples(
        stepCount: 9,
        stepPeriodSeconds: 0.62,
        secondaryPeakOffsetSeconds: 0.32,
      ),
    );
    final result = analyzeGaitCadenceSamples(
      stepPulseSamples(
        stepCount: 9,
        stepPeriodSeconds: 0.62,
        secondaryPeakOffsetSeconds: 0.32,
      ),
      minimumPeriodicity: baseline.periodicity! + 0.05,
    );

    expect(result.status, GaitCadenceStatus.computed);
    expect(result.stepCount, 9);
    expect(result.confidence, GaitCadenceConfidence.low);
    expect(result.confidenceReason, lowCadencePeriodicityReason);
    expect(result.periodicity, lessThan(baseline.periodicity! + 0.05));
  });

  test(
    'promotes long internally consistent estimates to moderate confidence',
    () {
      final samples = stepPulseSamples(
        stepCount: 18,
        stepPeriodSeconds: 0.62,
        secondaryPeakOffsetSeconds: 0.32,
      );
      final baseline = analyzeGaitCadenceSamples(samples);
      final preferredPeriodicityGate = baseline.periodicity! + 0.05;
      final result = analyzeGaitCadenceSamples(
        samples,
        minimumPeriodicity: preferredPeriodicityGate,
      );

      expect(result.status, GaitCadenceStatus.computed);
      expect(result.stepCount, 18);
      expect(result.periodicity, lessThan(preferredPeriodicityGate));
      expect(result.confidence, GaitCadenceConfidence.moderate);
      expect(result.confidenceReason, isNull);
    },
  );

  test('retains steps in a faster synthetic walking signal', () {
    final result = analyzeGaitCadenceSamples(
      stepPulseSamples(
        stepCount: 14,
        stepPeriodSeconds: 0.34,
        secondaryPeakOffsetSeconds: 0.13,
        secondaryPeakScale: 0.55,
      ),
    );

    expect(result.status, GaitCadenceStatus.computed);
    expect(result.stepCount, 14);
    expect(result.detectedStepSampleIndices, hasLength(14));
    expect(result.minimumPeakInterval, isNotNull);
    expect(
      result.minimumPeakInterval!.inMilliseconds,
      lessThan(300),
    );
    expect(result.cadenceStepsPerMinute, closeTo(60 / 0.34, 5));
  });

  test('keeps a slow cadence at the upper period boundary', () {
    final result = analyzeGaitCadenceSamples(
      stepPulseSamples(
        stepCount: 7,
        stepPeriodSeconds: 1,
        secondaryPeakOffsetSeconds: 0.42,
        secondaryPeakScale: 0.15,
      ),
    );

    expect(result.status, GaitCadenceStatus.computed);
    expect(result.stepCount, 7);
    expect(result.cadenceStepsPerMinute, closeTo(60, 3));
  });

  test('uses angular velocity when acceleration follows stride rhythm', () {
    final result = analyzeGaitCadenceSamples(
      pocketSwingSamples(
        stepCount: 18,
        stepPeriodSeconds: 0.52,
      ),
    );

    expect(result.status, GaitCadenceStatus.computed);
    expect(result.stepCount, 18);
    expect(result.cadenceStepsPerMinute, closeTo(60 / 0.52, 5));
    expect(result.confidence, GaitCadenceConfidence.high);
  });

  test(
    "prefers a genuine step signal over the other channel's "
    'search-boundary autocorrelation artifact',
    () {
      // Acceleration is a pure 1.05 s sine: its autocorrelation never peaks
      // inside the searched lag range (0.29-1.0 s), so the strongest value
      // found is at the range's longest lag, still rising -- the exact
      // mechanism traced to a ~50% step undercount on real fast-paced
      // recordings. Gyro carries the genuine 0.4 s (150 spm) step signal as an
      //  interior local maximum. Confirmed via the Python mirror
      // (ml/utils/gait_cadence_port.py) that without this tie-break, both
      // channels reach "high" confidence with a periodicity gap under the
      // 0.05 margin, so the prior rule fell through to its final default
      // (prefer acceleration) and returned the sine's 16 crests instead of
      // the gyro channel's 38 real steps.
      final result = analyzeGaitCadenceSamples(
        boundaryArtifactSamples(
          sampleCount: 800,
          accelerationPeriodSeconds: 1.05,
          gyroStepCount: 38,
          gyroStepPeriodSeconds: 0.4,
        ),
      );

      expect(result.status, GaitCadenceStatus.computed);
      expect(
        result.stepCount,
        38,
        reason:
            'period=${result.dominantPeriod}, '
            'periodicity=${result.periodicity}, '
            'cadence=${result.cadenceStepsPerMinute}',
      );
      expect(result.cadenceStepsPerMinute, closeTo(150, 3));
    },
  );

  test('lowers confidence when peak and period cadence disagree', () {
    final result = analyzeGaitCadenceSamples(
      stepPulseSamples(
        stepCount: 10,
        stepPeriodSeconds: 0.37,
        secondaryPeakOffsetSeconds: 0.14,
        secondaryPeakScale: 0.5,
      ),
      maximumEstimateDisagreement: 0.01,
    );

    expect(result.status, GaitCadenceStatus.computed);
    expect(result.confidence, GaitCadenceConfidence.low);
    expect(result.confidenceReason, cadenceEstimatesDisagreeReason);
  });

  test('returns insufficient signal for a long flat acceleration signal', () {
    final result = analyzeGaitCadenceSamples([
      for (var i = 0; i < 300; i++) sampleAt(i),
    ]);

    expect(result.status, GaitCadenceStatus.insufficientSignal);
    expect(result.reason, tooFewCadencePeaksReason);
    expect(result.stepCount, lessThan(defaultCadenceMinimumDetectedSteps));
  });

  test(
    'returns insufficient signal for a transient without repeated peaks',
    () {
      final result = analyzeGaitCadenceSamples([
        for (var i = 0; i < 150; i++)
          sampleAt(i, projectedAcceleration: i < 20 ? 1 : 0),
      ]);

      expect(result.status, GaitCadenceStatus.insufficientSignal);
      expect(result.reason, tooFewCadencePeaksReason);
      expect(result.stepCount, lessThan(defaultCadenceMinimumDetectedSteps));
    },
  );

  test('does not throw on inconsistent timestamps', () {
    final result = analyzeGaitCadenceSamples([
      sampleAt(0, timestamp: start),
      sampleAt(1, timestamp: start.add(const Duration(milliseconds: 40))),
      sampleAt(2, timestamp: start.add(const Duration(milliseconds: 20))),
      sampleAt(3, timestamp: start.add(const Duration(milliseconds: 60))),
    ]);

    expect(result.status, GaitCadenceStatus.invalidTimestamps);
    expect(result.reason, invalidCadenceTimestampsReason);
    expect(result.stepCount, 0);
  });

  test('uses samples from an extracted gait signal segment', () {
    final rawSamples = periodicSamples(500);
    final log = SessionLog(
      startedAt: start,
      stoppedAt: start.add(const Duration(seconds: 10)),
      modelInfo: const {},
      rawSamples: rawSamples,
      predictions: [
        predictionAt(3000, 177),
        predictionAt(4280, 241),
        predictionAt(5560, 305),
        predictionAt(6840, 369),
        predictionAt(8120, 433),
      ],
    );
    final gaitSegments = extractGaitSegments(log);
    final signal = extractGaitSignalSegments(
      log,
      gaitSegments: gaitSegments,
    ).single;

    final result = analyzeGaitCadence(signal);

    expect(signal.startSampleIndex, 50);
    expect(signal.endSampleIndexExclusive, 434);
    expect(signal.samples, rawSamples.sublist(50, 434));
    expect(result.status, GaitCadenceStatus.computed);
    // periodicSamples' bump peaks fall at sample index 6.25 + 25k (from its
    // 2 Hz sin argument and 20 ms sample spacing); within this segment's
    // [50, 434) range that is k = 2..17 -- 16 peaks, not 15.
    expect(
      result.stepCount,
      16,
      reason:
          'period=${result.dominantPeriod}, '
          'periodicity=${result.periodicity}, '
          'minimumInterval=${result.minimumPeakInterval}',
    );
    expect(
      result.detectedStepSampleIndices.every(
        (index) =>
            index >= signal.startSampleIndex! &&
            index < signal.endSampleIndexExclusive!,
      ),
      isTrue,
    );
  });
}
