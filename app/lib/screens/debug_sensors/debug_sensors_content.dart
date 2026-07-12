import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/sensor_stream/sensor_stream_bloc.dart';
import 'package:gait_sense/blocs/sensor_stream/sensor_stream_event.dart';
import 'package:gait_sense/blocs/sensor_stream/sensor_stream_state.dart';
import 'package:gait_sense/widgets/widgets.dart';

/// Renders [SensorStreamBloc]'s state: the metrics header, channel
/// statistics table, and Start/Stop control.
class DebugSensorsContent extends StatelessWidget {
  /// Creates the debug sensors content.
  const DebugSensorsContent({super.key});

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
                SensorMetricsHeader(
                  isRunning: state.isRunning,
                  measuredHertz: state.measuredHertz,
                  sampleCount: state.sampleCount,
                ),
                const Divider(height: 24),
                Expanded(
                  child: state.statistics.isEmpty
                      ? const Center(child: Text('Nema uzoraka.'))
                      : ChannelStatisticsTable(statistics: state.statistics),
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
