import 'package:equatable/equatable.dart';
import 'package:gait_sense/models/gait_segment.dart';
import 'package:gait_sense/models/sensor_sample.dart';
import 'package:gait_sense/models/session_log.dart';
import 'package:gait_sense/utils/gait_segments.dart';

/// No raw samples were persisted with the session.
const String missingRawSamplesReason = 'missing_raw_samples';

/// The persisted sample-index bounds are not a valid half-open interval.
const String invalidSampleIndexRangeReason = 'invalid_sample_index_range';

/// The persisted sample-index bounds do not fit the raw-sample list.
const String sampleIndexOutOfRangeReason = 'sample_index_out_of_range';

/// The timestamp-offset fallback bounds are not a valid half-open interval.
const String invalidTimeOffsetRangeReason = 'invalid_time_offset_range';

/// The timestamp-offset fallback found no raw samples inside the segment.
const String noSamplesInTimeRangeReason = 'no_samples_in_time_range';

/// Boundary source used to cut raw samples for a gait candidate.
enum GaitSignalSegmentBoundarySource {
  /// Preferred path: half-open raw-sample indices from the HAR source windows.
  sampleIndex,

  /// Backward-compatible path for older logs without prediction sample indices.
  timestampOffset,
}

/// Raw signal associated with one suitable level-walking candidate.
///
/// [samples] contains raw session samples in the half-open interval
/// [startSampleIndex, endSampleIndexExclusive) when sample-index bounds are
/// available. Older logs fall back to [GaitSegment.analysisStartOffset] and
/// [GaitSegment.analysisEndOffset], using the same half-open rule on sample
/// timestamps. Acceleration-signal gait analysis is motivated by Zijlstra &
/// Hof, "Assessment of spatio-temporal gait parameters from trunk
/// accelerations during human walking", Gait & Posture, 2003,
/// https://doi.org/10.1016/S0966-6362(02)00190-X; this helper only prepares
/// project-level signal slices and does not compute clinical gait parameters.
class GaitSignalSegment extends Equatable {
  /// Creates a raw-signal slice result.
  const GaitSignalSegment({
    required this.gaitSegment,
    required this.samples,
    required this.startSampleIndex,
    required this.endSampleIndexExclusive,
    required this.boundarySource,
    required this.emptyReason,
  });

  /// Gait candidate used to define the signal interval.
  final GaitSegment gaitSegment;

  /// Raw IMU samples belonging to the candidate interval.
  final List<SensorSample> samples;

  /// Inclusive index in [SessionLog.rawSamples] for this slice, when known.
  final int? startSampleIndex;

  /// Exclusive index in [SessionLog.rawSamples] for this slice, when known.
  final int? endSampleIndexExclusive;

  /// Whether the slice came from sample indices or timestamp offsets.
  final GaitSignalSegmentBoundarySource? boundarySource;

  /// Machine-readable reason when [samples] is empty.
  final String? emptyReason;

  /// Whether the slice contains at least one raw sample.
  bool get hasSamples => samples.isNotEmpty;

  @override
  List<Object?> get props => [
    gaitSegment,
    samples,
    startSampleIndex,
    endSampleIndexExclusive,
    boundarySource,
    emptyReason,
  ];
}

/// Returns raw-signal slices for every suitable gait candidate in [session].
///
/// Normal summary flow should not fail because an old or partial session lacks
/// sample bounds: invalid or missing data yields an empty sample list plus a
/// machine-readable [GaitSignalSegment.emptyReason].
List<GaitSignalSegment> extractGaitSignalSegments(
  SessionLog session, {
  List<GaitSegment>? gaitSegments,
}) {
  final candidates = gaitSegments ?? extractGaitSegments(session);
  return List.unmodifiable(
    candidates
        .where((segment) => segment.isSuitable)
        .map((segment) => _sliceSignal(session, segment)),
  );
}

