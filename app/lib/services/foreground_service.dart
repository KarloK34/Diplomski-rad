import 'dart:async';
import 'dart:convert';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:gait_sense/models/feature_window.dart';
import 'package:gait_sense/models/sensor_sample.dart';
import 'package:gait_sense/services/activity_smoother.dart';
import 'package:gait_sense/services/feature_pipeline.dart';
import 'package:gait_sense/services/har_inference.dart';
import 'package:gait_sense/services/sensor_service.dart';
import 'package:gait_sense/services/session_limit.dart';

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

  /// [eventKey] value for a raw IMU sample payload.
  static const String sampleEvent = 'sample';

  /// [eventKey] value sent main -> task (via
  /// [FlutterForegroundTask.sendDataToTask]) once the session commits to
  /// recording, so the notification stops reflecting the sensor-readiness
  /// probe that already ran during the countdown.
  static const String recordingCommittedEvent = 'recording_committed';
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
  final ActivitySmoother _smoother = ActivitySmoother();
  HarInference? _inference;
  StreamSubscription<SensorSample>? _sampleSubscription;

  // HarInference owns a single IsolateInterpreter; concurrent predict() calls
  // would race on it. Window arrivals are serialized through this future chain
  // (mirrors PredictionBloc's sequential transformer).
  Future<void> _inferenceChain = Future<void>.value();

  Timer? _limitTimer;
  bool _limitStopRequested = false;
  int _predictionCount = 0;
  String _lastLabel = '—';

  // Null while only the sensor-readiness probe is running (pre-recording
  // countdown); set once the main isolate confirms the session committed to
  // recording. Gates prediction/elapsed data out of the notification until
  // then — see [ForegroundMessage.recordingCommittedEvent].
  DateTime? _recordingStartedAt;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _limitStopRequested = false;
    _predictionCount = 0;
    _lastLabel = '—';
    _recordingStartedAt = null;
    _limitTimer?.cancel();
    _limitTimer = null;
    // Loading the model here verifies tflite_flutter initialises in the service
    // isolate; sensors_plus likewise streams from this isolate.
    _inference = await HarInference.load();
    _extractor.reset();
    _smoother.reset();
    _sensorService.start();
    _sampleSubscription = _sensorService.samples.listen(_onSample);
  }

  void _onSample(SensorSample sample) {
    if (_stopIfLimitReached(sample.timestamp) ||
        _stopIfLimitReached(DateTime.now())) {
      return;
    }

    FlutterForegroundTask.sendDataToMain(
      jsonEncode({
        ForegroundMessage.eventKey: ForegroundMessage.sampleEvent,
        ForegroundMessage.dataKey: sample.toJson(),
      }),
    );

    final window = _extractor.add(sample);
    if (window == null) return;
    _inferenceChain = _inferenceChain
        .then((_) => _classify(window))
        // A single failed window must not poison the chain or kill the service.
        .catchError((Object _, StackTrace _) {});
  }

  Future<void> _classify(FeatureWindow window) async {
    if (_limitStopRequested ||
        _isAtLimit(window.endTimestamp) ||
        _isAtLimit(DateTime.now())) {
      return;
    }

    final inference = _inference;
    if (inference == null) return;
    final rawPrediction = await inference.predict(window);
    if (_limitStopRequested || _isAtLimit(DateTime.now())) return;

    final prediction = _smoother.add(rawPrediction);
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
  void onReceiveData(Object data) {
    if (data is! String) return;
    final decoded = jsonDecode(data) as Map<String, dynamic>;
    if (decoded[ForegroundMessage.eventKey] !=
        ForegroundMessage.recordingCommittedEvent) {
      return;
    }
    // Predictions made during the probe phase belong to readiness-checking,
    // not the session — start the notification's counters fresh.
    _recordingStartedAt = DateTime.now();
    _predictionCount = 0;
    _lastLabel = '—';
    // The limit clock must start here, not in onStart: onStart fires at
    // Start-press, ~preparationDuration before the bloc's own clock starts
    // at commit. Arming both timers from the same commit event keeps the
    // service and the bloc from disagreeing about when the session ends.
    _limitTimer?.cancel();
    _limitTimer = Timer(
      defaultMaxSessionDuration,
      () => unawaited(_stopBecauseLimit()),
    );
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    if (_stopIfLimitReached(timestamp)) return;

    // Periodic refresh of the notification only — the data pipeline is driven
    // by the sensor stream, not by this callback.
    final recordingStartedAt = _recordingStartedAt;
    if (recordingStartedAt == null) {
      // Still probing sensor readiness during the pre-recording countdown;
      // nothing about the eventual session exists yet worth surfacing.
      unawaited(
        FlutterForegroundTask.updateService(
          notificationTitle: 'Priprema snimanja',
          notificationText: 'Provjera senzora…',
        ),
      );
      return;
    }

    final elapsed = timestamp.difference(recordingStartedAt);
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
    _limitStopRequested = true;
    _limitTimer?.cancel();
    _limitTimer = null;
    await _sampleSubscription?.cancel();
    _sampleSubscription = null;
    await _sensorService.dispose();
    await _inference?.close();
    _inference = null;
  }

  bool _stopIfLimitReached(DateTime timestamp) {
    if (!_isAtLimit(timestamp)) return false;
    unawaited(_stopBecauseLimit());
    return true;
  }

  bool _isAtLimit(DateTime timestamp) {
    // No commit yet means still probing sensor readiness during the bounded
    // pre-recording countdown — never at limit there.
    final recordingStartedAt = _recordingStartedAt;
    if (recordingStartedAt == null) return false;
    return hasReachedSessionLimit(
      startedAt: recordingStartedAt,
      now: timestamp,
    );
  }

  Future<void> _stopBecauseLimit() async {
    if (_limitStopRequested) return;
    _limitStopRequested = true;
    _limitTimer?.cancel();
    _limitTimer = null;

    await _sampleSubscription?.cancel();
    _sampleSubscription = null;
    await _sensorService.stop();
    _extractor.reset();
    _smoother.reset();

    await FlutterForegroundTask.stopService();
  }
}

String _formatElapsed(Duration d) {
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
