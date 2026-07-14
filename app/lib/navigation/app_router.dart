import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/auth/auth_cubit.dart';
import 'package:gait_sense/blocs/onboarding/onboarding_cubit.dart';
import 'package:gait_sense/blocs/recording_session/recording_session_bloc.dart';
import 'package:gait_sense/navigation/app_navigator_keys.dart';
import 'package:gait_sense/navigation/app_router_branches.dart';
import 'package:gait_sense/navigation/app_router_redirect.dart';
import 'package:gait_sense/navigation/app_routes.dart';
import 'package:gait_sense/navigation/main_shell.dart';
import 'package:gait_sense/screens/login/login_screen.dart';
import 'package:gait_sense/screens/onboarding/onboarding_screen.dart';
import 'package:gait_sense/screens/signup/signup_screen.dart';
import 'package:gait_sense/screens/splash_screen.dart';
import 'package:go_router/go_router.dart';

const _redirect = AppRouterRedirect();

/// Creates the app router with one preserved navigator stack per tab, gated
/// by [authCubit]'s sign-in status and, once signed in, [onboardingCubit]'s
/// per-account onboarding status. See [AppRouterRedirect] for the gating
/// logic itself.
///
/// [refreshListenable] must notify on [authCubit]'s, [onboardingCubit]'s, and
/// the app's `RecordingSessionBloc`'s changes — the redirect defers signing
/// a user out while a recording is in flight, so it needs re-evaluating
/// once that recording finishes too, not just on auth/onboarding changes.
GoRouter createAppRouter({
  required AuthCubit authCubit,
  required OnboardingCubit onboardingCubit,
  required Listenable refreshListenable,
}) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: refreshListenable,
    redirect: (context, state) => _redirect(
      authStatus: authCubit.state.status,
      onboardingStatus: onboardingCubit.state.status,
      recordingStatus: context.read<RecordingSessionBloc>().state.status,
      matchedLocation: state.matchedLocation,
    ),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: appShellBranches(),
      ),
    ],
  );
}
