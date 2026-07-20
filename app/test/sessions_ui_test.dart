import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gait_sense/blocs/pending_sessions/pending_sessions_cubit.dart';
import 'package:gait_sense/blocs/sessions/sessions_cubit.dart';
import 'package:gait_sense/models/session_summary_record.dart';
import 'package:gait_sense/repositories/session_log_repository.dart';
import 'package:gait_sense/repositories/session_repository.dart';
import 'package:gait_sense/screens/home_screen.dart';
import 'package:gait_sense/screens/session_detail/session_detail_content.dart';
import 'package:gait_sense/screens/sessions/sessions_screen.dart';
import 'package:gait_sense/theme/gait_sense_theme.dart';
import 'package:gait_sense/utils/gait_cadence.dart';
import 'package:gait_sense/utils/gait_walking_speed.dart';
import 'package:gait_sense/utils/session_summary.dart';
import 'package:gait_sense/widgets/widgets.dart';

/// Serves a fixed session list without touching Firebase.
class _FakeSessionRepository implements SessionRepository {
  _FakeSessionRepository(this._sessions);

  final List<SessionSummaryRecord> _sessions;

  @override
  Stream<List<SessionSummaryRecord>> watchSessions() => Stream.value(_sessions);

  @override
  Future<void> saveSession(SessionSummaryRecord record) async {}

  @override
  Future<void> deleteSession(String startedAtIso) async {}
}

SessionQualitySummary _quality({
  required int predictionCount,
  double? cadence,
  double? speed,
}) {
  return SessionQualitySummary(
    predictionCount: predictionCount,
    rawSmoothedChangeCount: 0,
    rawSmoothedChangeFraction: 0,
    effectiveLabelWindowCounts: const {'wlk': 150, 'std': 50},
    rawLabelWindowCounts: const {'wlk': 150, 'std': 50},
    stableLocomotionSegments: const [],
    stableLocomotionWindowCount: 0,
    stableLocomotionDuration: Duration.zero,
    hasEnoughStableLocomotion: false,
    gaitSegments: const [],
    gaitCadence: GaitCadenceSummary(
      signalSegmentCount: 0,
      sampledSignalSegmentCount: 0,
      computedResultCount: cadence != null ? 1 : 0,
      averageCadenceStepsPerMinute: cadence,
      totalStepCount: cadence != null ? 200 : 0,
      temporalParameters: null,
      status: cadence != null
          ? GaitCadenceStatus.computed
          : GaitCadenceStatus.empty,
      reason: null,
      confidence: GaitCadenceConfidence.moderate,
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

SessionSummaryRecord _record(DateTime startedAt, double cadence, double speed) {
  return SessionSummaryRecord(
    startedAt: startedAt,
    stoppedAt: startedAt.add(const Duration(minutes: 5)),
    duration: const Duration(minutes: 5),
    deviceId: null,
    predictionCount: 200,
    modelInfo: const {},
    heightCmAtRecording: 175,
    classTotals: const [
      ClassTotal(
        label: 'wlk',
        windows: 150,
        time: Duration(minutes: 4),
        fraction: 0.75,
      ),
      ClassTotal(
        label: 'std',
        windows: 50,
        time: Duration(minutes: 1),
        fraction: 0.25,
      ),
    ],
    timeline: const [
      TimelineSegment(
        label: 'wlk',
        start: Duration.zero,
        end: Duration(minutes: 4),
        windows: 150,
      ),
      TimelineSegment(
        label: 'std',
        start: Duration(minutes: 4),
        end: Duration(minutes: 5),
        windows: 50,
      ),
    ],
    quality: _quality(predictionCount: 200, cadence: cadence, speed: speed),
  );
}

void main() {
  final sessions = [
    _record(DateTime.now().subtract(const Duration(days: 1)), 120, 1.3),
    _record(DateTime.now().subtract(const Duration(days: 2)), 100, 1.1),
  ];

  Future<void> pumpWithCubit(WidgetTester tester, Widget screen) async {
    // Tall surface so nothing the assertions look for is below the lazy
    // ListView fold.
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final cubit = SessionsCubit(repository: _FakeSessionRepository(sessions))
      ..bind();
    addTearDown(cubit.close);

    // Never refreshed, so it stays at its empty initial state — enough for
    // HomeScreen's pending-session banner to build without touching disk.
    final pendingSessionsCubit = PendingSessionsCubit(
      repository: SessionLogRepository(
        documentsDirectory: () async => Directory.systemTemp,
      ),
    );
    addTearDown(pendingSessionsCubit.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: GaitSenseTheme.light(),
        home: MultiBlocProvider(
          providers: [
            BlocProvider<SessionsCubit>.value(value: cubit),
            BlocProvider<PendingSessionsCubit>.value(
              value: pendingSessionsCubit,
            ),
          ],
          child: Scaffold(body: screen),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Home shows aggregate metrics from saved sessions', (
    tester,
  ) async {
    await pumpWithCubit(tester, const HomeScreen());

    expect(find.text('Gait Sense'), findsOneWidget);
    expect(find.text('110 kor/min'), findsOneWidget); // mean of 100 and 120
    expect(find.text('1.2 m/s'), findsOneWidget); // mean of 1.1 and 1.3
    expect(find.text('Zadnja sesija'), findsOneWidget);
  });

  testWidgets('Sessions tab lists sessions and renders trend charts', (
    tester,
  ) async {
    await pumpWithCubit(tester, const SessionsScreen());

    expect(find.byType(SessionListCard), findsNWidgets(2));
    expect(find.text('Trend kadence'), findsOneWidget);
    expect(find.text('Trend brzine hoda'), findsOneWidget);
    expect(find.text('Usporedba aktivnosti'), findsOneWidget);
  });

  testWidgets(
    'Session detail renders charts, classification quality, and gait '
    'parameters',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: GaitSenseTheme.light(),
          home: SessionDetailContent(record: sessions.first),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Udio po aktivnosti'), findsOneWidget);
      expect(find.text('Vremenski slijed'), findsOneWidget);
      expect(find.text('Kvaliteta klasifikacije'), findsOneWidget);
      expect(find.text('Parametri hoda'), findsOneWidget);
    },
  );
}
