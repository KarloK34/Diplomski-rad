import 'package:gait_sense/models/gait_segment.dart';
import 'package:gait_sense/utils/gait_cadence.dart';
import 'package:gait_sense/utils/gait_walking_speed.dart';
import 'package:gait_sense/utils/session_summary.dart';

/// JSON (de)serialization for the computed session-summary value types.
///
/// These live here, not on the domain types themselves, so the large gait
/// analysis files stay focused on computation and the persistence mapping is
/// unit-testable in one place. Durations are stored as integer milliseconds
/// and enums by their name; unknown enum names fall back rather than throwing,
/// so a document written by a newer build still decodes.

Map<String, int> _intMap(Object? value) {
  if (value is! Map) return const {};
  return {
    for (final entry in value.entries)
      entry.key as String: (entry.value as num).toInt(),
  };
}

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  if (name is! String) return fallback;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

/// Encodes a per-class time total.
Map<String, dynamic> classTotalToJson(ClassTotal total) => {
  'label': total.label,
  'windows': total.windows,
  'timeMs': total.time.inMilliseconds,
  'fraction': total.fraction,
};

/// Decodes a per-class time total.
ClassTotal classTotalFromJson(Map<String, dynamic> json) => ClassTotal(
  label: json['label'] as String,
  windows: (json['windows'] as num).toInt(),
  time: Duration(milliseconds: (json['timeMs'] as num).toInt()),
  fraction: (json['fraction'] as num).toDouble(),
);

/// Encodes one collapsed activity-timeline segment.
Map<String, dynamic> timelineSegmentToJson(TimelineSegment segment) => {
  'label': segment.label,
  'startMs': segment.start.inMilliseconds,
  'endMs': segment.end.inMilliseconds,
  'windows': segment.windows,
};

/// Decodes one collapsed activity-timeline segment.
TimelineSegment timelineSegmentFromJson(Map<String, dynamic> json) =>
    TimelineSegment(
      label: json['label'] as String,
      start: Duration(milliseconds: (json['startMs'] as num).toInt()),
      end: Duration(milliseconds: (json['endMs'] as num).toInt()),
      windows: (json['windows'] as num).toInt(),
    );

/// Encodes the quality/gait-analysis summary, composing the nested types.
Map<String, dynamic> qualitySummaryToJson(SessionQualitySummary quality) => {
  'predictionCount': quality.predictionCount,
  'rawSmoothedChangeCount': quality.rawSmoothedChangeCount,
  'rawSmoothedChangeFraction': quality.rawSmoothedChangeFraction,
  'effectiveLabelWindowCounts': quality.effectiveLabelWindowCounts,
  'rawLabelWindowCounts': quality.rawLabelWindowCounts,
  'stableLocomotionSegments': [
    for (final segment in quality.stableLocomotionSegments)
      _stableSegmentToJson(segment),
  ],
  'stableLocomotionWindowCount': quality.stableLocomotionWindowCount,
  'stableLocomotionDurationMs':
      quality.stableLocomotionDuration.inMilliseconds,
  'hasEnoughStableLocomotion': quality.hasEnoughStableLocomotion,
  'gaitSegments': [
    for (final segment in quality.gaitSegments) _gaitSegmentToJson(segment),
  ],
  'gaitCadence': _cadenceToJson(quality.gaitCadence),
  'gaitWalkingSpeed': _walkingSpeedToJson(quality.gaitWalkingSpeed),
};

/// Decodes the quality/gait-analysis summary.
SessionQualitySummary qualitySummaryFromJson(Map<String, dynamic> json) {
  final stable = (json['stableLocomotionSegments'] as List? ?? const [])
      .map((e) => _stableSegmentFromJson(e as Map<String, dynamic>))
      .toList();
  final gaitSegments = (json['gaitSegments'] as List? ?? const [])
      .map((e) => _gaitSegmentFromJson(e as Map<String, dynamic>))
      .toList();
  return SessionQualitySummary(
    predictionCount: (json['predictionCount'] as num).toInt(),
    rawSmoothedChangeCount: (json['rawSmoothedChangeCount'] as num).toInt(),
    rawSmoothedChangeFraction:
        (json['rawSmoothedChangeFraction'] as num).toDouble(),
    effectiveLabelWindowCounts: _intMap(json['effectiveLabelWindowCounts']),
    rawLabelWindowCounts: _intMap(json['rawLabelWindowCounts']),
    stableLocomotionSegments: stable,
    stableLocomotionWindowCount:
        (json['stableLocomotionWindowCount'] as num).toInt(),
    stableLocomotionDuration: Duration(
      milliseconds: (json['stableLocomotionDurationMs'] as num).toInt(),
    ),
    hasEnoughStableLocomotion: json['hasEnoughStableLocomotion'] as bool,
    gaitSegments: gaitSegments,
    gaitCadence: _cadenceFromJson(
      json['gaitCadence'] as Map<String, dynamic>,
    ),
    gaitWalkingSpeed: _walkingSpeedFromJson(
      json['gaitWalkingSpeed'] as Map<String, dynamic>,
    ),
  );
}

