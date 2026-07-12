import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gait_sense/app.dart';
import 'package:gait_sense/models/activity_prediction.dart';
import 'package:gait_sense/models/sensor_sample.dart';
import 'package:gait_sense/models/session_log.dart';
import 'package:gait_sense/screens/session_summary/session_summary_error_view.dart';
import 'package:gait_sense/screens/session_summary/session_summary_screen.dart';
import 'package:gait_sense/services/auth_repository.dart';
import 'package:gait_sense/services/user_preferences_repository.dart';
import 'package:gait_sense/theme/gait_sense_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wraps [child] in a [RepositoryProvider] that serves a real
/// [UserPreferencesRepository] backed by an in-memory SharedPreferences store.
///
/// Applies [GaitSenseTheme] rather than a bare [MaterialApp] theme, since the
/// widget tree reads spacing/color/text-style tokens off it.
Widget _withPrefs(Widget child) {
  return RepositoryProvider<UserPreferencesRepository>(
    create: (_) => UserPreferencesRepository(),
    child: MaterialApp(theme: GaitSenseTheme.light(), home: child),
  );
}

/// Minimal stand-in for [User] — `noSuchMethod` covers the dozens of members
/// this test never touches; only `uid`/`email` need real implementations.
class _FakeUser implements User {
  const _FakeUser();

  @override
  String get uid => 'test-uid';

  @override
  String? get email => 'test@example.com';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Pre-authenticated [AuthRepository] fake, since this test file never calls
/// `Firebase.initializeApp()`.
class _FakeAuthRepository implements AuthRepository {
  @override
  Stream<User?> get authStateChanges => Stream.value(const _FakeUser());

  @override
  User? get currentUser => const _FakeUser();

  @override
  String? get googleServerClientId => null;

  @override
  String? get googleClientId => null;

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signOut() async {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  testWidgets('app renders bottom navigation and opens recording tab', (
    tester,
  ) async {
    await tester.pumpWidget(
      GaitSenseApp(authRepository: _FakeAuthRepository()),
    );
    // Settles the auth-status → router-redirect chain before asserting.
    await tester.pumpAndSettle();

    final navigationBar = find.byType(NavigationBar);
    expect(find.text('Gait Sense'), findsOneWidget);
    expect(
      find.descendant(of: navigationBar, matching: find.text('Početna')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navigationBar, matching: find.text('Snimanje')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navigationBar, matching: find.text('Sesije')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navigationBar, matching: find.text('Profil')),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(of: navigationBar, matching: find.text('Snimanje')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Live HAR'), findsOneWidget);
    expect(find.text('Zaustavljeno'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
  });

  testWidgets('session summary shows a loading indicator before data arrives', (
    tester,
  ) async {
    final start = DateTime.utc(2026, 1, 1, 12);
    final session = SessionLog(
      startedAt: start,
      stoppedAt: start.add(const Duration(seconds: 10)),
      modelInfo: const {},
      predictions: const [],
    );

    await tester.pumpWidget(
      _withPrefs(SessionSummaryScreen(session: session)),
    );

    // First frame: Future not yet resolved → loading scaffold is visible.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('session summary shows experimental cadence when computed', (
    tester,
  ) async {
    final start = DateTime.utc(2026, 1, 1, 12);

    SensorSample sampleAt(int index) {
      return SensorSample(
        timestamp: start.add(Duration(milliseconds: index * 20)),
        gravityX: 0,
        gravityY: 0,
        gravityZ: 1,
        userAccelerationX: 0,
        userAccelerationY: 0,
        userAccelerationZ:
            0.06 + 0.08 * (1 + math.sin(2 * math.pi * 2 * index * 0.02)) / 2,
        rotationRateX: 0,
        rotationRateY: 0,
        rotationRateZ: 0,
      );
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

    final session = SessionLog(
      startedAt: start,
      stoppedAt: start.add(const Duration(seconds: 10)),
      modelInfo: const {},
      rawSamples: [for (var i = 0; i < 500; i++) sampleAt(i)],
      predictions: [
        predictionAt(3, 177),
        predictionAt(4, 241),
        predictionAt(5, 305),
        predictionAt(6, 369),
        predictionAt(8, 433),
      ],
    );

    await tester.pumpWidget(
      _withPrefs(SessionSummaryScreen(session: session)),
    );

    await pumpUntilFound(tester, find.text('Kadenca (eksperimentalno)'));

    expect(find.text('Kadenca (eksperimentalno)'), findsOneWidget);
    expect(find.text('120 koraka/min'), findsOneWidget);
    expect(
      find.text('Detektirani koraci (eksperimentalno)'),
      findsOneWidget,
    );
    expect(find.text('Pouzdanost procjene'), findsOneWidget);
    expect(find.text('Visoka'), findsOneWidget);
    expect(
      find.text('Prosječno vrijeme koraka (eksperimentalno)'),
      findsOneWidget,
    );
    expect(
      find.text('Varijabilnost vremena koraka (eksperimentalno)'),
      findsOneWidget,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(
      find.text('Prosječno vrijeme iskoraka (eksperimentalno)'),
      findsOneWidget,
    );
    expect(
      find.text('Varijabilnost vremena iskoraka (eksperimentalno)'),
      findsOneWidget,
    );
    expect(
      find.text('Regularnost signala (indikator kvalitete)'),
      findsOneWidget,
    );
    expect(find.text('Razlog'), findsNothing);
  });

  testWidgets(
    'session summary marks step count unavailable when not computed',
    (tester) async {
      final start = DateTime.utc(2026, 1, 1, 12);

      ActivityPrediction predictionAt(int secondsAfterStart) {
        return ActivityPrediction(
          label: 'wlk',
          probabilities: const [0.1, 0.1, 0.5, 0.1, 0.1, 0.1],
          timestamp: start.add(Duration(seconds: secondsAfterStart)),
          inferenceLatencyMs: 10,
        );
      }

      final session = SessionLog(
        startedAt: start,
        stoppedAt: start.add(const Duration(seconds: 8)),
        modelInfo: const {},
        predictions: [
          for (var second = 3; second <= 7; second++) predictionAt(second),
        ],
      );

      await tester.pumpWidget(
        _withPrefs(SessionSummaryScreen(session: session)),
      );

      await pumpUntilFound(
        tester,
        find.text('Detektirani koraci (eksperimentalno)'),
      );

      expect(
        find.text('Detektirani koraci (eksperimentalno)'),
        findsOneWidget,
      );
      expect(find.text('Nije dostupno'), findsOneWidget);
      expect(find.text('Razlog'), findsOneWidget);
      expect(
        find.text('Prosječno vrijeme koraka (eksperimentalno)'),
        findsNothing,
      );
    },
  );

  testWidgets('session summary shows error scaffold on compute failure', (
    tester,
  ) async {
    // A compute() failure can't be forced directly, so this pumps the error
    // view directly to verify it renders correctly.
    await tester.pumpWidget(
      MaterialApp(
        theme: GaitSenseTheme.light(),
        home: const SessionSummaryErrorView(error: 'Simulated compute error'),
      ),
    );

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.text('Nije moguće izračunati sažetak sesije.'), findsOneWidget);
    expect(find.text('Natrag'), findsOneWidget);
  });
}

Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
  const timeout = Duration(seconds: 5);
  const interval = Duration(milliseconds: 20);
  final stopwatch = Stopwatch()..start();

  while (stopwatch.elapsed < timeout) {
    await tester.runAsync<void>(() async {
      await Future<void>.delayed(interval);
    });
    await tester.pump();

    if (finder.evaluate().isNotEmpty) return;
  }

  fail('Timed out waiting for async summary content.');
}
