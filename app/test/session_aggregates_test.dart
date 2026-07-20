import 'package:flutter_test/flutter_test.dart';
import 'package:gait_sense/models/gait_segment.dart';
import 'package:gait_sense/models/session_summary_record.dart';
import 'package:gait_sense/utils/gait_cadence.dart';
import 'package:gait_sense/utils/gait_walking_speed.dart';
import 'package:gait_sense/utils/session_aggregates.dart';
import 'package:gait_sense/utils/session_summary.dart';

void main() {
  // A single suitable gait segment whose analysis window spans [duration],
  // so `levelWalkingGaitDuration` reports exactly that value.
  List<GaitSegment> gaitSegmentsOf(Duration duration) => [
    GaitSegment(
      startIndex: 0,
      endIndexExclusive: 1,
      windows: 1,
      displayStartOffset: Duration.zero,
      displayEndOffset: duration,
      analysisStartOffset: Duration.zero,
      analysisEndOffset: duration,
      analysisStartSampleIndex: null,
      analysisEndSampleIndexExclusive: null,
      labelCounts: const {},
      quality: GaitSegmentQuality.suitable,
      qualityReason: null,
    ),
  ];

  SessionQualitySummary qualityWith({
    double? cadence,
    double? speed,
    Duration cadenceSignalDuration = Duration.zero,
    List<GaitSegment> gaitSegments = const [],
  }) {
    return SessionQualitySummary(
      predictionCount: 0,
      rawSmoothedChangeCount: 0,
      rawSmoothedChangeFraction: 0,
      effectiveLabelWindowCounts: const {},
      rawLabelWindowCounts: const {},
      stableLocomotionSegments: const [],
      stableLocomotionWindowCount: 0,
      stableLocomotionDuration: Duration.zero,
      hasEnoughStableLocomotion: false,
      gaitSegments: gaitSegments,
      gaitCadence: GaitCadenceSummary(
        signalSegmentCount: 0,
        sampledSignalSegmentCount: 0,
        computedResultCount: cadence != null ? 1 : 0,
        averageCadenceStepsPerMinute: cadence,
        signalDuration: cadenceSignalDuration,
        totalStepCount: 0,
        temporalParameters: null,
        status: cadence != null
            ? GaitCadenceStatus.computed
            : GaitCadenceStatus.empty,
        reason: null,
        confidence: GaitCadenceConfidence.low,
        confidenceReason: null,
      ),
      gaitWalkingSpeed: speed != null
          ? GaitWalkingSpeedSummary(
              signalSegmentCount: 0,
              computedResultCount: 1,
              averageWalkingSpeedMs: speed,
              averageStepLengthM: 0.7,
              status: GaitWalkingSpeedStatus.computed,
              reason: null,
            )
          : const GaitWalkingSpeedSummary.noHeight(),
    );
  }

  SessionSummaryRecord recordWith({
    List<ClassTotal> totals = const [],
    double? cadence,
    double? speed,
    Duration cadenceSignalDuration = Duration.zero,
    List<GaitSegment> gaitSegments = const [],
  }) {
    return SessionSummaryRecord(
      startedAt: DateTime.utc(2026),
      stoppedAt: DateTime.utc(2026, 1, 1, 0, 5),
      duration: const Duration(minutes: 5),
      deviceId: null,
      predictionCount: 0,
      modelInfo: const {},
      heightCmAtRecording: null,
      classTotals: totals,
      timeline: const [],
      quality: qualityWith(
        cadence: cadence,
        speed: speed,
        cadenceSignalDuration: cadenceSignalDuration,
        gaitSegments: gaitSegments,
      ),
    );
  }

  ClassTotal classTotal(String label, Duration time) =>
      ClassTotal(label: label, windows: 1, time: time, fraction: 1);

  group('sessionHistoryAggregates', () {
    test('totalWalkingTime sums only walking totals', () {
      final sessions = [
        recordWith(
          totals: [
            classTotal('wlk', const Duration(minutes: 2)),
            classTotal('sit', const Duration(minutes: 3)),
          ],
        ),
        recordWith(totals: [classTotal('wlk', const Duration(minutes: 3))]),
      ];

      expect(
        sessionHistoryAggregates(sessions).totalWalkingTime,
        const Duration(minutes: 5),
      );
    });

    test('averageCadence ignores sessions without a cadence estimate', () {
      final sessions = [
        recordWith(cadence: 100),
        recordWith(cadence: 120),
        recordWith(),
      ];

      expect(
        sessionHistoryAggregates(sessions).averageCadenceStepsPerMinute,
        110,
      );
    });

    test('averageWalkingSpeed ignores sessions without a speed estimate', () {
      final sessions = [
        recordWith(speed: 1),
        recordWith(speed: 1.4),
        recordWith(),
      ];

      expect(
        sessionHistoryAggregates(sessions).averageWalkingSpeedMs,
        closeTo(1.2, 1e-9),
      );
    });

    test('empty history yields null averages and zero walking', () {
      final aggregates = sessionHistoryAggregates(const []);
      expect(aggregates.totalWalkingTime, Duration.zero);
      expect(aggregates.averageCadenceStepsPerMinute, isNull);
      expect(aggregates.averageWalkingSpeedMs, isNull);
    });

    test(
      'averageCadence is weighted by the exact signal duration behind each '
      "session's cadence, so a session with 9x more usable signal "
      'outweighs a plain 100/200 mean',
      () {
        final sessions = [
          recordWith(
            cadence: 100,
            cadenceSignalDuration: const Duration(minutes: 1),
          ),
          recordWith(
            cadence: 200,
            cadenceSignalDuration: const Duration(minutes: 9),
          ),
        ];

        expect(
          sessionHistoryAggregates(sessions).averageCadenceStepsPerMinute,
          closeTo(190, 1e-9),
        );
      },
    );

    test(
      'averageWalkingSpeed is weighted by level-walking gait duration, so a '
      'session with 9x more usable signal outweighs a plain mean',
      () {
        final sessions = [
          recordWith(
            speed: 1,
            gaitSegments: gaitSegmentsOf(const Duration(minutes: 1)),
          ),
          recordWith(
            speed: 2,
            gaitSegments: gaitSegmentsOf(const Duration(minutes: 9)),
          ),
        ];

        expect(
          sessionHistoryAggregates(sessions).averageWalkingSpeedMs,
          closeTo(1.9, 1e-9),
        );
      },
    );

    test(
      'a session with a computed value but zero weight duration still '
      'contributes, at the same nominal weight as an unweighted mean',
      () {
        final sessions = [
          // No cadence signal duration recorded (e.g. an older record).
          recordWith(cadence: 100),
          recordWith(cadence: 200),
        ];

        expect(
          sessionHistoryAggregates(sessions).averageCadenceStepsPerMinute,
          150,
        );
      },
    );
  });
}