Map<String, dynamic> _stableSegmentToJson(StableLocomotionSegment segment) => {
  'startIndex': segment.startIndex,
  'endIndexExclusive': segment.endIndexExclusive,
  'windows': segment.windows,
  'startOffsetMs': segment.startOffset.inMilliseconds,
  'endOffsetMs': segment.endOffset.inMilliseconds,
  'effectiveLabelWindowCounts': segment.effectiveLabelWindowCounts,
};

StableLocomotionSegment _stableSegmentFromJson(Map<String, dynamic> json) =>
    StableLocomotionSegment(
      startIndex: (json['startIndex'] as num).toInt(),
      endIndexExclusive: (json['endIndexExclusive'] as num).toInt(),
      windows: (json['windows'] as num).toInt(),
      startOffset: Duration(
        milliseconds: (json['startOffsetMs'] as num).toInt(),
      ),
      endOffset: Duration(milliseconds: (json['endOffsetMs'] as num).toInt()),
      effectiveLabelWindowCounts: _intMap(json['effectiveLabelWindowCounts']),
    );

Map<String, dynamic> _gaitSegmentToJson(GaitSegment segment) => {
  'startIndex': segment.startIndex,
  'endIndexExclusive': segment.endIndexExclusive,
  'windows': segment.windows,
  'displayStartOffsetMs': segment.displayStartOffset.inMilliseconds,
  'displayEndOffsetMs': segment.displayEndOffset.inMilliseconds,
  'analysisStartOffsetMs': segment.analysisStartOffset.inMilliseconds,
  'analysisEndOffsetMs': segment.analysisEndOffset.inMilliseconds,
  'analysisStartSampleIndex': segment.analysisStartSampleIndex,
  'analysisEndSampleIndexExclusive': segment.analysisEndSampleIndexExclusive,
  'labelCounts': segment.labelCounts,
  'quality': segment.quality.name,
  'qualityReason': segment.qualityReason,
};

GaitSegment _gaitSegmentFromJson(Map<String, dynamic> json) => GaitSegment(
  startIndex: (json['startIndex'] as num).toInt(),
  endIndexExclusive: (json['endIndexExclusive'] as num).toInt(),
  windows: (json['windows'] as num).toInt(),
  displayStartOffset: Duration(
    milliseconds: (json['displayStartOffsetMs'] as num).toInt(),
  ),
  displayEndOffset: Duration(
    milliseconds: (json['displayEndOffsetMs'] as num).toInt(),
  ),
  analysisStartOffset: Duration(
    milliseconds: (json['analysisStartOffsetMs'] as num).toInt(),
  ),
  analysisEndOffset: Duration(
    milliseconds: (json['analysisEndOffsetMs'] as num).toInt(),
  ),
  analysisStartSampleIndex: (json['analysisStartSampleIndex'] as num?)?.toInt(),
  analysisEndSampleIndexExclusive:
      (json['analysisEndSampleIndexExclusive'] as num?)?.toInt(),
  labelCounts: _intMap(json['labelCounts']),
  quality: _enumByName(
    GaitSegmentQuality.values,
    json['quality'],
    GaitSegmentQuality.tooFewWindows,
  ),
  qualityReason: json['qualityReason'] as String?,
);

Map<String, dynamic> _temporalToJson(GaitTemporalParameters params) => {
  'stepIntervalCount': params.stepIntervalCount,
  'meanStepTimeMs': params.meanStepTime.inMilliseconds,
  'medianStepTimeMs': params.medianStepTime.inMilliseconds,
  'stepTimeStandardDeviationMs':
      params.stepTimeStandardDeviation.inMilliseconds,
  'stepTimeCoefficientOfVariation': params.stepTimeCoefficientOfVariation,
  'minimumStepTimeMs': params.minimumStepTime.inMilliseconds,
  'maximumStepTimeMs': params.maximumStepTime.inMilliseconds,
  'strideIntervalCount': params.strideIntervalCount,
  'meanStrideTimeMs': params.meanStrideTime?.inMilliseconds,
  'strideTimeStandardDeviationMs':
      params.strideTimeStandardDeviation?.inMilliseconds,
  'strideTimeCoefficientOfVariation': params.strideTimeCoefficientOfVariation,
  'meanInstantCadenceStepsPerMinute': params.meanInstantCadenceStepsPerMinute,
  'instantCadenceStandardDeviationStepsPerMinute':
      params.instantCadenceStandardDeviationStepsPerMinute,
  'instantCadenceCoefficientOfVariation':
      params.instantCadenceCoefficientOfVariation,
  'gaitRegularity': params.gaitRegularity,
};