GaitSignalSegment _sliceSignal(
  SessionLog session,
  GaitSegment segment,
) {
  if (session.rawSamples.isEmpty) {
    return _emptySignalSegment(
      segment,
      reason: missingRawSamplesReason,
      boundarySource: null,
    );
  }

  final startIndex = segment.analysisStartSampleIndex;
  final endIndexExclusive = segment.analysisEndSampleIndexExclusive;
  if (startIndex != null && endIndexExclusive != null) {
    return _sliceBySampleIndex(
      session,
      segment,
      startIndex: startIndex,
      endIndexExclusive: endIndexExclusive,
    );
  }

  return _sliceByTimestampOffset(session, segment);
}

GaitSignalSegment _sliceBySampleIndex(
  SessionLog session,
  GaitSegment segment, {
  required int startIndex,
  required int endIndexExclusive,
}) {
  if (startIndex < 0 || endIndexExclusive <= startIndex) {
    return _emptySignalSegment(
      segment,
      startSampleIndex: startIndex,
      endSampleIndexExclusive: endIndexExclusive,
      boundarySource: GaitSignalSegmentBoundarySource.sampleIndex,
      reason: invalidSampleIndexRangeReason,
    );
  }
  if (endIndexExclusive > session.rawSamples.length) {
    return _emptySignalSegment(
      segment,
      startSampleIndex: startIndex,
      endSampleIndexExclusive: endIndexExclusive,
      boundarySource: GaitSignalSegmentBoundarySource.sampleIndex,
      reason: sampleIndexOutOfRangeReason,
    );
  }

  return GaitSignalSegment(
    gaitSegment: segment,
    samples: List.unmodifiable(
      session.rawSamples.sublist(startIndex, endIndexExclusive),
    ),
    startSampleIndex: startIndex,
    endSampleIndexExclusive: endIndexExclusive,
    boundarySource: GaitSignalSegmentBoundarySource.sampleIndex,
    emptyReason: null,
  );
}

GaitSignalSegment _sliceByTimestampOffset(
  SessionLog session,
  GaitSegment segment,
) {
  final startOffset = segment.analysisStartOffset;
  final endOffset = segment.analysisEndOffset;
  if (startOffset.isNegative || endOffset <= startOffset) {
    return _emptySignalSegment(
      segment,
      boundarySource: GaitSignalSegmentBoundarySource.timestampOffset,
      reason: invalidTimeOffsetRangeReason,
    );
  }

  int? startIndex;
  var endIndexExclusive = session.rawSamples.length;
  for (var i = 0; i < session.rawSamples.length; i++) {
    final offset = session.rawSamples[i].timestamp.difference(
      session.startedAt,
    );
    if (startIndex == null && offset >= startOffset) {
      startIndex = i;
    }
    if (startIndex != null && offset >= endOffset) {
      endIndexExclusive = i;
      break;
    }
  }

  if (startIndex == null || endIndexExclusive <= startIndex) {
    return _emptySignalSegment(
      segment,
      startSampleIndex: startIndex,
      endSampleIndexExclusive: endIndexExclusive,
      boundarySource: GaitSignalSegmentBoundarySource.timestampOffset,
      reason: noSamplesInTimeRangeReason,
    );
  }

  return GaitSignalSegment(
    gaitSegment: segment,
    samples: List.unmodifiable(
      session.rawSamples.sublist(startIndex, endIndexExclusive),
    ),
    startSampleIndex: startIndex,
    endSampleIndexExclusive: endIndexExclusive,
    boundarySource: GaitSignalSegmentBoundarySource.timestampOffset,
    emptyReason: null,
  );
}

GaitSignalSegment _emptySignalSegment(
  GaitSegment segment, {
  required String reason,
  required GaitSignalSegmentBoundarySource? boundarySource,
  int? startSampleIndex,
  int? endSampleIndexExclusive,
}) {
  return GaitSignalSegment(
    gaitSegment: segment,
    samples: const [],
    startSampleIndex: startSampleIndex,
    endSampleIndexExclusive: endSampleIndexExclusive,
    boundarySource: boundarySource,
    emptyReason: reason,
  );
}
