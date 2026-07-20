import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gait_sense/blocs/auth/auth_cubit.dart';
import 'package:gait_sense/blocs/onboarding/onboarding_cubit.dart';
import 'package:gait_sense/blocs/onboarding/onboarding_state.dart';
import 'package:gait_sense/blocs/pending_sessions/pending_sessions_cubit.dart';
import 'package:gait_sense/blocs/recording_session/recording_session_bloc.dart';
import 'package:gait_sense/blocs/recording_session/recording_session_state.dart';
import 'package:gait_sense/blocs/sessions/sessions_cubit.dart';
import 'package:gait_sense/models/activity_prediction.dart';
import 'package:gait_sense/models/sensor_sample.dart';
import 'package:gait_sense/navigation/app_router.dart';
import 'package:gait_sense/navigation/go_router_refresh_stream.dart';
import 'package:gait_sense/repositories/auth_repository.dart';
import 'package:gait_sense/repositories/onboarding_repository.dart';
import 'package:gait_sense/repositories/session_log_repository.dart';
import 'package:gait_sense/repositories/session_repository.dart';
import 'package:gait_sense/repositories/user_profile_repository.dart';
import 'package:gait_sense/services/recording_controller.dart';
import 'package:gait_sense/theme/gait_sense_theme.dart';

/// Only satisfies [RecordingSessionBloc]'s constructor — this test drives
/// the bloc directly via `emit`, skipping the sensor/timer pipeline.
class _FakeController implements RecordingController {
  @override
  Stream<ActivityPrediction> get predictions => const Stream.empty();

  @override
  Stream<SensorSample> get samples => const Stream.empty();

  @override
  Future<void> requestPermissions() async {}

  @override
  Future<void> start() async {}

  @override
  void commitRecording() {}

  @override
  Future<void> stop() async {}
}

class _FakeUser implements User {
  const _FakeUser();

  @override
  String get uid => 'test-uid';

  @override
  String? get email => 'test@example.com';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Stream<User?> get userChanges => Stream.value(const _FakeUser());

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
    required String firstName,
    required String lastName,
  }) async {}

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> updateDisplayName(String displayName) async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {}
}

void main() {
  testWidgets(
    'back button after a recorded session returns to Live HAR, '
    'not a blank page',
    (tester) async {
      final tempDir = Directory.systemTemp.createTempSync(
        'session_summary_navigation_test',
      );
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final repository = SessionLogRepository(
        documentsDirectory: () async => tempDir,
      );
      final recordingSessionBloc = RecordingSessionBloc(
        controller: _FakeController(),
        repository: repository,
        tickInterval: const Duration(hours: 1),
        preparationDuration: const Duration(seconds: 1),
      );
      addTearDown(recordingSessionBloc.close);

      // Bind is never called (no gate), so it stays empty and never touches
      // Firebase — enough for the Home tab to build during navigation.
      final sessionRepository = SessionRepository();
      final sessionsCubit = SessionsCubit(repository: sessionRepository);
      addTearDown(sessionsCubit.close);
      final pendingSessionsCubit = PendingSessionsCubit(repository: repository);
      addTearDown(pendingSessionsCubit.close);

      final authCubit = AuthCubit(authRepository: _FakeAuthRepository());
      addTearDown(authCubit.close);
      final onboardingCubit = OnboardingCubit(
        repository: OnboardingRepository(),
      );
      addTearDown(onboardingCubit.close);
      // Skip the real Firestore-backed resolution — force the redirect gate
      // open directly, same as widget_test.dart's auth fake.
      onboardingCubit.emit(const OnboardingState.completed());

      final refreshListenable = GoRouterRefreshStream([
        authCubit.stream,
        onboardingCubit.stream,
        recordingSessionBloc.stream,
      ]);
      addTearDown(refreshListenable.dispose);

      final router = createAppRouter(
        authCubit: authCubit,
        onboardingCubit: onboardingCubit,
        refreshListenable: refreshListenable,
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<UserProfileRepository>.value(
              value: UserProfileRepository(),
            ),
            RepositoryProvider<SessionLogRepository>.value(value: repository),
            RepositoryProvider<SessionRepository>.value(
              value: sessionRepository,
            ),
          ],
          child: MultiBlocProvider(
            providers: [
              BlocProvider<RecordingSessionBloc>.value(
                value: recordingSessionBloc,
              ),
              BlocProvider<SessionsCubit>.value(value: sessionsCubit),
              BlocProvider<PendingSessionsCubit>.value(
                value: pendingSessionsCubit,
              ),
            ],
            child: MaterialApp.router(
              theme: GaitSenseTheme.light(),
              routerConfig: router,
            ),
          ),
        ),
      );

      // Let the fake auth stream emit + redirect chain settle onto Home.
      await tester.pumpAndSettle();

      await tester.tap(find.text('Snimanje'));
      await tester.pumpAndSettle();
      expect(find.text('Live HAR'), findsOneWidget);

      // Drives the bloc straight to "saved" (bypassing the real sensor/timer
      // pipeline) via the same path `_stopSession` leaves it in: the
      // repository holds the finished session before the state transition
      // that triggers navigation.
      final startedAt = DateTime.utc(2026);
      repository.startSession(startedAt: startedAt, modelInfo: const {});
      // Stopping now only builds the session in memory (no file I/O until the
      // user saves), mirroring what `_stopSession` leaves behind.
      final finished = repository.finish(
        stoppedAt: startedAt.add(const Duration(seconds: 10)),
      );
      recordingSessionBloc.emit(
        const RecordingSessionState.initial().copyWith(
          status: RecordingStatus.saved,
          finishedSession: finished,
        ),
      );

      // Both SessionSummaryLoadingView and the fully computed content show
      // an AppBar titled "Sažetak sesije" — asserting on it here avoids
      // needing SessionSummaryScreen's compute() isolate to resolve, which
      // this test (navigation behavior, not summary content) doesn't need.
      // Bounded pumps, not pumpAndSettle: the loading view's
      // CircularProgressIndicator animates forever, so pumpAndSettle would
      // never consider the tree settled.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Sažetak sesije'), findsOneWidget);

      // Tapping back pops the summary route and, right after, LiveHarListener
      // dispatches RecordingSessionReset — this used to race go_router's own
      // post-pop route-information bookkeeping and either land on a blank
      // SizedBox.shrink() or replay the push and undo the pop.
      await tester.tap(find.byTooltip('Back'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Live HAR'),
        findsOneWidget,
        reason: 'back should return to Live HAR, not a blank page',
      );
      expect(find.text('Sažetak sesije'), findsNothing);
    },
  );
}
