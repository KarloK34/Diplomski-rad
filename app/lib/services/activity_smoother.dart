import 'dart:collection';
import 'dart:math';

import 'package:gait_sense/models/activity_prediction.dart';

/// Causal temporal smoothing for per-window HAR predictions.
///
/// A short rolling majority suppresses isolated label spikes while preserving
/// the original model output in [ActivityPrediction.rawLabel]. Wearable-HAR
/// surveys describe activities as temporally structured sequences rather than
/// independent windows, which is the rationale for this post-processing step
/// (Lara & Labrador, 2013, https://doi.org/10.1109/SURV.2012.110112.00192).
class ActivitySmoother {
  /// Creates a smoother. The default `5 / 3` rule means a full rolling context
  /// needs at least three agreeing labels; shorter startup contexts use a
  /// strict local majority so smoothing is not delayed until the fifth window.
  ActivitySmoother({
    this.windowSize = 5,
    this.minVotes = 3,
  }) : assert(windowSize > 0, 'windowSize must be positive'),
       assert(minVotes > 0, 'minVotes must be positive'),
       assert(minVotes <= windowSize, 'minVotes cannot exceed windowSize');

  /// Number of recent raw predictions kept in the rolling context.
  final int windowSize;

  /// Vote threshold once the rolling context is full.
  final int minVotes;

  final Queue<String> _rawLabels = ListQueue<String>();

  /// Clears the rolling context for a fresh recording session.
  void reset() => _rawLabels.clear();

  /// Adds one raw prediction and returns the same prediction with a smoothed
  /// effective [ActivityPrediction.label].
  ActivityPrediction add(ActivityPrediction prediction) {
    _rawLabels.addLast(prediction.rawLabel);
    while (_rawLabels.length > windowSize) {
      _rawLabels.removeFirst();
    }

    final label = _majorityLabel(fallback: prediction.rawLabel);
    return prediction.copyWith(label: label);
  }

  String _majorityLabel({required String fallback}) {
    final counts = <String, int>{};
    for (final label in _rawLabels) {
      counts[label] = (counts[label] ?? 0) + 1;
    }

    var bestLabel = fallback;
    var bestVotes = 0;
    var tied = false;
    for (final entry in counts.entries) {
      if (entry.value > bestVotes) {
        bestLabel = entry.key;
        bestVotes = entry.value;
        tied = false;
      } else if (entry.value == bestVotes) {
        tied = true;
      }
    }

    final requiredVotes = min(minVotes, _rawLabels.length ~/ 2 + 1);
    if (!tied && bestVotes >= requiredVotes) return bestLabel;
    return fallback;
  }
}
