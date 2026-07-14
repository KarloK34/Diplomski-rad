import 'package:gait_sense/blocs/auth/auth_state.dart';
import 'package:gait_sense/blocs/onboarding/onboarding_state.dart';
import 'package:gait_sense/blocs/recording_session/recording_session_state.dart';
import 'package:gait_sense/navigation/app_routes.dart';

/// Redirect decision for `createAppRouter`'s `GoRouter.redirect`, gated by
/// sign-in status and, once signed in, per-account onboarding status.
///
/// Takes plain enum/string inputs rather than `BuildContext`/`GoRouterState`
/// so the branching is unit-testable without a router.
class AppRouterRedirect {
  /// Const so call sites can share a single instance.
  const AppRouterRedirect();

  /// Returns the path to redirect to, or null to allow [matchedLocation].
  String? call({
    required AuthStatus authStatus,
    required OnboardingStatus onboardingStatus,
    required RecordingStatus recordingStatus,
    required String matchedLocation,
  }) {
    final onSplash = matchedLocation == AppRoutes.splash;
    final onAuthPages =
        matchedLocation == AppRoutes.login ||
        matchedLocation == AppRoutes.signup;

    // While status is unknown, park on splash rather than assuming
    // signed-out, avoiding a login-screen flash for an already signed-in
    // user on cold start.
    if (authStatus == AuthStatus.unknown) {
      return onSplash ? null : AppRoutes.splash;
    }
    if (authStatus == AuthStatus.unauthenticated) {
      if (onAuthPages) return null;
      // Defer the sign-out redirect while a recording is being saved or its
      // summary is still pending display — otherwise this redirect unmounts
      // the record tab's LiveHarListener mid-flow and the finished session's
      // summary screen/RecordingSessionReset never happen. Once the
      // recording bloc returns to idle, refreshListenable fires again and
      // this re-evaluates.
      if (recordingStatus != RecordingStatus.idle) return null;
      return AppRoutes.login;
    }

    final onOnboarding = matchedLocation == AppRoutes.onboarding;
    if (onboardingStatus == OnboardingStatus.unresolved) {
      // The Firestore read is in flight — park on splash rather than
      // flashing home and then jumping to onboarding a moment later.
      return onSplash ? null : AppRoutes.splash;
    }
    if (onboardingStatus == OnboardingStatus.pending) {
      return onOnboarding ? null : AppRoutes.onboarding;
    }
    return (onOnboarding || onSplash || onAuthPages) ? AppRoutes.home : null;
  }
}
