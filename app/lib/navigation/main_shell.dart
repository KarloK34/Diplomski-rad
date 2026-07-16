import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/recording_session/recording_session_bloc.dart';
import 'package:gait_sense/blocs/recording_session/recording_session_state.dart';
import 'package:gait_sense/navigation/app_routes.dart';
import 'package:go_router/go_router.dart';

/// Shell scaffold that hosts the bottom navigation and current tab branch.
class MainShell extends StatelessWidget {
  /// Creates the shell for [navigationShell].
  const MainShell({required this.navigationShell, super.key});

  /// go_router stateful shell used to switch between tab branches.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RecordingSessionBloc, RecordingSessionState>(
      buildWhen: (previous, current) => previous.status != current.status,
      builder: (context, state) {
        final isRecordingTab =
            navigationShell.currentIndex == AppTab.record.index;
        final showNavigation = !(isRecordingTab && state.isSessionActive);

        return Scaffold(
          body: navigationShell,
          bottomNavigationBar: ExcludeSemantics(
            excluding: !showNavigation,
            child: IgnorePointer(
              ignoring: !showNavigation,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: showNavigation ? 1 : 0,
                child: NavigationBar(
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: _onDestinationSelected,
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard),
                      label: 'Početna',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.fiber_manual_record_outlined),
                      selectedIcon: Icon(Icons.fiber_manual_record),
                      label: 'Snimanje',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.insights_outlined),
                      selectedIcon: Icon(Icons.insights),
                      label: 'Sesije',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person),
                      label: 'Profil',
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}
