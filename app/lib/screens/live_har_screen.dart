import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/sensor_stream/sensor_stream_bloc.dart';
import 'package:gait_sense/models/activity_prediction.dart';
import 'package:gait_sense/screens/debug_sensors_screen.dart';
import 'package:gait_sense/services/gait_foreground_service.dart';
import 'package:gait_sense/services/sensor_service.dart';

/// The recording screen: one Start/Stop control over the background service.
///
/// This is the minimal surface that drives [GaitForegroundService] and shows
/// that predictions flow from the service isolate to the UI isolate. The
/// session log, elapsed timer, rolling latency stats, and summary navigation
/// are layered on top of this once the BLoC wiring lands.
class LiveHarScreen extends StatefulWidget {
  /// Creates the live screen.
  const LiveHarScreen({super.key});

  @override
  State<LiveHarScreen> createState() => _LiveHarScreenState();
}

class _LiveHarScreenState extends State<LiveHarScreen> {
  final GaitForegroundService _service = GaitForegroundService();
  StreamSubscription<ActivityPrediction>? _subscription;

  ActivityPrediction? _latest;
  int _count = 0;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _service.init();
    _subscription = _service.predictions.listen((prediction) {
      setState(() {
        _latest = prediction;
        _count++;
      });
    });
  }

  Future<void> _toggle() async {
    if (_running) {
      await _service.stop();
      if (mounted) setState(() => _running = false);
      return;
    }
    await _service.requestPermissions();
    await _service.start();
    if (mounted) {
      setState(() {
        _running = true;
        _count = 0;
        _latest = null;
      });
    }
  }

  void _openDebugScreen() {
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

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final latest = _latest;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live HAR'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sensors),
            tooltip: 'Debug senzori',
            onPressed: _openDebugScreen,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _running ? 'Snimanje u tijeku' : 'Zaustavljeno',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Text('Predikcija: $_count'),
            const SizedBox(height: 8),
            if (latest != null)
              Text(
                'Zadnje: ${latest.label} '
                '(p=${_topProbability(latest).toStringAsFixed(2)}, '
                '${latest.inferenceLatencyMs} ms)',
              )
            else
              const Text('Zadnje: —'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => unawaited(_toggle()),
        icon: Icon(_running ? Icons.stop : Icons.play_arrow),
        label: Text(_running ? 'Stop' : 'Start'),
      ),
    );
  }

  static double _topProbability(ActivityPrediction prediction) {
    return prediction.probabilities.reduce((a, b) => a > b ? a : b);
  }
}
