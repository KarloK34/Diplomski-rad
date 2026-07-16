import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gait_sense/blocs/pending_sessions/pending_sessions_cubit.dart';
import 'package:gait_sense/models/activity_prediction.dart';
import 'package:gait_sense/models/session_log.dart';
import 'package:gait_sense/repositories/session_log_repository.dart';
import 'package:gait_sense/repositories/session_repository.dart';
import 'package:gait_sense/screens/session_summary/session_summary_computation.dart';
import 'package:gait_sense/screens/session_summary/session_summary_content.dart';
import 'package:gait_sense/theme/gait_sense_theme.dart';
import 'package:go_router/go_router.dart';

/// Exercises [SessionSummaryContent]'s back-navigation confirmation directly
/// (bypassing `SessionSummaryScreen`'s `compute()` isolate hop) so the dialog
/// and pending-draft cleanup can be asserted deterministically instead of
/// racing an isolate result, as `session_summary_navigation_test.dart` does
/// for the full app/router integration.
void main() {
  late Directory tempDir;
  late SessionLogRepository repository;
  late PendingSessionsCubit pendingSessionsCubit;

  SessionLog sessionWithData(DateTime startedAt) {
    return SessionLog(
      startedAt: startedAt,
      stoppedAt: startedAt.add(const Duration(seconds: 10)),
      modelInfo: const {
        'class_labels': ['wlk', 'sit'],
      },
      predictions: [
        ActivityPrediction(
          label: 'wlk',
          probabilities: const [0.05, 0.05, 0.6, 0.1, 0.1, 0.1],
          timestamp: startedAt,
          inferenceLatencyMs: 3,
        ),
      ],
    );
  }

  Future<void> pumpSummary(WidgetTester tester, SessionLog session) async {
    final data = computeSessionSummaryData(
      SessionSummaryInput(session: session),
    );
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => context.push('/summary'),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/summary',
          builder: (context, state) =>
              SessionSummaryContent(session: session, data: data),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<SessionLogRepository>.value(value: repository),
          RepositoryProvider<SessionRepository>.value(
            value: SessionRepository(),
          ),
        ],
        child: BlocProvider<PendingSessionsCubit>.value(
          value: pendingSessionsCubit,
          child: MaterialApp.router(
            theme: GaitSenseTheme.light(),
            routerConfig: router,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync(
      'session_summary_content_test',
    );
    repository = SessionLogRepository(documentsDirectory: () async => tempDir);
    pendingSessionsCubit = PendingSessionsCubit(repository: repository);
    addTearDown(pendingSessionsCubit.close);
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  testWidgets(
    'backing out of a session with data shows a confirm dialog; '
    'cancelling stays on the summary',
    (tester) async {
      await pumpSummary(tester, sessionWithData(DateTime.utc(2026)));

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Odbaciti sesiju?'), findsOneWidget);

      await tester.tap(find.text('Odustani'));
      await tester.pumpAndSettle();

      expect(find.text('Sažetak sesije'), findsOneWidget);
      expect(find.text('Odbaciti sesiju?'), findsNothing);
    },
  );

  testWidgets(
    'confirming the discard deletes the pending draft and pops',
    (tester) async {
      final startedAt = DateTime.utc(2026);
      final session = sessionWithData(startedAt);
      await repository.savePendingDraft(session);

      await pumpSummary(tester, session);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Odbaci sesiju'));
      await tester.pumpAndSettle();

      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Sažetak sesije'), findsNothing);
      expect(await repository.listPendingDrafts(), isEmpty);
      expect(pendingSessionsCubit.state.sessions, isEmpty);
    },
  );

  testWidgets(
    'backing out of a session with no predictions pops without asking',
    (tester) async {
      final startedAt = DateTime.utc(2026);
      final empty = SessionLog(
        startedAt: startedAt,
        stoppedAt: startedAt.add(const Duration(seconds: 10)),
        modelInfo: const {},
        predictions: const [],
      );
      await repository.savePendingDraft(empty);

      await pumpSummary(tester, empty);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Odbaciti sesiju?'), findsNothing);
      expect(find.text('Open'), findsOneWidget);
      expect(await repository.listPendingDrafts(), isEmpty);
    },
  );
}
