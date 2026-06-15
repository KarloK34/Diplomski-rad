import 'package:equatable/equatable.dart';

/// Quality status for a level-walking gait-analysis candidate.
enum GaitSegmentQuality {
  /// Segment passes the app-level candidate gate.
  suitable,

  /// Segment is level walking, but shorter than the app-level minimum.
  tooFewWindows,
}

/// Consecutive `wlk` predictions prepared for later gait analysis.
///
/// The `wlk`, `ups`, and `dws` codes follow the MotionSense dataset taxonomy
/// (Malekzadeh et al., "Mobile Sensor Data Anonymization", IoTDI 2019,
/// https://doi.org/10.1145/3302505.3310068). This model intentionally treats
/// only `wlk` as a level-walking candidate; stair labels remain locomotion but
/// are not used for level-walking gait metrics. That gate is an application
/// policy, not a clinically validated rule.
class GaitSegment extends Equatable {
  /// Creates a gait-analysis candidate segment.
  const GaitSegment({
    required this.startIndex,
    required this.endIndexExclusive,
    required this.windows,
    required this.startOffset,
    required this.endOffset,
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

  /// Offset from session start where the segment begins.
  final Duration startOffset;

  /// Offset from session start where the segment ends.
  final Duration endOffset;

  /// Segment duration derived from [startOffset] and [endOffset].
  Duration get duration {
    final span = endOffset - startOffset;
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
    startOffset,
    endOffset,
    labelCounts,
    quality,
    qualityReason,
  ];
}
