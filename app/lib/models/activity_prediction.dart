import 'package:equatable/equatable.dart';

/// One classifier output for a single feature window.
///
/// [probabilities] is the raw softmax vector in the model's class order
/// (`cnn_final.preproc.json.class_labels`); [rawLabel] is the model argmax.
/// [label] is the effective label used by the app after optional temporal
/// smoothing.
/// [inferenceLatencyMs] is the measured wall-clock time of the interpreter
/// call that produced this prediction, used for the on-device latency budget.
class ActivityPrediction extends Equatable {
  /// Creates a prediction.
  const ActivityPrediction({
    required this.label,
    required this.probabilities,
    required this.timestamp,
    required this.inferenceLatencyMs,
    this.endSampleIndex,
    String? rawLabel,
  }) : rawLabel = rawLabel ?? label;

  /// Rebuilds a prediction from its [toJson] map. Also the decoder for the
  /// payload shipped across the foreground-service isolate boundary, since
  /// `sendDataToMain` only transports JSON-able values.
  factory ActivityPrediction.fromJson(Map<String, dynamic> json) {
    return ActivityPrediction(
      label: json['label'] as String,
      rawLabel: json['rawLabel'] as String?,
      probabilities: (json['probabilities'] as List)
          .map((v) => (v as num).toDouble())
          .toList(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      inferenceLatencyMs: (json['inferenceLatencyMs'] as num).toInt(),
      endSampleIndex: (json['endSampleIndex'] as num?)?.toInt(),
    );
  }

  /// Effective class label used by the app (e.g. `wlk`, `sit`).
  final String label;

  /// Raw model argmax before temporal smoothing.
  final String rawLabel;

  /// Softmax probability per class, in model class order (length == classes).
  final List<double> probabilities;

  /// Wall-clock time of the last sample in the source window.
  final DateTime timestamp;

  /// Index of the last raw sample in the source window.
  ///
  /// Null means the prediction came from an older session log that did not
  /// persist sample indices.
  final int? endSampleIndex;

  /// Measured interpreter latency for this window, in milliseconds.
  final int inferenceLatencyMs;

  /// Whether temporal smoothing changed the model argmax.
  bool get wasSmoothed => rawLabel != label;

  /// Returns a copy with the given fields replaced.
  ActivityPrediction copyWith({
    String? label,
    String? rawLabel,
    List<double>? probabilities,
    DateTime? timestamp,
    int? endSampleIndex,
    int? inferenceLatencyMs,
  }) {
    return ActivityPrediction(
      label: label ?? this.label,
      rawLabel: rawLabel ?? this.rawLabel,
      probabilities: probabilities ?? this.probabilities,
      timestamp: timestamp ?? this.timestamp,
      endSampleIndex: endSampleIndex ?? this.endSampleIndex,
      inferenceLatencyMs: inferenceLatencyMs ?? this.inferenceLatencyMs,
    );
  }

  /// Serializes to a JSON-able map. [timestamp] uses ISO-8601 so it survives
  /// a round-trip through both the session-log file and the isolate port.
  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'rawLabel': rawLabel,
      'probabilities': probabilities,
      'timestamp': timestamp.toIso8601String(),
      'endSampleIndex': endSampleIndex,
      'inferenceLatencyMs': inferenceLatencyMs,
    };
  }

  @override
  List<Object?> get props => [
    label,
    rawLabel,
    probabilities,
    timestamp,
    endSampleIndex,
    inferenceLatencyMs,
  ];
}
