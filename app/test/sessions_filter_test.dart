import 'package:flutter_test/flutter_test.dart';
import 'package:gait_sense/models/session_summary_record.dart';
import 'package:gait_sense/utils/gait_cadence.dart';
import 'package:gait_sense/utils/session_summary.dart';
import 'package:gait_sense/utils/sessions_filter.dart';

void main() {
  const quality = SessionQualitySummary(
    predictionCount: 0,
    rawSmoothedChangeCount: 0,
    rawSmoothedChangeFraction: 0,
    effectiveLabelWindowCounts: {},
    rawLabelWindowCounts: {},
    stableLocomotionSegments: [],
    stableLocomotionWindowCount: 0,
    stableLocomotionDuration: Duration.zero,
    hasEnoughStableLocomotion: false,
    gaitSegments: [],
    gaitCadence: GaitCadenceSummary(
      signalSegmentCount: 0,
      sampledSignalSegmentCount: 0,
      computedResultCount: 0,
      averageCadenceStepsPerMinute: null,
      signalDuration: Duration.zero,
      totalStepCount: 0,
      temporalParameters: null,
      status: GaitCadenceStatus.empty,
      reason: null,
      confidence: GaitCadenceConfidence.low,
      confidenceReason: null,
    ),
    gaitWalkingSpeed: GaitWalkingSpeedSummary.noHeight(),
  );

  SessionSummaryRecord recordAt(
    DateTime startedAt, {
    String dominantLabel = 'wlk',
  }) {
    return SessionSummaryRecord(
      startedAt: startedAt,
      stoppedAt: startedAt.add(const Duration(minutes: 5)),
      duration: const Duration(minutes: 5),
      deviceId: null,
      predictionCount: 1,
      modelInfo: const {},
      heightCmAtRecording: null,
      classTotals: [
        ClassTotal(
          label: dominantLabel,
          windows: 1,
          time: const Duration(minutes: 5),
          fraction: 1,
        ),
      ],
      timeline: const [],
      quality: quality,
    );
  }

  group('filterSessions', () {
    final now = DateTime(2026, 7, 16, 12); // Thursday.

    test('defaults return every session unchanged', () {
      final sessions = [recordAt(DateTime(2020)), recordAt(DateTime(2026))];

      expect(filterSessions(sessions), sessions);
    });

    test('thisWeek keeps sessions from Monday 00:00 onward', () {
      final sessions = [
        recordAt(DateTime(2026, 7, 16, 8)), // Same Thursday.
        recordAt(DateTime(2026, 7, 13)), // Monday this week.
        recordAt(DateTime(2026, 7, 12, 23, 59)), // Sunday, previous week.
      ];

      final result = filterSessions(
        sessions,
        period: SessionsPeriodFilter.thisWeek,
        now: now,
      );

      expect(result, [sessions[0], sessions[1]]);
    });

    test('thisMonth keeps sessions from the 1st of the month onward', () {
      final sessions = [
        recordAt(DateTime(2026, 7)),
        recordAt(DateTime(2026, 6, 30, 23, 59)),
      ];

      final result = filterSessions(
        sessions,
        period: SessionsPeriodFilter.thisMonth,
        now: now,
      );

      expect(result, [sessions[0]]);
    });

    test('thisYear keeps sessions from Jan 1st onward', () {
      final sessions = [
        recordAt(DateTime(2026)),
        recordAt(DateTime(2025, 12, 31)),
      ];

      final result = filterSessions(
        sessions,
        period: SessionsPeriodFilter.thisYear,
        now: now,
      );

      expect(result, [sessions[0]]);
    });

    test('walking keeps only sessions whose dominant activity is wlk', () {
      final sessions = [
        recordAt(DateTime(2026)),
        recordAt(DateTime(2026, 1, 2), dominantLabel: 'sit'),
      ];

      final result = filterSessions(
        sessions,
        activity: SessionsActivityFilter.walking,
      );

      expect(result, [sessions[0]]);
    });

    test('walking excludes a session with no class totals', () {
      final noTotals = SessionSummaryRecord(
        startedAt: DateTime(2026),
        stoppedAt: null,
        duration: Duration.zero,
        deviceId: null,
        predictionCount: 0,
        modelInfo: const {},
        heightCmAtRecording: null,
        classTotals: const [],
        timeline: const [],
        quality: quality,
      );

      expect(
        filterSessions(
          [noTotals],
          activity: SessionsActivityFilter.walking,
        ),
        isEmpty,
      );
    });

    test('resting matches both std- and sit-dominant sessions', () {
      final sessions = [
        recordAt(DateTime(2026), dominantLabel: 'std'),
        recordAt(DateTime(2026, 1, 2), dominantLabel: 'sit'),
        recordAt(DateTime(2026, 1, 3)),
      ];

      final result = filterSessions(
        sessions,
        activity: SessionsActivityFilter.resting,
      );

      expect(result, [sessions[0], sessions[1]]);
    });

    test('period and activity combine with an implicit AND', () {
      final sessions = [
        // Walking, this week -> kept.
        recordAt(DateTime(2026, 7, 16, 8)),
        // Walking, previous week -> excluded by period.
        recordAt(DateTime(2026, 7, 12, 23, 59)),
        // Sitting, this week -> excluded by activity.
        recordAt(DateTime(2026, 7, 15), dominantLabel: 'sit'),
      ];

      final result = filterSessions(
        sessions,
        period: SessionsPeriodFilter.thisWeek,
        activity: SessionsActivityFilter.walking,
        now: now,
      );

      expect(result, [sessions[0]]);
    });
  });
}
