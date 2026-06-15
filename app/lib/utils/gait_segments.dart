import 'package:gait_sense/models/gait_segment.dart';
import 'package:gait_sense/models/session_log.dart';
import 'package:gait_sense/utils/prediction_segment_time.dart';

/// MotionSense `wlk` code used by the app as level-walking context
/// (Malekzadeh et al., "Mobile Sensor Data Anonymization", IoTDI 2019,
/// https://doi.org/10.1145/3302505.3310068).
const String defaultLevelWalkingLabel = 'wlk';

/// App-level minimum for consecutive `wlk` windows before a segment is exposed
/// as a gait-analysis candidate. This threshold is project-specific and is not
/// clinically validated.
const int defaultGaitCandidateMinWindows = 5;

/// Reason code for a `wlk` run that is shorter than the app-level gate.
const String tooFewLevelWalkingWindowsReason = 'too_few_level_walking_windows';

/// Extracts consecutive level-walking runs from smoothed session predictions.
///
/// The current session log persists only HAR predictions, not raw IMU samples
/// or per-window feature matrices. For that reason this helper prepares
/// candidate intervals only; cadence, step detection, and stride-like metrics
/// need a persisted signal in a later implementation step.
List<GaitSegment> extractGaitSegments(
  SessionLog session, {
  String levelWalkingLabel = defaultLevelWalkingLabel,
  int minWindows = defaultGaitCandidateMinWindows,
  Duration fallbackStepDuration = defaultPredictionStepDuration,
}) {
  assert(minWindows > 0, 'minWindows must be positive');
  assert(
    fallbackStepDuration > Duration.zero,
    'fallbackStepDuration must be positive',
  );

  final predictions = session.predictions;
  final segments = <GaitSegment>[];
  var runStart = -1;

  void finishRun(int endIndexExclusive) {
    if (runStart < 0) return;

    final windows = endIndexExclusive - runStart;
    final timeRange = predictionSegmentTimeRange(
      session,
      startIndex: runStart,
      endIndexExclusive: endIndexExclusive,
      fallbackStepDuration: fallbackStepDuration,
    );
    final isSuitable = windows >= minWindows;

    segments.add(
      GaitSegment(
        startIndex: runStart,
        endIndexExclusive: endIndexExclusive,
        windows: windows,
        startOffset: timeRange.startOffset,
        endOffset: timeRange.endOffset,
        labelCounts: Map.unmodifiable(
          _labelCounts(session, runStart, endIndexExclusive),
        ),
        quality: isSuitable
            ? GaitSegmentQuality.suitable
            : GaitSegmentQuality.tooFewWindows,
        qualityReason: isSuitable ? null : tooFewLevelWalkingWindowsReason,
      ),
    );
    runStart = -1;
  }

  for (var i = 0; i < predictions.length; i++) {
    if (predictions[i].label == levelWalkingLabel) {
      if (runStart < 0) runStart = i;
    } else {
      finishRun(i);
    }
  }
  finishRun(predictions.length);

  return List.unmodifiable(segments);
}

Map<String, int> _labelCounts(
  SessionLog session,
  int startIndex,
  int endIndexExclusive,
) {
  final counts = <String, int>{};
  for (var i = startIndex; i < endIndexExclusive; i++) {
    final label = session.predictions[i].label;
    counts[label] = (counts[label] ?? 0) + 1;
  }
  return counts;
}
