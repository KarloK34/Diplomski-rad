import 'package:equatable/equatable.dart';
import 'package:gait_sense/models/activity_prediction.dart';
import 'package:gait_sense/models/sensor_sample.dart';

/// A full recording session: its time bounds, the model metadata it was
/// produced with, raw IMU samples, and per-window predictions.
///
/// Raw samples are persisted because later gait-parameter extraction needs a
/// timestamped acceleration signal, as in Zijlstra & Hof, "Assessment of
/// spatio-temporal gait parameters from trunk accelerations during human
/// walking", Gait & Posture, 2003,
/// https://doi.org/10.1016/S0966-6362(02)00190-X. The app still treats the
/// later gait metrics as project outputs until they are separately validated.
/// [modelInfo] carries a subset of `cnn_final.preproc.json` (channel order and
/// class labels) so an exported file is self-describing without the app bundle.
class SessionLog extends Equatable {
  /// Creates a session log.
  const SessionLog({
    required this.startedAt,
    required this.stoppedAt,
    required this.modelInfo,
    required this.predictions,
    this.deviceId,
    this.rawSamples = const [],
  });

  /// Rebuilds a session from its [toJson] map.
  factory SessionLog.fromJson(Map<String, dynamic> json) {
    final rawSamplesJson = json['rawSamples'] as List? ?? const [];
    return SessionLog(
      startedAt: DateTime.parse(json['startedAt'] as String),
      stoppedAt: json['stoppedAt'] == null
          ? null
          : DateTime.parse(json['stoppedAt'] as String),
      deviceId: json['deviceId'] as String?,
      modelInfo: Map<String, dynamic>.from(json['modelInfo'] as Map),
      rawSamples: rawSamplesJson
          .map((s) => SensorSample.fromJson(s as Map<String, dynamic>))
          .toList(),
      predictions: (json['predictions'] as List)
          .map((p) => ActivityPrediction.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Wall-clock time the session started.
  final DateTime startedAt;

  /// Wall-clock time the session stopped, or null while still running.
  final DateTime? stoppedAt;

  /// Optional device identifier (omitted unless a device-info source is wired).
  final String? deviceId;

  /// Channel order and class labels copied from `cnn_final.preproc.json`.
  final Map<String, dynamic> modelInfo;

  /// Timestamped IMU samples recorded during the session.
  final List<SensorSample> rawSamples;

  /// Per-window predictions in chronological order.
  final List<ActivityPrediction> predictions;

  /// Serializes to a JSON-able map.
  Map<String, dynamic> toJson() {
    return {
      'startedAt': startedAt.toIso8601String(),
      'stoppedAt': stoppedAt?.toIso8601String(),
      'deviceId': deviceId,
      'modelInfo': modelInfo,
      'rawSamples': [for (final sample in rawSamples) sample.toJson()],
      'predictions': [for (final p in predictions) p.toJson()],
    };
  }

  @override
  List<Object?> get props => [
    startedAt,
    stoppedAt,
    deviceId,
    modelInfo,
    rawSamples,
    predictions,
  ];
}
