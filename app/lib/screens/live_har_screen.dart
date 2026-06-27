import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/sensor_stream/sensor_stream_bloc.dart';
import 'package:gait_sense/blocs/ui/ui_bloc.dart';
import 'package:gait_sense/blocs/ui/ui_event.dart';
import 'package:gait_sense/blocs/ui/ui_state.dart';
import 'package:gait_sense/models/activity_prediction.dart';
import 'package:gait_sense/screens/debug_sensors_screen.dart';
import 'package:gait_sense/screens/session_summary_screen.dart';
import 'package:gait_sense/services/sensor_service.dart';
import 'package:gait_sense/utils/activity_labels.dart';

/// The recording screen: a single Start/Stop control over the background
/// recording service, plus the live readouts derived by [UiBloc].
///
/// State lives entirely in [UiBloc]; this widget renders it and dispatches user
/// intents. When a session finishes it navigates to [SessionSummaryScreen] and,
/// on return, resets the bloc back to idle.
class LiveHarScreen extends StatelessWidget {
  /// Creates the live screen.
  const LiveHarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<UiBloc, UiState>(
      // Fire once on the transition into the saved state, not on every rebuild
      // while it stays saved.
      listenWhen: (previous, current) =>
          previous.status != RecordingStatus.saved &&
          current.status == RecordingStatus.saved,
      listener: (context, state) {
        final session = state.finishedSession;
        if (session == null) return;

        if (state.stoppedByLimit) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Sesija je automatski zaustavljena — dostignut je limit od 30 minuta.',
              ),
              duration: Duration(seconds: 5),
            ),
          );
        }

        unawaited(
          Navigator.of(context)
              .push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => SessionSummaryScreen(session: session),
                ),
              )
              .then((_) {
                if (context.mounted) {
                  context.read<UiBloc>().add(const UiReset());
                }
              }),
        );
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Live HAR'),
            actions: [
              IconButton(
                icon: const Icon(Icons.sensors),
                tooltip: 'Debug senzori',
                onPressed: () => _openDebugScreen(context),
              ),
            ],
          ),
          body: _Body(state: state),
          floatingActionButton: _RecordButton(state: state),
        );
      },
    );
  }

  void _openDebugScreen(BuildContext context) {
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BlocProvider(
            create: (_) => SensorStreamBloc(sensorService: SensorService()),
            child: const DebugSensorsScreen(),
          ),
        ),
      ),
    );
  }
}

/// Start/Stop control whose appearance follows the recording status.
class _RecordButton extends StatelessWidget {
  const _RecordButton({required this.state});

  final UiState state;

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case RecordingStatus.saving:
        return const FloatingActionButton.extended(
          onPressed: null,
          icon: SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          label: Text('Spremanje…'),
        );
      case RecordingStatus.recording:
        return FloatingActionButton.extended(
          onPressed: () =>
              context.read<UiBloc>().add(const UiRecordingStopped()),
          icon: const Icon(Icons.stop),
          label: const Text('Stop'),
        );
      case RecordingStatus.idle:
      case RecordingStatus.saved:
        return FloatingActionButton.extended(
          onPressed: () =>
              context.read<UiBloc>().add(const UiRecordingStarted()),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start'),
        );
    }
  }
}

/// The body: status, elapsed time, latency readout, and the de-emphasized
/// per-window prediction ticker.
class _Body extends StatelessWidget {
  const _Body({required this.state});

  final UiState state;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodyMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final bloc = context.read<UiBloc>();

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_statusLabel(state.status), style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            _formatElapsed(state.elapsed),
            style: textTheme.displayMedium,
          ),
          if (state.status == RecordingStatus.recording) ...[
            const SizedBox(height: 4),
            _SessionLimitBar(
              elapsed: state.elapsed,
              maxDuration: bloc.maxSessionDuration,
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'Predikcija: ${state.predictionCount}',
            style: textTheme.bodyLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Latencija: p50 ${state.latencyP50Ms} ms · '
            'p95 ${state.latencyP95Ms} ms',
            style: muted,
          ),
          const SizedBox(height: 24),
          // The per-window label is intentionally de-emphasized: single-window
          // predictions are noisy, and the session totals on the summary screen
          // are the headline result rather than this live ticker.
          _Ticker(latest: state.latest, style: muted),
        ],
      ),
    );
  }

  static String _statusLabel(RecordingStatus status) {
    switch (status) {
      case RecordingStatus.recording:
        return 'Snimanje u tijeku';
      case RecordingStatus.saving:
        return 'Spremanje…';
      case RecordingStatus.idle:
      case RecordingStatus.saved:
        return 'Zaustavljeno';
    }
  }

  static String _formatElapsed(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

/// Thin progress bar + remaining-time label that shows how much of the 30-min
/// session budget has been consumed.
class _SessionLimitBar extends StatelessWidget {
  const _SessionLimitBar({
    required this.elapsed,
    required this.maxDuration,
  });

  final Duration elapsed;
  final Duration maxDuration;

  @override
  Widget build(BuildContext context) {
    final fraction =
        (elapsed.inMilliseconds / maxDuration.inMilliseconds).clamp(0.0, 1.0);
    final remaining = maxDuration - elapsed;
    final isNearLimit = remaining.inMinutes < 5;

    final colorScheme = Theme.of(context).colorScheme;
    final barColor =
        isNearLimit ? colorScheme.error : colorScheme.primary;
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: isNearLimit ? colorScheme.error : colorScheme.onSurfaceVariant,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: LinearProgressIndicator(
            value: fraction,
            color: barColor,
            backgroundColor: colorScheme.surfaceContainerHighest,
            minHeight: 3,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Preostalo: ${_formatRemaining(remaining)}',
          style: muted,
        ),
      ],
    );
  }

  static String _formatRemaining(Duration d) {
    if (d.isNegative) return '00:00';
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

/// The de-emphasized live prediction line.
class _Ticker extends StatelessWidget {
  const _Ticker({required this.latest, required this.style});

  final ActivityPrediction? latest;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final prediction = latest;
    if (prediction == null) {
      return Text('Trenutno: —', style: style);
    }
    if (prediction.wasSmoothed) {
      return Text(
        'Trenutno: ${activityLabelHr(prediction.label)} '
        '(ugladeno iz: ${activityLabelHr(prediction.rawLabel)})',
        style: style,
      );
    }
    final topProbability = prediction.probabilities.reduce(
      (a, b) => a > b ? a : b,
    );
    return Text(
      'Trenutno: ${activityLabelHr(prediction.label)} '
      '(${(topProbability * 100).round()} %)',
      style: style,
    );
  }
}
