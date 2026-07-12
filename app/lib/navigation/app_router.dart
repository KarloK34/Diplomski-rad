import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/auth/auth_cubit.dart';
import 'package:gait_sense/blocs/auth/auth_state.dart';
import 'package:gait_sense/blocs/ui/ui_bloc.dart';
import 'package:gait_sense/blocs/ui/ui_state.dart';
import 'package:gait_sense/models/session_log.dart';
import 'package:gait_sense/navigation/app_routes.dart';
import 'package:gait_sense/navigation/main_shell.dart';
import 'package:gait_sense/screens/debug_sensors/debug_sensors_screen.dart';
import 'package:gait_sense/screens/home_screen.dart';
import 'package:gait_sense/screens/live_har/live_har_screen.dart';
import 'package:gait_sense/screens/login/login_screen.dart';
import 'package:gait_sense/screens/profile_screen.dart';
import 'package:gait_sense/screens/session_summary/session_summary_screen.dart';
import 'package:gait_sense/screens/sessions_screen.dart';
import 'package:gait_sense/screens/settings_screen.dart';
import 'package:gait_sense/screens/signup/signup_screen.dart';
import 'package:gait_sense/screens/splash_screen.dart';
import 'package:go_router/go_router.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _homeNavigatorKey = GlobalKey<NavigatorState>();
final _recordNavigatorKey = GlobalKey<NavigatorState>();
final _sessionsNavigatorKey = GlobalKey<NavigatorState>();
final _profileNavigatorKey = GlobalKey<NavigatorState>();

/// Creates the app router with one preserved navigator stack per tab, gated
/// by [authCubit]'s sign-in status.
///
/// While status is `AuthStatus.unknown`, redirect points at the splash route
/// rather than assuming signed-out, avoiding a login-screen flash for an
/// already signed-in user on cold start.
///
/// [refreshListenable] must notify on both [authCubit]'s and the app's
/// `UiBloc`'s changes — the redirect below defers signing a user out while a
/// recording is in flight, so it needs re-evaluating once that recording
/// finishes too, not just on auth changes.
GoRouter createAppRouter({
  required AuthCubit authCubit,
  required Listenable refreshListenable,
}) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final status = authCubit.state.status;
      final onSplash = state.matchedLocation == AppRoutes.splash;
      final onAuthPages =
          state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.signup;

      if (status == AuthStatus.unknown) {
        return onSplash ? null : AppRoutes.splash;
      }
      if (status == AuthStatus.unauthenticated) {
        if (onAuthPages) return null;
        // Defer the sign-out redirect while a recording is being saved or
        // its summary is still pending display — otherwise this redirect
        // unmounts the record tab's LiveHarListener mid-flow and the
        // finished session's summary screen/UiReset never happen. Once the
        // recording bloc returns to idle, refreshListenable fires again and
        // this re-evaluates.
        final recordingInFlight =
            context.read<UiBloc>().state.status != RecordingStatus.idle;
        if (recordingInFlight) return null;
        return AppRoutes.login;
      }
      return (onSplash || onAuthPages) ? AppRoutes.home : null;
    },
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
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: _homeNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.home,
                name: AppTab.home.name,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _recordNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.record,
                name: AppTab.record.name,
                builder: (context, state) => const LiveHarScreen(),
                routes: [
                  GoRoute(
                    path: AppRoutes.recordSummarySegment,
                    name: AppSubRoute.recordSummary.name,
                    // `extra` is in-memory only and not restored across
                    // process death — bounce back rather than crash if this
                    // route is ever reached without a session attached.
                    redirect: (context, state) =>
                        state.extra is SessionLog ? null : AppRoutes.record,
                    builder: (context, state) => SessionSummaryScreen(
                      session: state.extra! as SessionLog,
                    ),
                  ),
                  GoRoute(
                    path: AppRoutes.recordDebugSensorsSegment,
                    name: AppSubRoute.recordDebugSensors.name,
                    builder: (context, state) => const DebugSensorsScreen(),
                  ),
                  GoRoute(
                    path: AppRoutes.settingsSegment,
                    name: AppSubRoute.recordSettings.name,
                    builder: (context, state) => const SettingsScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _sessionsNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.sessions,
                name: AppTab.sessions.name,
                builder: (context, state) => const SessionsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _profileNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                name: AppTab.profile.name,
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: AppRoutes.settingsSegment,
                    name: AppSubRoute.profileSettings.name,
                    builder: (context, state) => const SettingsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
