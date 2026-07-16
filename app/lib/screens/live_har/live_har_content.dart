import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/recording_session/recording_session_bloc.dart';
import 'package:gait_sense/blocs/recording_session/recording_session_event.dart';
import 'package:gait_sense/blocs/recording_session/recording_session_state.dart';
import 'package:gait_sense/navigation/app_routes.dart';
import 'package:gait_sense/widgets/widgets.dart';
import 'package:go_router/go_router.dart';

/// Renders [RecordingSessionBloc]'s state: the Start/Stop control and the
/// live readouts.
class LiveHarContent extends StatelessWidget {
  /// Creates the live HAR content.
  const LiveHarContent({super.key});

  @override
  Widget build(BuildContext context) {
    // Scoped to status/countdown only: elapsed, predictionCount, latency and
    // latest all change every tick during an active session and would
    // otherwise tear down and rebuild the AppBar/FAB shell on every one of
    // them. The frequently-changing readouts get their own BlocBuilder in
    // [_body] instead, so only that subtree pays for those rebuilds.
    return BlocBuilder<RecordingSessionBloc, RecordingSessionState>(
      buildWhen: (previous, current) =>
          previous.status != current.status ||
          previous.countdownSecondsRemaining !=
              current.countdownSecondsRemaining,
      builder: (context, state) {
        final bloc = context.read<RecordingSessionBloc>();
        return PopScope(
          // A pocketed back-gesture must not be able to leave this screen
          // while a session is in flight — there'd be no visible way back.
          canPop: !state.isSessionActive,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Live HAR'),
              // Hidden while a session is active so a pocketed touch has
              // nothing to navigate away to.
              actions: state.isSessionActive
                  ? null
                  : [
                      IconButton(
                        icon: const Icon(Icons.settings_outlined),
                        tooltip: 'Postavke',
                        onPressed: () => _openSettings(context),
                      ),
                      const SessionImportAction(),
                      IconButton(
                        icon: const Icon(Icons.info_outline),
                        tooltip: 'Upute',
                        onPressed: () => _openInstructions(context),
                      ),
                    ],
            ),
            body: _body(state, bloc),
            floatingActionButton: RecordingFab(
              status: state.status,
              countdownSecondsRemaining: state.countdownSecondsRemaining,
              onStart: () => bloc.add(const RecordingSessionStarted()),
              onStop: () => bloc.add(const RecordingSessionStopped()),
              onCancel: () =>
                  bloc.add(const RecordingSessionCountdownCancelled()),
            ),
          ),
        );
      },
    );
  }

  // [state] here is only as fresh as the outer BlocBuilder's buildWhen
  // allows — fine for the preparing countdown (already covered by it), but
  // the idle/recording/saving/saved panel needs fields that change far more
  // often, so it reads the bloc's live state through its own BlocBuilder
  // instead of relying on this one.
  Widget _body(RecordingSessionState state, RecordingSessionBloc bloc) {
    switch (state.status) {
      case RecordingStatus.preparing:
        return RecordingCountdownPanel(
          secondsRemaining: state.countdownSecondsRemaining,
        );
      case RecordingStatus.unavailable:
        return const SensorUnavailablePanel();
      case RecordingStatus.idle:
      case RecordingStatus.recording:
      case RecordingStatus.saving:
      case RecordingStatus.saved:
        return BlocBuilder<RecordingSessionBloc, RecordingSessionState>(
          builder: (context, liveState) => RecordingStatusPanel(
            status: liveState.status,
            elapsed: liveState.elapsed,
            maxSessionDuration: bloc.maxSessionDuration,
            predictionCount: liveState.predictionCount,
            latencyP50Ms: liveState.latencyP50Ms,
            latencyP95Ms: liveState.latencyP95Ms,
            latest: liveState.latest,
          ),
        );
    }
  }

  void _openSettings(BuildContext context) {
    unawaited(context.push(AppRoutes.recordSettings));
  }

  void _openInstructions(BuildContext context) {
    unawaited(context.push(AppRoutes.recordInstructions));
  }
}
