import 'package:flutter/foundation.dart';

/// Plain-language explanation for one displayed metric, shown via
/// `showMetricInfoSheet`.
@immutable
class MetricInfo {
  /// Creates the explanation for a metric titled [title].
  const MetricInfo({required this.title, required this.description});

  /// Metric name, matches its on-screen label.
  final String title;

  /// Plain-language explanation of what the metric means.
  final String description;
}
