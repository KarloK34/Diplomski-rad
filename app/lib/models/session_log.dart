import 'package:equatable/equatable.dart';
import 'package:gait_sense/models/activity_prediction.dart';

/// A full recording session: its time bounds, the model metadata it was
/// produced with, and the ordered list of per-window predictions.
///
/// Only predictions are persisted — raw IMU samples are never written to disk.
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
  });

  /// Rebuilds a session from its [toJson] map.
  factory SessionLog.fromJson(Map<String, dynamic> json) {
    return SessionLog(
      startedAt: DateTime.parse(json['startedAt'] as String),
      stoppedAt: json['stoppedAt'] == null
          ? null
          : DateTime.parse(json['stoppedAt'] as String),
      deviceId: json['deviceId'] as String?,
      modelInfo: Map<String, dynamic>.from(json['modelInfo'] as Map),
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

  /// Per-window predictions in chronological order.
  final List<ActivityPrediction> predictions;

  /// Serializes to a JSON-able map.
  Map<String, dynamic> toJson() {
    return {
      'startedAt': startedAt.toIso8601String(),
      'stoppedAt': stoppedAt?.toIso8601String(),
      'deviceId': deviceId,
      'modelInfo': modelInfo,
      'predictions': [for (final p in predictions) p.toJson()],
    };
  }

  @override
  List<Object?> get props => [
    startedAt,
    stoppedAt,
    deviceId,
    modelInfo,
    predictions,
  ];
}
