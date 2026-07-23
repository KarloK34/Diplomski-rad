import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:gait_sense/models/activity_prediction.dart';
import 'package:gait_sense/models/gait_segment.dart';
import 'package:gait_sense/models/sensor_sample.dart';
import 'package:gait_sense/models/session_log.dart';
import 'package:gait_sense/utils/gait_cadence.dart';
import 'package:gait_sense/utils/gait_quality_format.dart';
import 'package:gait_sense/utils/gait_segments.dart';
import 'package:gait_sense/utils/gait_signal_segments.dart';
import 'package:gait_sense/utils/gait_temporal_parameters.dart';
import 'package:gait_sense/utils/gait_walking_speed.dart';
import 'package:gait_sense/utils/session_summary.dart';

void main() {
  // Fixed session start so every prediction timestamp below is deterministic.
  final start = DateTime.utc(2026, 1, 1, 12);

  ActivityPrediction predictionAt(
    String label,
    int secondsAfterStart, {
    String? rawLabel,
    int? endSampleIndex,
  }) {
    return ActivityPrediction(
      label: label,
      rawLabel: rawLabel,
      probabilities: const [0.1, 0.1, 0.5, 0.1, 0.1, 0.1],
      timestamp: start.add(Duration(seconds: secondsAfterStart)),
      endSampleIndex: endSampleIndex,
      inferenceLatencyMs: 10,
    );
  }

  SessionLog session({
    required List<ActivityPrediction> predictions,
    List<SensorSample> rawSamples = const [],
    DateTime? stoppedAt,
  }) {
    return SessionLog(
      startedAt: start,
      stoppedAt: stoppedAt,
      modelInfo: const {},
      rawSamples: rawSamples,
      predictions: predictions,
    );
  }

  SensorSample sampleAt(
    int index, {
    double projectedAcceleration = 0,
  }) {
    return SensorSample(
      timestamp: start.add(Duration(milliseconds: index * 20)),
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

  List<SensorSample> periodicSamples(
    int count, {
    double firstFrequencyHz = 2,
    double secondFrequencyHz = 1.5,
    double amplitude = 0.08,
    double baseline = 0.06,
  }) {
    return [
      for (var i = 0; i < count; i++)
        sampleAt(
          i,
          projectedAcceleration:
              baseline +
              amplitude *
                  (1 +
                      math.sin(
                        2 *
                            math.pi *
                            (i < 500 ? firstFrequencyHz : secondFrequencyHz) *
                            i *
                            0.02,
                      )) /
                  2,
        ),
    ];
  }

  Matcher closeToDuration(Duration expected, int toleranceMicroseconds) {
    return predicate<Duration>(
      (actual) =>
          (actual.inMicroseconds - expected.inMicroseconds).abs() <=
          toleranceMicroseconds,
      'within ${toleranceMicroseconds}us of $expected',
    );
  }

  group('sessionDuration', () {
    test('uses stoppedAt minus startedAt when stopped', () {
      final log = session(
        predictions: [predictionAt('wlk', 2)],
        stoppedAt: start.add(const Duration(seconds: 60)),
      );
      expect(sessionDuration(log), const Duration(seconds: 60));
    });

    test('falls back to the last prediction timestamp when not stopped', () {
      final log = session(
        predictions: [predictionAt('wlk', 2), predictionAt('wlk', 12)],
      );
      expect(sessionDuration(log), const Duration(seconds: 12));
    });

    test('is zero for an empty, never-stopped session', () {
      expect(sessionDuration(session(predictions: const [])), Duration.zero);
    });
  });

  group('computeClassTotals', () {
    test('returns an empty list for no predictions', () {
      expect(computeClassTotals(session(predictions: const [])), isEmpty);
    });

    test('counts, scales time by fraction, and sorts by windows desc', () {
      final log = session(
        predictions: [
          predictionAt('jog', 2),
          predictionAt('jog', 4),
          predictionAt('wlk', 6),
          predictionAt('wlk', 8),
          predictionAt('wlk', 10),
          predictionAt('ups', 12),
        ],
        stoppedAt: start.add(const Duration(seconds: 60)),
      );

      final totals = computeClassTotals(log);

      // 3 wlk, 2 jog, 1 ups over 6 windows, sorted by window count descending.
      expect(totals.map((t) => t.label).toList(), ['wlk', 'jog', 'ups']);
      expect(totals.map((t) => t.windows).toList(), [3, 2, 1]);
      expect(totals[0].fraction, closeTo(0.5, 1e-9));
      expect(totals[1].fraction, closeTo(1 / 3, 1e-9));
      expect(totals[2].fraction, closeTo(1 / 6, 1e-9));
      // Fraction * 60 s: 30 s, 20 s, 10 s.
      expect(totals[0].time, const Duration(seconds: 30));
      expect(totals[1].time, const Duration(seconds: 20));
      expect(totals[2].time, const Duration(seconds: 10));
    });

    test('merges std and sit windows into one resting total', () {
      final log = session(
        predictions: [
          predictionAt('sit', 2),
          predictionAt('std', 4),
          predictionAt('wlk', 6),
        ],
        stoppedAt: start.add(const Duration(seconds: 30)),
      );

      final totals = computeClassTotals(log);

      expect(totals.map((t) => t.label).toList(), ['rest', 'wlk']);
      expect(totals.map((t) => t.windows).toList(), [2, 1]);
    });
  });

  group('computeTimeline', () {
    test('returns an empty list for no predictions', () {
      expect(computeTimeline(session(predictions: const [])), isEmpty);
    });

    test('collapses runs, anchors first at 0 and last at duration', () {
      final log = session(
        predictions: [
          predictionAt('jog', 2),
          predictionAt('jog', 4),
          predictionAt('wlk', 6),
          predictionAt('wlk', 8),
          predictionAt('wlk', 10),
          predictionAt('ups', 12),
        ],
        stoppedAt: start.add(const Duration(seconds: 60)),
      );

      final timeline = computeTimeline(log);

      expect(timeline.length, 3);

      expect(timeline[0].label, 'jog');
      expect(timeline[0].start, Duration.zero);
      // Interior boundary uses the timestamp where the new label first appears.
      expect(timeline[0].end, const Duration(seconds: 6));
      expect(timeline[0].windows, 2);

      expect(timeline[1].label, 'wlk');
      expect(timeline[1].start, const Duration(seconds: 6));
      expect(timeline[1].end, const Duration(seconds: 12));
      expect(timeline[1].windows, 3);

      expect(timeline[2].label, 'ups');
      expect(timeline[2].start, const Duration(seconds: 12));
      // Last segment stays anchored at the full session duration for display.
      expect(timeline[2].end, const Duration(seconds: 60));
      expect(timeline[2].windows, 1);
    });

    test('handles a single uniform run as one full-span segment', () {
      final log = session(
        predictions: [predictionAt('wlk', 2), predictionAt('wlk', 4)],
        stoppedAt: start.add(const Duration(seconds: 30)),
      );
      final timeline = computeTimeline(log);
      expect(timeline.length, 1);
      expect(timeline.single.label, 'wlk');
      expect(timeline.single.start, Duration.zero);
      expect(timeline.single.end, const Duration(seconds: 30));
      expect(timeline.single.windows, 2);
    });

    test('merges an alternating std/sit run into one resting segment', () {
      final log = session(
        predictions: [
          predictionAt('std', 2),
          predictionAt('sit', 4),
          predictionAt('std', 6),
          predictionAt('wlk', 8),
        ],
        stoppedAt: start.add(const Duration(seconds: 20)),
      );

      final timeline = computeTimeline(log);

      expect(timeline.length, 2);
      expect(timeline[0].label, 'rest');
      expect(timeline[0].start, Duration.zero);
      expect(timeline[0].end, const Duration(seconds: 8));
      expect(timeline[0].windows, 3);
      expect(timeline[1].label, 'wlk');
      expect(timeline[1].start, const Duration(seconds: 8));
      expect(timeline[1].end, const Duration(seconds: 20));
      expect(timeline[1].windows, 1);
    });
  });

  group('computeSessionQualitySummary', () {
    test('returns empty quality values for no predictions', () {
      final summary = computeSessionQualitySummary(
        session(predictions: const []),
      );

      expect(summary.predictionCount, 0);
      expect(summary.rawSmoothedChangeCount, 0);
      expect(summary.rawSmoothedChangeFraction, 0);
      expect(summary.effectiveLabelWindowCounts, isEmpty);
      expect(summary.rawLabelWindowCounts, isEmpty);
      expect(summary.stableLocomotionSegments, isEmpty);
      expect(summary.stableLocomotionWindowCount, 0);
      expect(summary.stableLocomotionDuration, Duration.zero);
      expect(summary.hasEnoughStableLocomotion, isFalse);
      expect(summary.gaitSegments, isEmpty);
      expect(summary.suitableGaitSegments, isEmpty);
      expect(summary.hasEnoughLevelWalkingGaitSegments, isFalse);
      expect(summary.gaitCadence.signalSegmentCount, 0);
      expect(summary.gaitCadence.sampledSignalSegmentCount, 0);
      expect(summary.gaitCadence.computedResultCount, 0);
      expect(summary.gaitCadence.averageCadenceStepsPerMinute, isNull);
      expect(summary.gaitCadence.totalStepCount, 0);
      expect(summary.gaitCadence.temporalParameters, isNull);
      expect(summary.gaitCadence.status, GaitCadenceStatus.empty);
      expect(summary.gaitCadence.reason, noSuitableCadenceSignalReason);
      expect(summary.gaitCadence.confidence, GaitCadenceConfidence.low);
    });

    test('marks one short walking jump as an unsuitable gait segment', () {
      final summary = computeSessionQualitySummary(
        session(
          predictions: [
            predictionAt('sit', 1),
            predictionAt('wlk', 2),
            predictionAt('sit', 3),
          ],
        ),
      );

      expect(summary.predictionCount, 3);
      expect(summary.effectiveLabelWindowCounts, {'sit': 2, 'wlk': 1});
      expect(summary.stableLocomotionSegments, isEmpty);
      expect(summary.stableLocomotionWindowCount, 0);
      expect(summary.hasEnoughStableLocomotion, isFalse);
      expect(summary.gaitSegments, hasLength(1));
      expect(
        summary.gaitSegments.single.quality,
        GaitSegmentQuality.tooFewWindows,
      );
      expect(
        summary.gaitSegments.single.qualityReason,
        tooFewLevelWalkingWindowsReason,
      );
      expect(summary.suitableGaitSegments, isEmpty);
      expect(summary.hasEnoughLevelWalkingGaitSegments, isFalse);
    });

    test('accepts five consecutive walking windows as level-walking gait', () {
      final summary = computeSessionQualitySummary(
        session(
          predictions: [
            for (var i = 0; i < 5; i++) predictionAt('wlk', i + 1),
          ],
          stoppedAt: start.add(const Duration(seconds: 5)),
        ),
      );

      expect(summary.predictionCount, 5);
      expect(summary.stableLocomotionSegments, hasLength(1));
      expect(summary.stableLocomotionSegments.single.startIndex, 0);
      expect(summary.stableLocomotionSegments.single.endIndexExclusive, 5);
      expect(summary.stableLocomotionWindowCount, 5);
      expect(summary.stableLocomotionDuration, const Duration(seconds: 5));
      expect(summary.hasEnoughStableLocomotion, isTrue);

      expect(summary.gaitSegments, hasLength(1));
      final segment = summary.gaitSegments.single;
      expect(segment.isSuitable, isTrue);
      expect(segment.labelCounts, {'wlk': 5});
      expect(segment.displayStartOffset, Duration.zero);
      expect(segment.displayEndOffset, const Duration(seconds: 5));
      expect(segment.analysisStartOffset, const Duration(seconds: 1));
      expect(segment.analysisEndOffset, const Duration(seconds: 5));
      expect(summary.suitableGaitSegments, hasLength(1));
      expect(summary.levelWalkingGaitWindowCount, 5);
      expect(summary.levelWalkingGaitDuration, const Duration(seconds: 4));
      expect(summary.hasEnoughLevelWalkingGaitSegments, isTrue);
    });

    test('returns unavailable cadence when raw samples are missing', () {
      final summary = computeSessionQualitySummary(
        session(
          predictions: [
            for (var i = 0; i < 5; i++) predictionAt('wlk', i + 1),
          ],
          stoppedAt: start.add(const Duration(seconds: 5)),
        ),
      );

      expect(summary.suitableGaitSegments, hasLength(1));
      expect(summary.gaitCadence.signalSegmentCount, 1);
      expect(summary.gaitCadence.sampledSignalSegmentCount, 0);
      expect(summary.gaitCadence.computedResultCount, 0);
      expect(summary.gaitCadence.averageCadenceStepsPerMinute, isNull);
      expect(summary.gaitCadence.totalStepCount, 0);
      expect(summary.gaitCadence.temporalParameters, isNull);
      expect(summary.gaitCadence.status, GaitCadenceStatus.empty);
      expect(summary.gaitCadence.reason, missingRawSamplesReason);
      expect(summary.gaitCadence.confidence, GaitCadenceConfidence.low);
    });

    test('does not count time before the first walking prediction', () {
      final summary = computeSessionQualitySummary(
        session(
          predictions: [
            for (var i = 0; i < 5; i++) predictionAt('wlk', i + 3),
          ],
          stoppedAt: start.add(const Duration(seconds: 7)),
        ),
      );

      final segment = summary.suitableGaitSegments.single;
      expect(segment.displayStartOffset, Duration.zero);
      expect(segment.analysisStartOffset, const Duration(seconds: 3));
      expect(segment.analysisEndOffset, const Duration(seconds: 7));
      expect(summary.levelWalkingGaitDuration, const Duration(seconds: 4));
    });

    test('sets analysis sample bounds from the full source windows', () {
      final summary = computeSessionQualitySummary(
        session(
          predictions: [
            for (var i = 0; i < 5; i++)
              predictionAt('wlk', i + 3, endSampleIndex: 127 + i * 64),
          ],
          stoppedAt: start.add(const Duration(seconds: 8)),
        ),
      );

      final segment = summary.suitableGaitSegments.single;
      expect(segment.analysisStartOffset, const Duration(seconds: 3));
      expect(segment.analysisStartSampleIndex, 0);
      expect(segment.analysisEndSampleIndexExclusive, 384);
    });

    test('uses prediction timestamps for stable segment duration', () {
      final summary = computeSessionQualitySummary(
        session(
          predictions: [
            predictionAt('wlk', 2),
            predictionAt('wlk', 4),
            predictionAt('wlk', 6),
            predictionAt('wlk', 8),
            predictionAt('wlk', 10),
            predictionAt('sit', 12),
          ],
        ),
      );

      expect(summary.stableLocomotionSegments, hasLength(1));
      expect(summary.stableLocomotionDuration, const Duration(seconds: 12));
      expect(summary.levelWalkingGaitDuration, const Duration(seconds: 10));
    });

    test('counts smoothing changes when rawLabel differs from label', () {
      final summary = computeSessionQualitySummary(
        session(
          predictions: [
            predictionAt('wlk', 1, rawLabel: 'sit'),
            predictionAt('wlk', 2),
            predictionAt('std', 3, rawLabel: 'wlk'),
          ],
        ),
      );

      expect(summary.rawSmoothedChangeCount, 2);
      expect(summary.rawSmoothedChangeFraction, closeTo(2 / 3, 1e-9));
      expect(summary.effectiveLabelWindowCounts, {'wlk': 2, 'std': 1});
      expect(summary.rawLabelWindowCounts, {'sit': 1, 'wlk': 2});
    });

    test('keeps mixed walking and stairs as locomotion only', () {
      final summary = computeSessionQualitySummary(
        session(
          predictions: [
            predictionAt('wlk', 1),
            predictionAt('ups', 2),
            predictionAt('dws', 3),
            predictionAt('ups', 4),
            predictionAt('wlk', 5),
          ],
          stoppedAt: start.add(const Duration(seconds: 5)),
        ),
      );

      expect(summary.stableLocomotionSegments, hasLength(1));
      expect(
        summary.stableLocomotionSegments.single.effectiveLabelWindowCounts,
        {
          'wlk': 2,
          'ups': 2,
          'dws': 1,
        },
      );
      expect(summary.stableLocomotionWindowCount, 5);
      expect(summary.hasEnoughStableLocomotion, isTrue);
      expect(summary.suitableGaitSegments, isEmpty);
      expect(summary.hasEnoughLevelWalkingGaitSegments, isFalse);
    });

    test('does not accept stairs-only locomotion as a gait segment', () {
      final summary = computeSessionQualitySummary(
        session(
          predictions: [
            predictionAt('ups', 1),
            predictionAt('dws', 2),
            predictionAt('ups', 3),
            predictionAt('dws', 4),
            predictionAt('ups', 5),
          ],
          stoppedAt: start.add(const Duration(seconds: 5)),
        ),
      );

      expect(summary.stableLocomotionSegments, hasLength(1));
      expect(summary.stableLocomotionWindowCount, 5);
      expect(summary.hasEnoughStableLocomotion, isTrue);
      expect(summary.gaitSegments, isEmpty);
      expect(summary.suitableGaitSegments, isEmpty);
      expect(summary.hasEnoughLevelWalkingGaitSegments, isFalse);
    });

    test('returns computed cadence for a synthetic gait signal', () {
      final rawSamples = periodicSamples(500);
      final summary = computeSessionQualitySummary(
        session(
          rawSamples: rawSamples,
          predictions: [
            predictionAt('wlk', 3, endSampleIndex: 177),
            predictionAt('wlk', 4, endSampleIndex: 241),
            predictionAt('wlk', 5, endSampleIndex: 305),
            predictionAt('wlk', 6, endSampleIndex: 369),
            predictionAt('wlk', 8, endSampleIndex: 433),
          ],
          stoppedAt: start.add(const Duration(seconds: 10)),
        ),
      );

      expect(summary.suitableGaitSegments, hasLength(1));
      expect(summary.gaitCadence.signalSegmentCount, 1);
      expect(summary.gaitCadence.sampledSignalSegmentCount, 1);
      expect(summary.gaitCadence.computedResultCount, 1);
      expect(summary.gaitCadence.status, GaitCadenceStatus.computed);
      expect(summary.gaitCadence.reason, isNull);
      expect(summary.gaitCadence.confidence, GaitCadenceConfidence.high);
      // periodicSamples' bump peaks fall at sample index 6.25 + 25k (from
      // its 2 Hz sin argument and 20 ms sample spacing); within this
      // signal's analysis window [50, 434) that is k = 2..17 -- 16 peaks,
      // not 15.
      expect(summary.gaitCadence.totalStepCount, 16);
      expect(summary.gaitCadence.temporalParameters, isNotNull);
      expect(summary.gaitCadence.temporalParameters!.stepIntervalCount, 15);
      expect(
        summary.gaitCadence.temporalParameters!.meanStepTime,
        closeToDuration(const Duration(milliseconds: 500), 25000),
      );
      expect(
        summary.gaitCadence.averageCadenceStepsPerMinute,
        closeTo(120, 0.5),
      );
    });

    test('weights cadence by segment duration across multiple segments', () {
      final rawSamples = periodicSamples(1100);
      final predictions = [
        predictionAt('wlk', 3, endSampleIndex: 177),
        predictionAt('wlk', 4, endSampleIndex: 241),
        predictionAt('wlk', 5, endSampleIndex: 305),
        predictionAt('wlk', 6, endSampleIndex: 369),
        predictionAt('wlk', 8, endSampleIndex: 433),
        // Three consecutive 'sit' windows: deliberately wider than
        // defaultGaitSegmentGapToleranceWindows (2), so the two 'wlk' runs
        // stay separate segments (a genuine pause, not a brief
        // misclassification blip) and this test keeps exercising
        // duration-weighted aggregation across two distinct segments.
        predictionAt('sit', 9, endSampleIndex: 497),
        predictionAt('sit', 10, endSampleIndex: 561),
        predictionAt('sit', 11, endSampleIndex: 595),
        predictionAt('wlk', 12, endSampleIndex: 627),
        predictionAt('wlk', 13, endSampleIndex: 691),
        predictionAt('wlk', 14, endSampleIndex: 755),
        predictionAt('wlk', 15, endSampleIndex: 819),
        predictionAt('wlk', 16, endSampleIndex: 883),
        predictionAt('wlk', 17, endSampleIndex: 947),
        predictionAt('wlk', 20, endSampleIndex: 1011),
      ];
      final log = session(
        rawSamples: rawSamples,
        predictions: predictions,
        stoppedAt: start.add(const Duration(seconds: 22)),
      );
      final summary = computeSessionQualitySummary(log);
      final signals = extractGaitSignalSegments(
        log,
        gaitSegments: summary.gaitSegments,
      );
      final results = [
        for (final signal in signals) analyzeGaitCadence(signal),
      ];
      final totalDurationUs = results.fold<int>(
        0,
        (sum, result) => sum + result.duration.inMicroseconds,
      );
      final totalSteps = results.fold<int>(
        0,
        (sum, result) => sum + result.stepCount,
      );
      final totalIntervals = results.fold<int>(
        0,
        (sum, result) =>
            sum + computeGaitTemporalParameters(result)!.stepIntervalCount,
      );
      final totalStrideIntervals = results.fold<int>(
        0,
        (sum, result) =>
            sum + computeGaitTemporalParameters(result)!.strideIntervalCount,
      );
      final expectedCadence =
          results.fold<double>(
            0,
            (sum, result) =>
                sum +
                result.cadenceStepsPerMinute * result.duration.inMicroseconds,
          ) /
          totalDurationUs;
      final simpleAverage =
          results
              .map((result) => result.cadenceStepsPerMinute)
              .reduce((a, b) => a + b) /
          results.length;

      expect(summary.suitableGaitSegments, hasLength(2));
      expect(results.every((result) => result.isComputed), isTrue);
      expect(results.first.duration, isNot(results.last.duration));
      expect(summary.gaitCadence.signalSegmentCount, 2);
      expect(summary.gaitCadence.sampledSignalSegmentCount, 2);
      expect(summary.gaitCadence.computedResultCount, 2);
      expect(summary.gaitCadence.totalStepCount, totalSteps);
      expect(summary.gaitCadence.temporalParameters, isNotNull);
      expect(
        summary.gaitCadence.temporalParameters!.stepIntervalCount,
        totalIntervals,
      );
      expect(
        summary.gaitCadence.temporalParameters!.strideIntervalCount,
        totalStrideIntervals,
      );
      expect(
        summary.gaitCadence.averageCadenceStepsPerMinute,
        closeTo(expectedCadence, 1e-9),
      );
      expect(
        summary.gaitCadence.averageCadenceStepsPerMinute,
        isNot(closeTo(simpleAverage, 0.01)),
      );
      expect(
        summary.gaitCadence.signalDuration,
        Duration(microseconds: totalDurationUs),
      );
    });

    test(
      'cadence counts steps from a stair run absent from gaitSegments '
      '(level-walking only)',
      () {
        final rawSamples = periodicSamples(500);
        final summary = computeSessionQualitySummary(
          session(
            rawSamples: rawSamples,
            predictions: [
              predictionAt('ups', 3, endSampleIndex: 177),
              predictionAt('ups', 4, endSampleIndex: 241),
              predictionAt('ups', 5, endSampleIndex: 305),
              predictionAt('ups', 6, endSampleIndex: 369),
              predictionAt('ups', 8, endSampleIndex: 433),
            ],
            stoppedAt: start.add(const Duration(seconds: 10)),
          ),
          userHeightCm: 175,
        );

        // Never a level-walking candidate: gaitSegments/suitableGaitSegments
        // and walking-speed stay wlk-only regardless of cadence's broader
        // label set.
        expect(summary.gaitSegments, isEmpty);
        expect(summary.suitableGaitSegments, isEmpty);
        expect(summary.gaitWalkingSpeed.hasComputedSpeed, isFalse);

        // But cadence/step counting does pick up the stair run — same
        // signal and endSampleIndex range as the all-'wlk' case above, so the
        // same result.
        expect(summary.gaitCadence.hasComputedCadence, isTrue);
        expect(summary.gaitCadence.totalStepCount, 16);
      },
    );

    test(
      'cadence counts steps from a jogging run absent from gaitSegments '
      '(level-walking only)',
      () {
        final rawSamples = periodicSamples(500);
        final summary = computeSessionQualitySummary(
          session(
            rawSamples: rawSamples,
            predictions: [
              predictionAt('jog', 3, endSampleIndex: 177),
              predictionAt('jog', 4, endSampleIndex: 241),
              predictionAt('jog', 5, endSampleIndex: 305),
              predictionAt('jog', 6, endSampleIndex: 369),
              predictionAt('jog', 8, endSampleIndex: 433),
            ],
            stoppedAt: start.add(const Duration(seconds: 10)),
          ),
          userHeightCm: 175,
        );

        // Jogging is never a level-walking candidate either: the
        // inverted-pendulum model's single-support assumption cannot
        // represent a run's flight phase at all.
        expect(summary.gaitSegments, isEmpty);
        expect(summary.suitableGaitSegments, isEmpty);
        expect(summary.gaitWalkingSpeed.hasComputedSpeed, isFalse);

        expect(summary.gaitCadence.hasComputedCadence, isTrue);
        expect(summary.gaitCadence.totalStepCount, 16);
      },
    );

    test(
      'cadence treats a wlk/ups mix as one continuous run, unlike '
      'gaitSegments',
      () {
        final rawSamples = periodicSamples(500);
        final summary = computeSessionQualitySummary(
          session(
            rawSamples: rawSamples,
            predictions: [
              // Three consecutive 'ups' windows: deliberately wider than
              // defaultGaitSegmentGapToleranceWindows (2), so this isolates
              // the label-set-breadth distinction below from gap-tolerant
              // merging (a <=2-window gap would now bridge for both label
              // sets — see the gap-tolerance test group instead).
              predictionAt('wlk', 3, endSampleIndex: 177),
              predictionAt('ups', 4, endSampleIndex: 241),
              predictionAt('ups', 5, endSampleIndex: 305),
              predictionAt('ups', 6, endSampleIndex: 369),
              predictionAt('wlk', 8, endSampleIndex: 433),
            ],
            stoppedAt: start.add(const Duration(seconds: 10)),
          ),
          userHeightCm: 175,
        );

        // gaitSegments (level-walking only) fragments at every non-'wlk'
        // window into two too-short runs...
        expect(summary.gaitSegments, hasLength(2));
        expect(
          summary.gaitSegments.every(
            (s) => s.quality == GaitSegmentQuality.tooFewWindows,
          ),
          isTrue,
        );
        expect(summary.suitableGaitSegments, isEmpty);

        // ...but cadence sees one continuous 5-window locomotion run, so a
        // brief HAR misclassification mid-walk does not fragment or drop the
        // steps around it.
        expect(summary.gaitCadence.signalSegmentCount, 1);
        expect(summary.gaitCadence.hasComputedCadence, isTrue);
        expect(summary.gaitCadence.totalStepCount, 16);
      },
    );

    test(
      'gap-tolerant merge treats a brief non-locomotion blip as one '
      'suitable level-walking segment',
      () {
        final rawSamples = periodicSamples(500);
        final summary = computeSessionQualitySummary(
          session(
            rawSamples: rawSamples,
            predictions: [
              predictionAt('wlk', 1, endSampleIndex: 127),
              predictionAt('wlk', 2, endSampleIndex: 175),
              predictionAt('wlk', 3, endSampleIndex: 223),
              // Two consecutive 'std' windows: within
              // defaultGaitSegmentGapToleranceWindows (2), so this brief
              // mid-walk blip is bridged rather than splitting the run.
              predictionAt('std', 4),
              predictionAt('std', 5),
              predictionAt('wlk', 6, endSampleIndex: 367),
              predictionAt('wlk', 7, endSampleIndex: 415),
              predictionAt('wlk', 8, endSampleIndex: 463),
            ],
            stoppedAt: start.add(const Duration(seconds: 9)),
          ),
          userHeightCm: 175,
        );

        expect(summary.gaitSegments, hasLength(1));
        final segment = summary.gaitSegments.single;
        expect(segment.quality, GaitSegmentQuality.suitable);
        expect(segment.windows, 8);
        expect(segment.labelCounts, {'wlk': 6, 'std': 2});
        expect(summary.suitableGaitSegments, hasLength(1));
        expect(summary.hasEnoughLevelWalkingGaitSegments, isTrue);
        expect(summary.gaitCadence.signalSegmentCount, 1);
        expect(summary.gaitCadence.hasComputedCadence, isTrue);
      },
    );

    test(
      'a gap wider than the tolerance still splits the segment',
      () {
        final summary = computeSessionQualitySummary(
          session(
            predictions: [
              predictionAt('wlk', 1),
              predictionAt('wlk', 2),
              predictionAt('wlk', 3),
              predictionAt('std', 4),
              predictionAt('std', 5),
              predictionAt('std', 6),
              predictionAt('wlk', 7),
              predictionAt('wlk', 8),
              predictionAt('wlk', 9),
            ],
            stoppedAt: start.add(const Duration(seconds: 9)),
          ),
        );

        expect(summary.gaitSegments, hasLength(2));
        expect(
          summary.gaitSegments.every((s) => s.windows == 3),
          isTrue,
        );
        expect(summary.suitableGaitSegments, isEmpty);
      },
    );

    test('gaitWalkingSpeed is noHeight when userHeightCm is not provided', () {
      final summary = computeSessionQualitySummary(
        session(predictions: const []),
      );
      expect(
        summary.gaitWalkingSpeed.status,
        GaitWalkingSpeedStatus.unavailable,
      );
      expect(summary.gaitWalkingSpeed.reason, missingUserHeightReason);
      expect(summary.gaitWalkingSpeed.averageWalkingSpeedMs, isNull);
      expect(summary.gaitWalkingSpeed.averageStepLengthM, isNull);
    });

    test('gaitWalkingSpeed is unavailable when no suitable signal exists', () {
      final summary = computeSessionQualitySummary(
        session(predictions: const []),
        userHeightCm: 175,
      );
      expect(
        summary.gaitWalkingSpeed.status,
        GaitWalkingSpeedStatus.unavailable,
      );
      expect(summary.gaitWalkingSpeed.averageWalkingSpeedMs, isNull);
    });

    test('gaitWalkingSpeed computes when height and signal are provided', () {
      final rawSamples = periodicSamples(500, amplitude: 0.20);
      final summary = computeSessionQualitySummary(
        session(
          rawSamples: rawSamples,
          predictions: [
            predictionAt('wlk', 3, endSampleIndex: 177),
            predictionAt('wlk', 4, endSampleIndex: 241),
            predictionAt('wlk', 5, endSampleIndex: 305),
            predictionAt('wlk', 6, endSampleIndex: 369),
            predictionAt('wlk', 8, endSampleIndex: 433),
          ],
          stoppedAt: start.add(const Duration(seconds: 10)),
        ),
        userHeightCm: 175,
      );

      expect(summary.gaitCadence.hasComputedCadence, isTrue);
      expect(summary.gaitWalkingSpeed.hasComputedSpeed, isTrue);

      expect(summary.gaitWalkingSpeed.signalSegmentCount, 1);
      expect(summary.gaitWalkingSpeed.computedResultCount, 1);
      expect(summary.gaitWalkingSpeed.averageWalkingSpeedMs, isNotNull);
      expect(summary.gaitWalkingSpeed.averageStepLengthM, isNotNull);
      expect(summary.gaitWalkingSpeed.averageWalkingSpeedMs, greaterThan(0));
      expect(summary.gaitWalkingSpeed.averageStepLengthM, greaterThan(0));
    });
  });

  group('windowCountLabelHr', () {
    test('uses singular "prozor" only for counts ending in 1 except 11', () {
      expect(windowCountLabelHr(1), '1 prozor');
      expect(windowCountLabelHr(21), '21 prozor');
      expect(windowCountLabelHr(101), '101 prozor');
    });

    test('uses "prozora" for everything else', () {
      expect(windowCountLabelHr(0), '0 prozora');
      expect(windowCountLabelHr(2), '2 prozora');
      expect(windowCountLabelHr(11), '11 prozora');
      expect(windowCountLabelHr(25), '25 prozora');
      expect(windowCountLabelHr(111), '111 prozora');
    });
  });
}
