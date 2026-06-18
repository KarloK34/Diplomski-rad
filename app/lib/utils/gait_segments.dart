import 'package:gait_sense/models/feature_window.dart';
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
/// This helper prepares candidate intervals only; cadence, step detection, and
/// stride-like metrics are intentionally left to later signal processing over
/// the persisted raw samples. The acceleration-signal premise follows Zijlstra
/// & Hof, "Assessment of spatio-temporal gait parameters from trunk
/// accelerations during human walking", Gait & Posture, 2003,
/// https://doi.org/10.1016/S0966-6362(02)00190-X; this app-level candidate gate
/// is not a clinically validated gait segmentation rule.
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
    final displayTimeRange = predictionDisplayTimeRange(
      session,
      startIndex: runStart,
      endIndexExclusive: endIndexExclusive,
      fallbackStepDuration: fallbackStepDuration,
    );
    final analysisTimeRange = predictionAnalysisTimeRange(
      session,
      startIndex: runStart,
      endIndexExclusive: endIndexExclusive,
      fallbackStepDuration: fallbackStepDuration,
    );
    final analysisSampleRange = _predictionAnalysisSampleRange(
      session,
      startIndex: runStart,
      endIndexExclusive: endIndexExclusive,
    );
    final isSuitable = windows >= minWindows;

    segments.add(
      GaitSegment(
        startIndex: runStart,
        endIndexExclusive: endIndexExclusive,
        windows: windows,
        displayStartOffset: displayTimeRange.startOffset,
        displayEndOffset: displayTimeRange.endOffset,
        analysisStartOffset: analysisTimeRange.startOffset,
        analysisEndOffset: analysisTimeRange.endOffset,
        analysisStartSampleIndex: analysisSampleRange?.startIndex,
        analysisEndSampleIndexExclusive: analysisSampleRange?.endIndexExclusive,
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

_SampleRange? _predictionAnalysisSampleRange(
  SessionLog session, {
  required int startIndex,
  required int endIndexExclusive,
}) {
  if (startIndex == endIndexExclusive) return null;

  final firstEnd = session.predictions[startIndex].endSampleIndex;
  final lastEnd = session.predictions[endIndexExclusive - 1].endSampleIndex;
  if (firstEnd == null || lastEnd == null) return null;

  final start = firstEnd - FeatureWindow.windowSize + 1;
  final endExclusive = lastEnd + 1;
  if (start < 0 || endExclusive <= start) return null;

  return _SampleRange(
    startIndex: start,
    endIndexExclusive: endExclusive,
  );
}

class _SampleRange {
  const _SampleRange({
    required this.startIndex,
    required this.endIndexExclusive,
  });

  final int startIndex;
  final int endIndexExclusive;
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
