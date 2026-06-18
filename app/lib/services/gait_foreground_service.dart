import 'dart:async';
import 'dart:convert';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:gait_sense/models/activity_prediction.dart';
import 'package:gait_sense/models/sensor_sample.dart';
import 'package:gait_sense/services/foreground_service.dart';
import 'package:gait_sense/services/recording_controller.dart';

/// UI-isolate facade over the foreground service.
///
/// Owns the service lifecycle (init / permissions / start / stop) and bridges
/// [FlutterForegroundTask.addTaskDataCallback] into a typed broadcast [Stream]
/// of [ActivityPrediction]s for the UI layer to consume. The recording pipeline
/// itself runs in the service isolate (see `foreground_service.dart`).
///
/// Implements [RecordingController] so the recording bloc can depend on the
/// interface and be exercised on the host VM with a plain fake.
class GaitForegroundService implements RecordingController {
  /// Registers the data callback that receives messages from the task isolate.
  GaitForegroundService() {
    FlutterForegroundTask.addTaskDataCallback(_onData);
  }

  final StreamController<ActivityPrediction> _predictions =
      StreamController<ActivityPrediction>.broadcast();
  final StreamController<SensorSample> _samples =
      StreamController<SensorSample>.broadcast();

  /// Predictions produced by the service isolate, decoded back into objects.
  @override
  Stream<ActivityPrediction> get predictions => _predictions.stream;

  /// Raw IMU samples produced by the service isolate.
  @override
  Stream<SensorSample> get samples => _samples.stream;

  void _onData(Object data) {
    if (data is! String) return;
    final decoded = jsonDecode(data) as Map<String, dynamic>;
    switch (decoded[ForegroundMessage.eventKey]) {
      case ForegroundMessage.predictionEvent:
        _predictions.add(
          ActivityPrediction.fromJson(
            decoded[ForegroundMessage.dataKey] as Map<String, dynamic>,
          ),
        );
      case ForegroundMessage.sampleEvent:
        _samples.add(
          SensorSample.fromJson(
            decoded[ForegroundMessage.dataKey] as Map<String, dynamic>,
          ),
        );
    }
  }

  /// Configures the notification channel and task options. Call once at startup
  /// before [start].
  void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'gait_sense_recording',
        channelName: 'Snimanje aktivnosti',
        channelDescription:
            'Obavijest dok pozadinsko prepoznavanje aktivnosti radi.',
        onlyAlertOnce: true,
      ),
      // showNotification:false keeps iOS quiet; allowWakeLock defaults to true,
      // which is what keeps the CPU alive for inference with the screen off.
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        // Drives only the 1 s notification refresh; sampling is event-driven by
        // the sensor stream inside the handler.
        eventAction: ForegroundTaskEventAction.repeat(1000),
      ),
    );
  }

  /// Requests the runtime permissions the foreground service needs: the
  /// notification permission (Android 13+) and a battery-optimization exemption
  /// for reliable screen-off operation.
  @override
  Future<void> requestPermissions() async {
    final permission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
  }

  /// Starts the recording service, restarting it if already running.
  @override
  Future<ServiceRequestResult> start() async {
    if (await FlutterForegroundTask.isRunningService) {
      return FlutterForegroundTask.restartService();
    }
    return FlutterForegroundTask.startService(
      serviceId: 1001,
      notificationTitle: 'Snimanje aktivnosti u tijeku',
      notificationText: 'Pokretanje…',
      callback: gaitSenseForegroundCallback,
    );
  }

  /// Stops the recording service.
  @override
  Future<ServiceRequestResult> stop() {
    return FlutterForegroundTask.stopService();
  }

  /// Whether the service is currently running.
  Future<bool> get isRunning => FlutterForegroundTask.isRunningService;

  /// Removes the data callback and closes the prediction stream.
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onData);
    unawaited(_predictions.close());
    unawaited(_samples.close());
  }
}
