import 'package:flutter/widgets.dart';
import 'package:gait_sense/navigation/app_routes.dart';
import 'package:gait_sense/navigation/main_shell.dart';
import 'package:gait_sense/screens/home_screen.dart';
import 'package:gait_sense/screens/live_har_screen.dart';
import 'package:gait_sense/screens/profile_screen.dart';
import 'package:gait_sense/screens/sessions_screen.dart';
import 'package:gait_sense/screens/settings_screen.dart';
import 'package:go_router/go_router.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _homeNavigatorKey = GlobalKey<NavigatorState>();
final _recordNavigatorKey = GlobalKey<NavigatorState>();
final _sessionsNavigatorKey = GlobalKey<NavigatorState>();
final _profileNavigatorKey = GlobalKey<NavigatorState>();

/// Creates the app router with one preserved navigator stack per tab.
GoRouter createAppRouter() {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.home,
    routes: [
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
                    path: 'settings',
                    name: 'profileSettings',
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
