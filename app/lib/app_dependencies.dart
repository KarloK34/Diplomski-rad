import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:gait_sense/blocs/auth/auth_cubit.dart';
import 'package:gait_sense/blocs/onboarding/onboarding_cubit.dart';
import 'package:gait_sense/blocs/onboarding/onboarding_gate.dart';
import 'package:gait_sense/blocs/recording_session/recording_session_bloc.dart';
import 'package:gait_sense/firebase_options.dart';
import 'package:gait_sense/navigation/app_router.dart';
import 'package:gait_sense/navigation/go_router_refresh_stream.dart';
import 'package:gait_sense/repositories/auth_repository.dart';
import 'package:gait_sense/repositories/onboarding_repository.dart';
import 'package:gait_sense/repositories/session_log_repository.dart';
import 'package:gait_sense/repositories/session_summary_repository.dart';
import 'package:gait_sense/repositories/user_preferences_repository.dart';
import 'package:gait_sense/services/gait_foreground_service.dart';
import 'package:go_router/go_router.dart';

/// Owns construction/lifecycle of the app's singleton dependencies and the
/// router built from them; `GaitSenseApp` only owns widget lifecycle and
/// tree building.
class AppDependencies {
  /// [authRepository] is overridable so tests can substitute a fake instead
  /// of touching real Firebase.
  AppDependencies({AuthRepository? authRepository})
    : authRepository = authRepository ?? _defaultAuthRepository();

  /// Runs sensing/inference in the background isolate.
  final GaitForegroundService service = GaitForegroundService();

  /// Persists finished recording sessions on-device.
  final SessionLogRepository sessionLogRepository = SessionLogRepository();

  /// Persists user-configurable app settings.
  final UserPreferencesRepository userPreferencesRepository =
      UserPreferencesRepository();

  /// Syncs finished session summaries to the signed-in account.
  final SessionSummaryRepository sessionSummaryRepository =
      SessionSummaryRepository();

  /// Persists per-account onboarding completion.
  final OnboardingRepository onboardingRepository = OnboardingRepository();

  /// The app's [AuthRepository]; overridden by tests via the constructor.
  final AuthRepository authRepository;

  /// Tracks the signed-in account's status.
  late final AuthCubit authCubit = AuthCubit(authRepository: authRepository);

  /// Tracks whether the signed-in account has completed onboarding.
  late final OnboardingCubit onboardingCubit = OnboardingCubit(
    repository: onboardingRepository,
  );

  /// Orchestrates the current/last recording session.
  late final RecordingSessionBloc recordingSessionBloc = RecordingSessionBloc(
    controller: service,
    repository: sessionLogRepository,
    summaryRepository: sessionSummaryRepository,
  );

  late final OnboardingGate _onboardingGate = OnboardingGate(
    authCubit: authCubit,
    onboardingCubit: onboardingCubit,
  );

  /// Notifies go_router's redirect to re-run on auth/onboarding/recording
  /// changes.
  late final GoRouterRefreshStream refreshListenable = GoRouterRefreshStream([
    authCubit.stream,
    onboardingCubit.stream,
    recordingSessionBloc.stream,
  ]);

  /// The app's router, gated by [authCubit] and [onboardingCubit].
  late final GoRouter router = createAppRouter(
    authCubit: authCubit,
    onboardingCubit: onboardingCubit,
    refreshListenable: refreshListenable,
  );

  /// Starts the foreground service and the onboarding gate. Must be called
  /// exactly once, from `State.initState`.
  void init() {
    service.init();
    _onboardingGate.start();
  }

  // Android's OAuth "Web client" id (google-services.json oauth_client,
  // client_type 3) — needed so Google's ID token is one Firebase accepts.
  static AuthRepository _defaultAuthRepository() {
    return AuthRepository(
      googleServerClientId:
          // The OAuth client id itself can't be wrapped.
          // ignore: lines_longer_than_80_chars
          '900038882223-8ur8ge2s5duga2a801nkjassp8pu7pt8.apps.googleusercontent.com',
      // iOS has no bundled GoogleService-Info.plist — supply the id from
      // FlutterFire's generated options instead.
      googleClientId: defaultTargetPlatform == TargetPlatform.iOS
          ? DefaultFirebaseOptions.ios.iosClientId
          : null,
    );
  }

  /// Tears everything down. Must be called exactly once, from
  /// `State.dispose`.
  void dispose() {
    router.dispose();
    refreshListenable.dispose();
    _onboardingGate.dispose();
    unawaited(authCubit.close());
    unawaited(onboardingCubit.close());
    unawaited(recordingSessionBloc.close());
    service.dispose();
  }
}
