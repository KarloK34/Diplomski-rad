import 'package:equatable/equatable.dart';

/// One classifier output for a single feature window.
///
/// [probabilities] is the raw softmax vector in the model's class order
/// (`cnn_final.preproc.json.class_labels`); [label] is the argmax class.
/// [inferenceLatencyMs] is the measured wall-clock time of the interpreter
/// call that produced this prediction, used for the on-device latency budget.
class ActivityPrediction extends Equatable {
  /// Creates a prediction.
  const ActivityPrediction({
    required this.label,
    required this.probabilities,
    required this.timestamp,
    required this.inferenceLatencyMs,
  });

  /// Rebuilds a prediction from its [toJson] map. Also the decoder for the
  /// payload shipped across the foreground-service isolate boundary, since
  /// `sendDataToMain` only transports JSON-able values.
  factory ActivityPrediction.fromJson(Map<String, dynamic> json) {
    return ActivityPrediction(
      label: json['label'] as String,
      probabilities: (json['probabilities'] as List)
          .map((v) => (v as num).toDouble())
          .toList(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      inferenceLatencyMs: (json['inferenceLatencyMs'] as num).toInt(),
    );
  }

  /// Argmax class label (e.g. `wlk`, `sit`).
  final String label;

  /// Softmax probability per class, in model class order (length == classes).
  final List<double> probabilities;

  /// Wall-clock time of the last sample in the source window.
  final DateTime timestamp;

  /// Measured interpreter latency for this window, in milliseconds.
  final int inferenceLatencyMs;

  /// Serializes to a JSON-able map. [timestamp] uses ISO-8601 so it survives
  /// a round-trip through both the session-log file and the isolate port.
  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'probabilities': probabilities,
      'timestamp': timestamp.toIso8601String(),
      'inferenceLatencyMs': inferenceLatencyMs,
    };
  }

  @override
  List<Object?> get props => [
    label,
    probabilities,
    timestamp,
    inferenceLatencyMs,
  ];
}
