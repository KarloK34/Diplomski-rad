import 'package:equatable/equatable.dart';

/// Quality status for a gait-segment candidate.
enum GaitSegmentQuality {
  /// Segment passes the app-level candidate gate.
  suitable,

  /// Segment matches the requested locomotion labels, but is shorter than the
  /// app-level minimum.
  tooFewWindows,
}

/// Consecutive same-purpose locomotion predictions prepared for later gait
/// analysis.
///
/// The `wlk`, `ups`, `dws`, and `jog` codes follow the MotionSense dataset
/// taxonomy (Malekzadeh et al., "Mobile Sensor Data Anonymization", IoTDI
/// 2019, https://doi.org/10.1145/3302505.3310068). Which labels form a run is
/// decided by the caller of `extractGaitSegments`: level-walking only (`wlk`)
/// for the walking-speed/step-length model, or the broader
/// `defaultLocomotionLabels` (`wlk`+`ups`+`dws`+`jog`) for step counting —
/// see that constant's doc comment. That gate is an application policy, not a
/// clinically validated rule.
class GaitSegment extends Equatable {
  /// Creates a gait-analysis candidate segment.
  const GaitSegment({
    required this.startIndex,
    required this.endIndexExclusive,
    required this.windows,
    required this.displayStartOffset,
    required this.displayEndOffset,
    required this.analysisStartOffset,
    required this.analysisEndOffset,
    required this.analysisStartSampleIndex,
    required this.analysisEndSampleIndexExclusive,
    required this.labelCounts,
    required this.quality,
    required this.qualityReason,
  });

  /// Index of the first prediction in this run.
  final int startIndex;

  /// Index after the last prediction in this run.
  final int endIndexExclusive;

  /// Number of prediction windows in this run.
  final int windows;

  /// Offset used when the segment is drawn in a session timeline.
  final Duration displayStartOffset;

  /// End offset used when the segment is drawn in a session timeline.
  final Duration displayEndOffset;

  /// Offset used for later signal analysis of this gait candidate.
  final Duration analysisStartOffset;

  /// End offset used for later signal analysis of this gait candidate.
  final Duration analysisEndOffset;

  /// Inclusive raw-sample index where signal analysis should start.
  ///
  /// Null means the segment came from predictions without persisted sample
  /// indices, so callers must fall back to timestamp offsets.
  final int? analysisStartSampleIndex;

  /// Exclusive raw-sample index where signal analysis should stop.
  ///
  /// The interval is [analysisStartSampleIndex,
  /// analysisEndSampleIndexExclusive) when both values are non-null.
  final int? analysisEndSampleIndexExclusive;

  /// Analysis duration derived from [analysisStartOffset] and
  /// [analysisEndOffset].
  Duration get duration {
    final span = analysisEndOffset - analysisStartOffset;
    return span.isNegative ? Duration.zero : span;
  }

  /// Effective-label counts inside this run.
  final Map<String, int> labelCounts;

  /// App-level quality status for this candidate.
  final GaitSegmentQuality quality;

  /// Machine-readable reason when [quality] is not suitable.
  final String? qualityReason;

  /// Whether this segment can be used by the next gait-analysis step.
  bool get isSuitable => quality == GaitSegmentQuality.suitable;

  @override
  List<Object?> get props => [
    startIndex,
    endIndexExclusive,
    windows,
    displayStartOffset,
    displayEndOffset,
    analysisStartOffset,
    analysisEndOffset,
    analysisStartSampleIndex,
    analysisEndSampleIndexExclusive,
    labelCounts,
    quality,
    qualityReason,
  ];
}
