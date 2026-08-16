import 'package:gait_sense/models/activity_prediction.dart';
import 'package:gait_sense/models/sensor_sample.dart';
import 'package:gait_sense/models/session_log.dart';

/// In-memory accumulator for the active recording session's predictions and
/// raw IMU samples.
///
/// Kept separate from `SessionLogRepository` (which composes this) so the
/// active-session bookkeeping is unit-testable without touching disk.
class SessionBuffer {
  DateTime? _startedAt;
  String? _deviceId;
  Map<String, dynamic> _modelInfo = const {};
  final List<ActivityPrediction> _predictions = [];
  final List<SensorSample> _rawSamples = [];

  /// Number of predictions buffered in the active session.
  int get count => _predictions.length;

  /// Number of raw IMU samples buffered in the active session.
  int get sampleCount => _rawSamples.length;

  /// Unmodifiable view of the predictions buffered so far.
  List<ActivityPrediction> get predictions => List.unmodifiable(_predictions);

  /// Unmodifiable view of the raw IMU samples buffered so far.
  List<SensorSample> get rawSamples => List.unmodifiable(_rawSamples);

  /// Begins a new session, clearing any buffered predictions.
  void start({
    required DateTime startedAt,
    required Map<String, dynamic> modelInfo,
    String? deviceId,
  }) {
    _startedAt = startedAt;
    _modelInfo = modelInfo;
    _deviceId = deviceId;
    _predictions.clear();
    _rawSamples.clear();
  }

  /// Appends one prediction to the active session.
  void append(ActivityPrediction prediction) {
    _predictions.add(prediction);
  }

  /// Appends one raw IMU sample to the active session.
  void appendSample(SensorSample sample) {
    _rawSamples.add(sample);
  }

  /// Finalizes the session from the buffered predictions and raw samples and
  /// returns it.
  ///
  /// Throws [StateError] if called before [start].
  SessionLog finish({required DateTime stoppedAt}) {
    final startedAt = _startedAt;
    if (startedAt == null) {
      throw StateError('finish called before start');
    }

    return SessionLog(
      startedAt: startedAt,
      stoppedAt: stoppedAt,
      deviceId: _deviceId,
      modelInfo: _modelInfo,
      rawSamples: List.of(_rawSamples),
      predictions: List.of(_predictions),
    );
  }
}
