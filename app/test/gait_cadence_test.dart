import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:gait_sense/models/activity_prediction.dart';
import 'package:gait_sense/models/sensor_sample.dart';
import 'package:gait_sense/models/session_log.dart';
import 'package:gait_sense/utils/gait_cadence.dart';
import 'package:gait_sense/utils/gait_segments.dart';
import 'package:gait_sense/utils/gait_signal_segments.dart';

void main() {
  final start = DateTime.utc(2026, 1, 1, 12);

  SensorSample sampleAt(
    int index, {
    DateTime? timestamp,
    double projectedAcceleration = 0,
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
      rotationRateZ: 0,
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

  ActivityPrediction predictionAt(int millisecondsAfterStart, int endIndex) {
    return ActivityPrediction(
      label: 'wlk',
      probabilities: const [0.1, 0.1, 0.5, 0.1, 0.1, 0.1],
      timestamp: start.add(Duration(milliseconds: millisecondsAfterStart)),
      endSampleIndex: endIndex,
      inferenceLatencyMs: 10,
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
    expect(
      result.stepCount,
      15,
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
