import 'dart:async';

import 'package:gait_sense/models/sensor_sample.dart';
import 'package:gait_sense/services/recording_controller.dart';

/// Confirms a [RecordingController] is actually delivering samples before a
/// session commits to recording.
///
/// `RecordingController.start()` succeeds even when no sample ever arrives —
/// a device with no working sensor, or an iOS Core Motion permission denial,
/// simply stays silent. Watching for a first sample during the pre-recording
/// countdown is the only way to surface that failure.
class SensorReadinessProbe {
  /// Creates a probe over [_controller].
  SensorReadinessProbe(this._controller);

  final RecordingController _controller;
  StreamSubscription<SensorSample>? _subscription;
  bool _isReady = false;

  /// Whether a sample has arrived since the last [arm] call.
  bool get isReady => _isReady;

  /// Requests permissions, starts the controller, and begins watching for a
  /// first sample.
  Future<void> arm() async {
    await _controller.requestPermissions();
    _isReady = false;
    await _subscription?.cancel();
    _subscription = _controller.samples.listen((_) => _isReady = true);
    await _controller.start();
  }

  /// Stops watching. Does not stop the controller itself — callers decide
  /// separately whether the session commits or the controller is torn down.
  Future<void> disarm() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
