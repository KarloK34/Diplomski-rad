import 'dart:async';
import 'dart:convert';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:gait_sense/models/feature_window.dart';
import 'package:gait_sense/models/sensor_sample.dart';
import 'package:gait_sense/services/feature_pipeline.dart';
import 'package:gait_sense/services/har_inference.dart';
import 'package:gait_sense/services/sensor_service.dart';

/// Entry point of the foreground-service isolate.
///
/// Must be a top-level function annotated `@pragma('vm:entry-point')` so it
/// survives tree-shaking and can be resolved by name from the native side when
/// the service isolate is spawned.
@pragma('vm:entry-point')
void gaitSenseForegroundCallback() {
  FlutterForegroundTask.setTaskHandler(_HarTaskHandler());
}

/// Wire contract for messages crossing the isolate boundary via
/// [FlutterForegroundTask.sendDataToMain].
///
/// Payloads are JSON strings rather than raw maps: the platform message codec
/// guarantees lossless [String] transport, whereas a `Map` arrives on the other
/// side as `Map<Object?, Object?>` and would need re-casting at every access.
class ForegroundMessage {
  /// Key naming the message kind.
  static const String eventKey = 'event';

  /// Key holding the message payload.
  static const String dataKey = 'data';

  /// [eventKey] value for a prediction payload.
  static const String predictionEvent = 'prediction';
}

/// Runs the live recording pipeline inside the foreground-service isolate.
///
/// The UI (main) isolate is paused by Android when the activity is backgrounded
/// or the screen is locked, so the sensor stream, feature pipeline, and TFLite
/// inference all live here instead. Each prediction is forwarded to the UI
/// isolate via [FlutterForegroundTask.sendDataToMain].
class _HarTaskHandler extends TaskHandler {
  final SensorService _sensorService = SensorService();
  final StreamingFeatureExtractor _extractor = StreamingFeatureExtractor();
  HarInference? _inference;
  StreamSubscription<SensorSample>? _sampleSubscription;

  // HarInference owns a single IsolateInterpreter; concurrent predict() calls
  // would race on it. Window arrivals are serialized through this future chain
  // (mirrors PredictionBloc's sequential transformer).
  Future<void> _inferenceChain = Future<void>.value();

  DateTime _startedAt = DateTime.fromMillisecondsSinceEpoch(0);
  int _predictionCount = 0;
  String _lastLabel = '—';

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _startedAt = timestamp;
    _predictionCount = 0;
    _lastLabel = '—';
    // Loading the model here verifies tflite_flutter initialises in the service
    // isolate; sensors_plus likewise streams from this isolate.
    _inference = await HarInference.load();
    _extractor.reset();
    _sensorService.start();
    _sampleSubscription = _sensorService.samples.listen(_onSample);
  }

  void _onSample(SensorSample sample) {
    final window = _extractor.add(sample);
    if (window == null) return;
    _inferenceChain = _inferenceChain
        .then((_) => _classify(window))
        // A single failed window must not poison the chain or kill the service.
        .catchError((Object _, StackTrace _) {});
  }

  Future<void> _classify(FeatureWindow window) async {
    final inference = _inference;
    if (inference == null) return;
    final prediction = await inference.predict(window);
    _predictionCount++;
    _lastLabel = prediction.label;
    FlutterForegroundTask.sendDataToMain(
      jsonEncode({
        ForegroundMessage.eventKey: ForegroundMessage.predictionEvent,
        ForegroundMessage.dataKey: prediction.toJson(),
      }),
    );
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Periodic refresh of the notification only — the data pipeline is driven
    // by the sensor stream, not by this callback.
    final elapsed = timestamp.difference(_startedAt);
    unawaited(
      FlutterForegroundTask.updateService(
        notificationTitle: 'Snimanje aktivnosti u tijeku',
        notificationText:
            'Trajanje ${_formatElapsed(elapsed)} · '
            'predikcija: $_predictionCount · zadnje: $_lastLabel',
      ),
    );
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _sampleSubscription?.cancel();
    _sampleSubscription = null;
    await _sensorService.dispose();
    await _inference?.close();
    _inference = null;
  }
}

String _formatElapsed(Duration d) {
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
