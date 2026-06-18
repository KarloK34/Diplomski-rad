import 'package:gait_sense/models/activity_prediction.dart';
import 'package:gait_sense/models/sensor_sample.dart';

/// UI-isolate-facing contract for the background recording service.
///
/// Extracted as an interface so the recording bloc can be unit-tested on the
/// host VM. The concrete `GaitForegroundService` calls static methods on
/// `flutter_foreground_task` that resolve through platform channels absent in
/// `flutter test`; a fake implementing this interface needs no platform at all.
abstract interface class RecordingController {
  /// Predictions emitted by the service isolate, decoded on the UI isolate.
  Stream<ActivityPrediction> get predictions;

  /// Raw IMU samples emitted by the service isolate.
  Stream<SensorSample> get samples;

  /// Requests the runtime permissions required before [start].
  Future<void> requestPermissions();

  /// Starts (or restarts) the recording service.
  Future<void> start();

  /// Stops the recording service.
  Future<void> stop();
}