GaitTemporalParameters _temporalFromJson(Map<String, dynamic> json) {
  Duration? optionalMs(Object? value) =>
      value == null ? null : Duration(milliseconds: (value as num).toInt());
  Duration requiredMs(Object? value) =>
      Duration(milliseconds: (value! as num).toInt());
  return GaitTemporalParameters(
    stepIntervalCount: (json['stepIntervalCount'] as num).toInt(),
    meanStepTime: requiredMs(json['meanStepTimeMs']),
    medianStepTime: requiredMs(json['medianStepTimeMs']),
    stepTimeStandardDeviation: requiredMs(json['stepTimeStandardDeviationMs']),
    stepTimeCoefficientOfVariation:
        (json['stepTimeCoefficientOfVariation'] as num).toDouble(),
    minimumStepTime: requiredMs(json['minimumStepTimeMs']),
    maximumStepTime: requiredMs(json['maximumStepTimeMs']),
    strideIntervalCount: (json['strideIntervalCount'] as num).toInt(),
    meanStrideTime: optionalMs(json['meanStrideTimeMs']),
    strideTimeStandardDeviation:
        optionalMs(json['strideTimeStandardDeviationMs']),
    strideTimeCoefficientOfVariation:
        (json['strideTimeCoefficientOfVariation'] as num?)?.toDouble(),
    meanInstantCadenceStepsPerMinute:
        (json['meanInstantCadenceStepsPerMinute'] as num).toDouble(),
    instantCadenceStandardDeviationStepsPerMinute:
        (json['instantCadenceStandardDeviationStepsPerMinute'] as num)
            .toDouble(),
    instantCadenceCoefficientOfVariation:
        (json['instantCadenceCoefficientOfVariation'] as num).toDouble(),
    gaitRegularity: (json['gaitRegularity'] as num?)?.toDouble(),
  );
}

Map<String, dynamic> _cadenceToJson(GaitCadenceSummary cadence) => {
  'signalSegmentCount': cadence.signalSegmentCount,
  'sampledSignalSegmentCount': cadence.sampledSignalSegmentCount,
  'computedResultCount': cadence.computedResultCount,
  'averageCadenceStepsPerMinute': cadence.averageCadenceStepsPerMinute,
  'totalStepCount': cadence.totalStepCount,
  'temporalParameters': cadence.temporalParameters == null
      ? null
      : _temporalToJson(cadence.temporalParameters!),
  'status': cadence.status.name,
  'reason': cadence.reason,
  'confidence': cadence.confidence.name,
  'confidenceReason': cadence.confidenceReason,
};

GaitCadenceSummary _cadenceFromJson(Map<String, dynamic> json) {
  final temporal = json['temporalParameters'];
  return GaitCadenceSummary(
    signalSegmentCount: (json['signalSegmentCount'] as num).toInt(),
    sampledSignalSegmentCount:
        (json['sampledSignalSegmentCount'] as num).toInt(),
    computedResultCount: (json['computedResultCount'] as num).toInt(),
    averageCadenceStepsPerMinute:
        (json['averageCadenceStepsPerMinute'] as num?)?.toDouble(),
    totalStepCount: (json['totalStepCount'] as num).toInt(),
    temporalParameters: temporal == null
        ? null
        : _temporalFromJson(temporal as Map<String, dynamic>),
    status: _enumByName(
      GaitCadenceStatus.values,
      json['status'],
      GaitCadenceStatus.empty,
    ),
    reason: json['reason'] as String?,
    confidence: _enumByName(
      GaitCadenceConfidence.values,
      json['confidence'],
      GaitCadenceConfidence.low,
    ),
    confidenceReason: json['confidenceReason'] as String?,
  );
}

Map<String, dynamic> _walkingSpeedToJson(GaitWalkingSpeedSummary speed) => {
  'signalSegmentCount': speed.signalSegmentCount,
  'computedResultCount': speed.computedResultCount,
  'averageWalkingSpeedMs': speed.averageWalkingSpeedMs,
  'averageStepLengthM': speed.averageStepLengthM,
  'status': speed.status.name,
  'reason': speed.reason,
};

GaitWalkingSpeedSummary _walkingSpeedFromJson(Map<String, dynamic> json) =>
    GaitWalkingSpeedSummary(
      signalSegmentCount: (json['signalSegmentCount'] as num).toInt(),
      computedResultCount: (json['computedResultCount'] as num).toInt(),
      averageWalkingSpeedMs:
          (json['averageWalkingSpeedMs'] as num?)?.toDouble(),
      averageStepLengthM: (json['averageStepLengthM'] as num?)?.toDouble(),
      status: _enumByName(
        GaitWalkingSpeedStatus.values,
        json['status'],
        GaitWalkingSpeedStatus.unavailable,
      ),
      reason: json['reason'] as String?,
    );
