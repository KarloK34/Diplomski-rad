import 'package:flutter/material.dart';
import 'package:gait_sense/models/activity_prediction.dart';
import 'package:gait_sense/utils/activity_labels.dart';

/// De-emphasized live line showing the [latest] per-window prediction.
///
/// Single-window predictions are noisy, so this is intentionally muted —
/// the session totals on the summary screen are the headline result.
class PredictionTicker extends StatelessWidget {
  /// Creates the ticker for [latest], styled with [style].
  const PredictionTicker({
    required this.latest,
    required this.style,
    super.key,
  });

  /// Latest prediction, or null before the first arrives.
  final ActivityPrediction? latest;

  /// Text style applied to the rendered line.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final prediction = latest;
    if (prediction == null) {
      return Text('Trenutno: —', style: style);
    }
    if (prediction.wasSmoothed) {
      return Text(
        'Trenutno: ${activityLabelHr(prediction.label)} '
        '(ugladeno iz: ${activityLabelHr(prediction.rawLabel)})',
        style: style,
      );
    }
    final topProbability = prediction.probabilities.reduce(
      (a, b) => a > b ? a : b,
    );
    return Text(
      'Trenutno: ${activityLabelHr(prediction.label)} '
      '(${(topProbability * 100).round()} %)',
      style: style,
    );
  }
}
