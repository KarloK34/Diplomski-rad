import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/ui/ui_bloc.dart';
import 'package:gait_sense/blocs/ui/ui_event.dart';
import 'package:gait_sense/blocs/ui/ui_state.dart';
import 'package:gait_sense/navigation/app_routes.dart';
import 'package:gait_sense/widgets/widgets.dart';
import 'package:go_router/go_router.dart';

/// Renders [UiBloc]'s state: the Start/Stop control and the live readouts.
class LiveHarContent extends StatelessWidget {
  /// Creates the live HAR content.
  const LiveHarContent({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UiBloc, UiState>(
      builder: (context, state) {
        final bloc = context.read<UiBloc>();
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
            ],
          ),
          body: RecordingStatusPanel(
            status: state.status,
            elapsed: state.elapsed,
            maxSessionDuration: bloc.maxSessionDuration,
            predictionCount: state.predictionCount,
            latencyP50Ms: state.latencyP50Ms,
            latencyP95Ms: state.latencyP95Ms,
            latest: state.latest,
          ),
          floatingActionButton: RecordingFab(
            status: state.status,
            onStart: () => bloc.add(const UiRecordingStarted()),
            onStop: () => bloc.add(const UiRecordingStopped()),
          ),
        );
      },
    );
  }

  void _openSettings(BuildContext context) {
    unawaited(context.push(AppRoutes.recordSettings));
  }

  void _openDebugScreen(BuildContext context) {
    unawaited(context.push(AppRoutes.recordDebugSensors));
  }
}
