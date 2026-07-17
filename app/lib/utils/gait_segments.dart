import 'package:gait_sense/models/feature_window.dart';
import 'package:gait_sense/models/gait_segment.dart';
import 'package:gait_sense/models/session_log.dart';
import 'package:gait_sense/utils/prediction_segment_time.dart';

/// MotionSense `wlk` code used by the app as level-walking context
/// (Malekzadeh et al., "Mobile Sensor Data Anonymization", IoTDI 2019,
/// https://doi.org/10.1145/3302505.3310068).
const String defaultLevelWalkingLabel = 'wlk';

/// Effective labels that count as ambulatory locomotion in the MotionSense
/// label set: walking, upstairs, downstairs, and jogging (Malekzadeh et al.,
/// 2019, https://doi.org/10.1145/3302505.3310068).
///
/// Deliberately broader than [defaultLevelWalkingLabel]: step *counting*
/// (cadence, peak detection on acceleration/gyroscope magnitude) does not
/// depend on the level-gait, single-support assumption the inverted-pendulum
/// step-length/speed model does (see `gait_walking_speed.dart`) — a footfall
/// still produces a detectable acceleration peak on stairs or while jogging,
/// so those runs contribute to the step count even though neither ever feeds
/// walking-speed. Jogging is the more clear-cut exclusion there: it has an
/// aerial/flight phase where both feet leave the ground, which the
/// inverted-pendulum model's single-support geometry cannot represent at all
/// (unlike stairs, which at least keeps single-limb support). This inclusion
/// list is an application-policy choice by analogy to the stair case, not a
/// literature-validated claim that step counting is equally accurate for
/// jogging. Used both for the "stable locomotion" quality metric and for
/// cadence's broader gait-segment extraction in `computeSessionQualitySummary`
/// (`session_summary.dart`).
const Set<String> defaultLocomotionLabels = {'wlk', 'ups', 'dws', 'jog'};

/// App-level minimum for consecutive matching-label windows before a segment
/// is exposed as a gait-analysis candidate. This threshold is project-specific
/// and is not clinically validated.
const int defaultGaitCandidateMinWindows = 5;

/// Reason code for a locomotion run that is shorter than the app-level gate.
const String tooFewLevelWalkingWindowsReason = 'too_few_level_walking_windows';

/// Extracts consecutive locomotion runs from smoothed session predictions.
///
/// This helper prepares candidate intervals only; cadence, step detection, and
/// stride-like metrics are intentionally left to later signal processing over
/// the persisted raw samples. The acceleration-signal premise follows Zijlstra
/// & Hof, "Assessment of spatio-temporal gait parameters from trunk
/// accelerations during human walking", Gait & Posture, 2003,
/// https://doi.org/10.1016/S0966-6362(02)00190-X; this app-level candidate gate
/// is not a clinically validated gait segmentation rule.
///
/// [labels] controls what counts as one run. The default is level-walking
/// only ([defaultLevelWalkingLabel]), matching the walking-speed/step-length
/// model's level-gait assumption; pass [defaultLocomotionLabels] instead to
/// also include stair runs, appropriate for step *counting* — see that
/// constant's doc comment for why the two use different label sets.
List<GaitSegment> extractGaitSegments(
  SessionLog session, {
  Set<String> labels = const {defaultLevelWalkingLabel},
  int minWindows = defaultGaitCandidateMinWindows,
  Duration fallbackStepDuration = defaultPredictionStepDuration,
}) {
  assert(labels.isNotEmpty, 'labels must not be empty');
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
    if (labels.contains(predictions[i].label)) {
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
