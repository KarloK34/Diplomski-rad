import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/recording_session/recording_session_bloc.dart';
import 'package:gait_sense/models/session_log.dart';
import 'package:gait_sense/navigation/app_navigator_keys.dart';
import 'package:gait_sense/navigation/app_routes.dart';
import 'package:gait_sense/screens/about_screen.dart';
import 'package:gait_sense/screens/home_screen.dart';
import 'package:gait_sense/screens/live_har/live_har_screen.dart';
import 'package:gait_sense/screens/live_har/recording_instructions_screen.dart';
import 'package:gait_sense/screens/privacy_screen.dart';
import 'package:gait_sense/screens/profile/profile_screen.dart';
import 'package:gait_sense/screens/session_detail/session_detail_screen.dart';
import 'package:gait_sense/screens/session_summary/session_summary_screen.dart';
import 'package:gait_sense/screens/sessions/sessions_screen.dart';
import 'package:gait_sense/screens/settings_screen.dart';
import 'package:go_router/go_router.dart';

final _homeNavigatorKey = GlobalKey<NavigatorState>();
final _recordNavigatorKey = GlobalKey<NavigatorState>();
final _sessionsNavigatorKey = GlobalKey<NavigatorState>();
final _profileNavigatorKey = GlobalKey<NavigatorState>();

/// The four tab branches hosted by `createAppRouter`'s indexed-stack shell,
/// one preserved navigator stack each.
List<StatefulShellBranch> appShellBranches() => [
  _homeBranch(),
  _recordBranch(),
  _sessionsBranch(),
  _profileBranch(),
];

StatefulShellBranch _homeBranch() => StatefulShellBranch(
  navigatorKey: _homeNavigatorKey,
  routes: [
    GoRoute(
      path: AppRoutes.home,
      name: AppTab.home.name,
      builder: (context, state) => const HomeScreen(),
    ),
  ],
);

StatefulShellBranch _recordBranch() => StatefulShellBranch(
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
          parentNavigatorKey: rootNavigatorKey,
          redirect: (context, state) =>
              context.read<RecordingSessionBloc>().state.finishedSession != null
              ? null
              : AppRoutes.record,
          builder: (context, state) {
            final session = context
                .read<RecordingSessionBloc>()
                .state
                .finishedSession;
            return session != null
                ? SessionSummaryScreen(session: session)
                : const SizedBox.shrink();
          },
        ),
        GoRoute(
          path: AppRoutes.recordRecoveredSummarySegment,
          name: AppSubRoute.recordRecoveredSummary.name,
          parentNavigatorKey: rootNavigatorKey,
          redirect: (context, state) =>
              state.extra is SessionLog ? null : AppRoutes.record,
          builder: (context, state) =>
              SessionSummaryScreen(session: state.extra! as SessionLog),
        ),
        GoRoute(
          path: AppRoutes.recordInstructionsSegment,
          name: AppSubRoute.recordInstructions.name,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const RecordingInstructionsScreen(),
        ),
        GoRoute(
          path: AppRoutes.settingsSegment,
          name: AppSubRoute.recordSettings.name,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
  ],
);

StatefulShellBranch _sessionsBranch() => StatefulShellBranch(
  navigatorKey: _sessionsNavigatorKey,
  routes: [
    GoRoute(
      path: AppRoutes.sessions,
      name: AppTab.sessions.name,
      builder: (context, state) => const SessionsScreen(),
      routes: [
        GoRoute(
          path: AppRoutes.sessionDetailSegment,
          name: AppSubRoute.sessionDetail.name,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => SessionDetailScreen(
            sessionId: state.pathParameters['sessionId']!,
          ),
        ),
      ],
    ),
  ],
);

StatefulShellBranch _profileBranch() => StatefulShellBranch(
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
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: AppRoutes.privacySegment,
          name: AppSubRoute.profilePrivacy.name,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const PrivacyScreen(),
        ),
        GoRoute(
          path: AppRoutes.aboutSegment,
          name: AppSubRoute.profileAbout.name,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const AboutScreen(),
        ),
      ],
    ),
  ],
);
