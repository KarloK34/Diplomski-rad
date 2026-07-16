import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gait_sense/blocs/sessions_list/sessions_list_cubit.dart';
import 'package:gait_sense/models/session_summary_record.dart';
import 'package:gait_sense/theme/gait_sense_theme.dart';
import 'package:gait_sense/utils/gait_cadence.dart';
import 'package:gait_sense/utils/session_summary.dart';
import 'package:gait_sense/widgets/widgets.dart';

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

  Future<void> pumpList(
    WidgetTester tester,
    List<SessionSummaryRecord> sessions,
  ) async {
    // Tall surface so every revealed card fits without needing to scroll the
    // assertions into view.
    tester.view.physicalSize = const Size(1000, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: GaitSenseTheme.light(),
        home: BlocProvider<SessionsListCubit>(
          create: (_) => SessionsListCubit(),
          child: Scaffold(
            body: FilteredSessionsList(
              sessions: sessions,
              onSessionTap: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> expandFilters(WidgetTester tester) async {
    await tester.tap(find.text('Filteri'));
    await tester.pumpAndSettle();
  }

  testWidgets('reveals five sessions at a time and collapses back', (
    tester,
  ) async {
    final sessions = [
      for (var i = 0; i < 12; i++) recordAt(DateTime(2026, 1, 1 + i)),
    ];

    await pumpList(tester, sessions);

    expect(find.byType(SessionListCard), findsNWidgets(5));
    expect(find.text('Prikaži još (5)'), findsOneWidget);
    expect(find.text('Prikaži manje'), findsNothing);

    await tester.tap(find.text('Prikaži još (5)'));
    await tester.pumpAndSettle();

    expect(find.byType(SessionListCard), findsNWidgets(10));
    expect(find.text('Prikaži još (2)'), findsOneWidget);
    expect(find.text('Prikaži manje'), findsOneWidget);

    await tester.tap(find.text('Prikaži još (2)'));
    await tester.pumpAndSettle();

    expect(find.byType(SessionListCard), findsNWidgets(12));
    expect(find.byType(TextButton), findsOneWidget); // only "Prikaži manje".

    await tester.tap(find.text('Prikaži manje'));
    await tester.pumpAndSettle();

    expect(find.byType(SessionListCard), findsNWidgets(5));
  });

  testWidgets(
    'switching the activity filter narrows the list and resets pagination',
    (tester) async {
      final sessions = [
        for (var i = 0; i < 3; i++) recordAt(DateTime(2026, 1, 1 + i)),
        for (var i = 0; i < 8; i++)
          recordAt(DateTime(2026, 2, 1 + i), dominantLabel: 'sit'),
      ];

      await pumpList(tester, sessions);

      expect(
        find.byType(SessionListCard),
        findsNWidgets(5),
      ); // first page of 11

      await expandFilters(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Hodanje'));
      await tester.pumpAndSettle();

      expect(find.byType(SessionListCard), findsNWidgets(3));
      expect(find.byType(TextButton), findsNothing); // one page covers all 3.
    },
  );

  testWidgets('period and activity filters combine to narrow the list', (
    tester,
  ) async {
    final now = DateTime.now();
    final earlierMonth = DateTime(now.year, now.month).subtract(
      const Duration(days: 45),
    );
    final sessions = [
      // Walking, this month -> kept by both facets.
      recordAt(DateTime(now.year, now.month)),
      // Sitting, this month -> excluded by activity.
      recordAt(DateTime(now.year, now.month, 2), dominantLabel: 'sit'),
      // Walking, an earlier month -> excluded by period.
      recordAt(earlierMonth),
    ];

    await pumpList(tester, sessions);

    await expandFilters(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Hodanje'));
    await tester.pumpAndSettle();
    expect(find.byType(SessionListCard), findsNWidgets(2));

    await tester.tap(find.widgetWithText(ChoiceChip, 'Ovaj mjesec'));
    await tester.pumpAndSettle();
    expect(find.byType(SessionListCard), findsNWidgets(1));
  });

  testWidgets('shows an empty state when no session matches the filters', (
    tester,
  ) async {
    final sessions = [recordAt(DateTime(2026), dominantLabel: 'sit')];

    await pumpList(tester, sessions);

    await expandFilters(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Hodanje'));
    await tester.pumpAndSettle();

    expect(find.text('Nema sesija za odabrani filtar'), findsOneWidget);
    expect(find.byType(SessionListCard), findsNothing);
  });
}
