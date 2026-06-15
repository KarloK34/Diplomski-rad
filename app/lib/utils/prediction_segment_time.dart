import 'package:equatable/equatable.dart';
import 'package:gait_sense/models/session_log.dart';

/// Current live HAR prediction cadence used only when timestamps cannot define
/// the open end of the last segment. The value comes from the app extractor's
/// default step: 64 samples at 50 Hz; the MotionSense sampling context is
/// documented by Malekzadeh et al., "Mobile Sensor Data Anonymization",
/// IoTDI 2019, https://doi.org/10.1145/3302505.3310068. This is an app
/// fallback, not a clinical parameter.
const Duration defaultPredictionStepDuration = Duration(milliseconds: 1280);

/// Time bounds for a consecutive run of prediction indices.
class PredictionSegmentTimeRange extends Equatable {
  /// Creates a time range for a prediction segment.
  const PredictionSegmentTimeRange({
    required this.startOffset,
    required this.endOffset,
  });

  /// Offset from session start where the segment begins.
  final Duration startOffset;

  /// Offset from session start where the segment ends.
  final Duration endOffset;

  /// Non-negative segment duration.
  Duration get duration {
    final span = endOffset - startOffset;
    return span.isNegative ? Duration.zero : span;
  }

  @override
  List<Object?> get props => [startOffset, endOffset];
}

/// Estimates display bounds for a run of predictions.
///
/// The app treats prediction timestamps as the boundary where a label becomes
/// visible in the summary timeline. Interior segment ends therefore use the
/// next prediction timestamp. For the last segment there is no next timestamp,
/// so the helper uses the last observed positive prediction interval, falling
/// back to [fallbackStepDuration] only when the log has no usable interval.
/// This is an application timing heuristic, not a clinically validated gait
/// segmentation rule.
PredictionSegmentTimeRange predictionSegmentTimeRange(
  SessionLog session, {
  required int startIndex,
  required int endIndexExclusive,
  Duration fallbackStepDuration = defaultPredictionStepDuration,
}) {
  assert(startIndex >= 0, 'startIndex must be non-negative');
  assert(
    endIndexExclusive >= startIndex,
    'endIndexExclusive must be after startIndex',
  );
  assert(
    endIndexExclusive <= session.predictions.length,
    'endIndexExclusive must fit inside the prediction list',
  );
  assert(
    fallbackStepDuration > Duration.zero,
    'fallbackStepDuration must be positive',
  );

  if (startIndex == endIndexExclusive || session.predictions.isEmpty) {
    return const PredictionSegmentTimeRange(
      startOffset: Duration.zero,
      endOffset: Duration.zero,
    );
  }

  final startOffset = startIndex == 0
      ? Duration.zero
      : _offsetAt(session, startIndex);
  var endOffset = endIndexExclusive < session.predictions.length
      ? _offsetAt(session, endIndexExclusive)
      : _tailEndOffset(
          session,
          lastPredictionIndex: endIndexExclusive - 1,
          fallbackStepDuration: fallbackStepDuration,
        );

  if (endOffset < startOffset) endOffset = startOffset;
  return PredictionSegmentTimeRange(
    startOffset: startOffset,
    endOffset: endOffset,
  );
}

Duration _offsetAt(SessionLog session, int index) {
  final span = session.predictions[index].timestamp.difference(
    session.startedAt,
  );
  return span.isNegative ? Duration.zero : span;
}

Duration _tailEndOffset(
  SessionLog session, {
  required int lastPredictionIndex,
  required Duration fallbackStepDuration,
}) {
  final lastOffset = _offsetAt(session, lastPredictionIndex);
  final inferredStep = _lastObservedPositiveStep(
    session,
    beforeOrAtIndex: lastPredictionIndex,
  );
  final estimatedEnd = lastOffset + (inferredStep ?? fallbackStepDuration);

  final stoppedAt = session.stoppedAt;
  if (stoppedAt == null) return estimatedEnd;

  final stoppedOffset = stoppedAt.difference(session.startedAt);
  if (stoppedOffset.isNegative || stoppedOffset < lastOffset) {
    return estimatedEnd;
  }
  return stoppedOffset < estimatedEnd ? stoppedOffset : estimatedEnd;
}

Duration? _lastObservedPositiveStep(
  SessionLog session, {
  required int beforeOrAtIndex,
}) {
  for (var i = beforeOrAtIndex; i > 0; i--) {
    final step = session.predictions[i].timestamp.difference(
      session.predictions[i - 1].timestamp,
    );
    if (step > Duration.zero) return step;
  }
  return null;
}
