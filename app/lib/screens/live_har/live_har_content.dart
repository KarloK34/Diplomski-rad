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
    return BlocBuilder<RecordingSessionBloc, RecordingSessionState>(
      builder: (context, state) {
        final bloc = context.read<RecordingSessionBloc>();
        return Scaffold(
          appBar: AppBar(
            title: const Text('Live HAR'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Postavke',
                onPressed: () => _openSettings(context),
              ),
              IconButton(
                icon: const Icon(Icons.sensors),
                tooltip: 'Debug senzori',
                onPressed: () => _openDebugScreen(context),
              ),
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
        );
      },
    );
  }

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
        return RecordingStatusPanel(
          status: state.status,
          elapsed: state.elapsed,
          maxSessionDuration: bloc.maxSessionDuration,
          predictionCount: state.predictionCount,
          latencyP50Ms: state.latencyP50Ms,
          latencyP95Ms: state.latencyP95Ms,
          latest: state.latest,
        );
    }
  }

  void _openSettings(BuildContext context) {
    unawaited(context.push(AppRoutes.recordSettings));
  }

  void _openDebugScreen(BuildContext context) {
    unawaited(context.push(AppRoutes.recordDebugSensors));
  }

  void _openInstructions(BuildContext context) {
    unawaited(context.push(AppRoutes.recordInstructions));
  }
}
