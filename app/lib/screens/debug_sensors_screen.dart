import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/sensor_stream/sensor_stream_bloc.dart';
import 'package:gait_sense/blocs/sensor_stream/sensor_stream_event.dart';
import 'package:gait_sense/blocs/sensor_stream/sensor_stream_state.dart';
import 'package:gait_sense/models/channel_statistics.dart';
import 'package:gait_sense/theme/theme_context.dart';

/// Live readout of the resampled IMU channels. Shows the measured sampling
/// rate plus per-channel mean/std accumulated since Start, so a walking test
/// (phone in pocket) can be read off the screen afterwards.
class DebugSensorsScreen extends StatelessWidget {
  /// Creates the debug screen.
  const DebugSensorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Debug senzori')),
      body: BlocBuilder<SensorStreamBloc, SensorStreamState>(
        builder: (context, state) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MetricsHeader(state: state),
                const Divider(height: 24),
                Expanded(
                  child: state.statistics.isEmpty
                      ? const Center(child: Text('Nema uzoraka.'))
                      : _StatisticsTable(statistics: state.statistics),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: BlocBuilder<SensorStreamBloc, SensorStreamState>(
        builder: (context, state) {
          return FloatingActionButton.extended(
            onPressed: () => context.read<SensorStreamBloc>().add(
              state.isRunning
                  ? const SensorStreamStopped()
                  : const SensorStreamStarted(),
            ),
            icon: Icon(state.isRunning ? Icons.stop : Icons.play_arrow),
            label: Text(state.isRunning ? 'Stop' : 'Start'),
          );
        },
      ),
    );
  }
}

class _MetricsHeader extends StatelessWidget {
  const _MetricsHeader({required this.state});

  final SensorStreamState state;

  @override
  Widget build(BuildContext context) {
    final hertzInRange = state.measuredHertz >= 48 && state.measuredHertz <= 52;
    final appTextStyles = context.appTextStyles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status: ${state.isRunning ? "aktivno" : "zaustavljeno"}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Rate: ${state.measuredHertz.toStringAsFixed(1)} Hz'
          '${state.isRunning ? (hertzInRange ? "  ✓" : "  ⚠") : ""}',
          style: state.isRunning && !hertzInRange
              ? appTextStyles.warning
              : null,
        ),
        Text('Uzoraka: ${state.sampleCount}'),
        const SizedBox(height: 4),
        Text(
          'μ / σ akumulirano od Start-a',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _StatisticsTable extends StatelessWidget {
  const _StatisticsTable({required this.statistics});

  final Map<String, ChannelStatistics> statistics;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const _StatisticsRow(
          channel: 'kanal',
          mean: 'μ',
          standardDeviation: 'σ',
          isHeader: true,
        ),
        const Divider(),
        for (final channel in sensorStatisticsChannels) ...[
          _StatisticsRow(
            channel: channel,
            mean: (statistics[channel]?.mean ?? 0).toStringAsFixed(4),
            standardDeviation: (statistics[channel]?.standardDeviation ?? 0)
                .toStringAsFixed(4),
            highlight:
                channel.startsWith('userAcceleration') ||
                channel == '‖gravity‖',
          ),
          if (channel == '‖gravity‖') const Divider(),
          if (channel == 'userAcceleration.z') const Divider(),
        ],
      ],
    );
  }
}

class _StatisticsRow extends StatelessWidget {
  const _StatisticsRow({
    required this.channel,
    required this.mean,
    required this.standardDeviation,
    this.highlight = false,
    this.isHeader = false,
  });

  final String channel;
  final String mean;
  final String standardDeviation;
  final bool highlight;
  final bool isHeader;

  @override
  Widget build(BuildContext context) {
    final appTextStyles = context.appTextStyles;
    final numericStyle = highlight || isHeader
        ? appTextStyles.monospaceDataBold
        : appTextStyles.monospaceData;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              channel,
              style: isHeader ? appTextStyles.tableHeader : null,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(mean, textAlign: TextAlign.right, style: numericStyle),
          ),
          Expanded(
            flex: 2,
            child: Text(
              standardDeviation,
              textAlign: TextAlign.right,
              style: numericStyle,
            ),
          ),
        ],
      ),
    );
  }
}
