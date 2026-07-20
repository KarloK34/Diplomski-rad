import 'package:equatable/equatable.dart';
import 'package:gait_sense/models/gait_segment.dart';
import 'package:gait_sense/models/session_log.dart';
import 'package:gait_sense/utils/activity_labels.dart';
import 'package:gait_sense/utils/gait_cadence.dart';
import 'package:gait_sense/utils/gait_segments.dart';
import 'package:gait_sense/utils/gait_signal_segments.dart';
import 'package:gait_sense/utils/gait_temporal_parameters.dart';
import 'package:gait_sense/utils/gait_walking_speed.dart';
import 'package:gait_sense/utils/prediction_segment_time.dart';

/// Pure aggregation helpers for the session summary screen.
///
/// All functions here are platform-free so they can be unit-tested on the host
/// VM; the screen widget consumes their output and adds the display layer.

/// App-level minimum for consecutive locomotion windows before a run is shown
/// as stable locomotion. This threshold is project-specific and is not
/// clinically validated.
const int defaultStableLocomotionMinWindows = 5;

/// No suitable level-walking signal segment was available for cadence.
const String noSuitableCadenceSignalReason = 'no_suitable_cadence_signal';

/// User height was not provided so walking speed cannot be estimated.
const String missingUserHeightReason = 'missing_user_height';

/// Aggregated time a single activity class occupied during a session.
class ClassTotal extends Equatable {
  /// Creates a class total.
  const ClassTotal({
    required this.label,
    required this.windows,
    required this.time,
    required this.fraction,
  });

  /// Model class code (e.g. `wlk`), or [restingActivityCode] when `std`/`sit`
  /// windows were merged for display; map to a name via the labels util.
  final String label;

  /// Number of prediction windows assigned to this class.
  final int windows;

  /// Estimated wall-clock time spent in this class.
  final Duration time;

  /// Share of the session's windows assigned to this class, in `[0, 1]`.
  final double fraction;

  @override
  List<Object?> get props => [label, windows, time, fraction];
}

/// One run of consecutive same-label prediction windows.
class TimelineSegment extends Equatable {
  /// Creates a timeline segment.
  const TimelineSegment({
    required this.label,
    required this.start,
    required this.end,
    required this.windows,
  });

  /// Model class code for the segment, or [restingActivityCode] when it
  /// collapses a `std`/`sit` run for display.
  final String label;

  /// Offset from session start at which this segment begins.
  final Duration start;

  /// Offset from session start at which this segment ends.
  final Duration end;

  /// Number of prediction windows collapsed into this segment.
  final int windows;

  @override
  List<Object?> get props => [label, start, end, windows];
}

/// One consecutive locomotion run that is long enough for the app-level gate.
class StableLocomotionSegment extends Equatable {
  /// Creates a stable locomotion segment.
  const StableLocomotionSegment({
    required this.startIndex,
    required this.endIndexExclusive,
    required this.windows,
    required this.startOffset,
    required this.endOffset,
    required this.effectiveLabelWindowCounts,
  });

  /// Index of the first prediction in the segment.
  final int startIndex;

  /// Index after the last prediction in the segment.
  final int endIndexExclusive;

  /// Number of effective HAR windows in the segment.
  final int windows;

  /// Offset from session start at which this segment begins.
  final Duration startOffset;

  /// Offset from session start at which this segment ends.
  final Duration endOffset;

  /// Duration derived from timestamps where possible.
  Duration get duration {
    final span = endOffset - startOffset;
    return span.isNegative ? Duration.zero : span;
  }

  /// Effective-label counts inside this stable locomotion segment.
  final Map<String, int> effectiveLabelWindowCounts;

  @override
  List<Object?> get props => [
    startIndex,
    endIndexExclusive,
    windows,
    startOffset,
    endOffset,
    effectiveLabelWindowCounts,
  ];
}

/// Prototype cadence aggregation over suitable locomotion signal slices
/// (level-walking, stairs, and jogging — see [defaultLocomotionLabels]).
///
/// Acceleration-based gait analysis is motivated by Zijlstra & Hof,
/// "Assessment of spatio-temporal gait parameters from trunk accelerations
/// during human walking", Gait & Posture, 2003,
/// https://doi.org/10.1016/S0966-6362(02)00190-X. The aggregation here is an
/// app-level prototype output and is not clinically validated.
class GaitCadenceSummary extends Equatable {
  /// Creates a session-level cadence summary.
  const GaitCadenceSummary({
    required this.signalSegmentCount,
    required this.sampledSignalSegmentCount,
    required this.computedResultCount,
    required this.averageCadenceStepsPerMinute,
    required this.signalDuration,
    required this.totalStepCount,
    required this.temporalParameters,
    required this.status,
    required this.reason,
    required this.confidence,
    required this.confidenceReason,
  });

  /// Number of suitable gait signal segments considered.
  final int signalSegmentCount;

  /// Number of considered segments with a non-empty raw sample list.
  final int sampledSignalSegmentCount;

  /// Number of segments that produced a computed cadence result.
  final int computedResultCount;

  /// Duration-weighted cadence, or null when no segment produced cadence.
  final double? averageCadenceStepsPerMinute;

  /// Total duration of the computed segments backing
  /// [averageCadenceStepsPerMinute] — the same per-segment durations used to
  /// weight it (see [summarizeGaitCadence]). Persisted so cross-session
  /// aggregation (`session_aggregates.dart`) can reweight by the exact
  /// amount of signal each session contributed rather than by a proxy
  /// duration. [Duration.zero] whenever [averageCadenceStepsPerMinute] is
  /// null.
  final Duration signalDuration;

  /// Total accepted peak count across cadence attempts.
  final int totalStepCount;

  /// Experimental temporal gait descriptors derived from accepted step times.
  final GaitTemporalParameters? temporalParameters;

  /// Overall cadence availability status.
  final GaitCadenceStatus status;

  /// Machine-readable reason when [status] is not
  /// [GaitCadenceStatus.computed].
  final String? reason;

  /// Lowest confidence among the computed segment results.
  final GaitCadenceConfidence confidence;

  /// Machine-readable reason for a low confidence label.
  final String? confidenceReason;

  /// Whether [averageCadenceStepsPerMinute] is available.
  bool get hasComputedCadence => status == GaitCadenceStatus.computed;

  @override
  List<Object?> get props => [
    signalSegmentCount,
    sampledSignalSegmentCount,
    computedResultCount,
    averageCadenceStepsPerMinute,
    signalDuration,
    totalStepCount,
    temporalParameters,
    status,
    reason,
    confidence,
    confidenceReason,
  ];
}

/// Duration-weighted walking-speed and step-length summary across all suitable
/// level-walking gait segments in a session.
///
/// The weighting rule matches [GaitCadenceSummary]: longer segments contribute
/// proportionally more to the session average, giving a stable estimate that
/// is not dominated by short or unreliable segments.  All values are project-
/// level estimations; see [GaitWalkingSpeedResult] for the full disclaimer.
class GaitWalkingSpeedSummary extends Equatable {
  /// Creates a walking-speed summary.
  const GaitWalkingSpeedSummary({
    required this.signalSegmentCount,
    required this.computedResultCount,
    required this.averageWalkingSpeedMs,
    required this.averageStepLengthM,
    required this.status,
    required this.reason,
  });

  /// Convenience constructor for the case where no height was provided.
  const GaitWalkingSpeedSummary.noHeight()
    : signalSegmentCount = 0,
      computedResultCount = 0,
      averageWalkingSpeedMs = null,
      averageStepLengthM = null,
      status = GaitWalkingSpeedStatus.unavailable,
      reason = missingUserHeightReason;

  /// Number of suitable signal segments considered.
  final int signalSegmentCount;

  /// Number of segments that produced a computed result.
  final int computedResultCount;

  /// Duration-weighted average walking speed in m/s, or null when unavailable.
  final double? averageWalkingSpeedMs;

  /// Duration-weighted average step length in metres, or null when unavailable.
  final double? averageStepLengthM;

  /// Overall status for this summary.
  final GaitWalkingSpeedStatus status;

  /// Machine-readable reason when [status] is not computed.
  final String? reason;

  /// Whether [averageWalkingSpeedMs] and [averageStepLengthM] are available.
  bool get hasComputedSpeed => status == GaitWalkingSpeedStatus.computed;

  @override
  List<Object?> get props => [
    signalSegmentCount,
    computedResultCount,
    averageWalkingSpeedMs,
    averageStepLengthM,
    status,
    reason,
  ];
}

/// Quality summary that keeps raw HAR, smoothed HAR, stable locomotion, and
/// level-walking gait-analysis candidates separate.
class SessionQualitySummary extends Equatable {
  /// Creates a session quality summary.
  const SessionQualitySummary({
    required this.predictionCount,
    required this.rawSmoothedChangeCount,
    required this.rawSmoothedChangeFraction,
    required this.effectiveLabelWindowCounts,
    required this.rawLabelWindowCounts,
    required this.stableLocomotionSegments,
    required this.stableLocomotionWindowCount,
    required this.stableLocomotionDuration,
    required this.hasEnoughStableLocomotion,
    required this.gaitSegments,
    required this.gaitCadence,
    required this.gaitWalkingSpeed,
  });

  /// Total number of prediction windows in the session.
  final int predictionCount;

  /// Number of windows where temporal smoothing changed the raw model argmax.
  final int rawSmoothedChangeCount;

  /// Share of predictions changed by temporal smoothing, in `[0, 1]`.
  final double rawSmoothedChangeFraction;

  /// Window counts by effective label after smoothing.
  final Map<String, int> effectiveLabelWindowCounts;

  /// Window counts by raw model argmax before smoothing.
  final Map<String, int> rawLabelWindowCounts;

  /// Consecutive locomotion runs that satisfy the app-level gate.
  final List<StableLocomotionSegment> stableLocomotionSegments;

  /// Total number of windows inside stable locomotion runs.
  final int stableLocomotionWindowCount;

  /// Total timestamp-derived duration inside stable locomotion runs.
  final Duration stableLocomotionDuration;

  /// Whether at least one stable locomotion run exists.
  final bool hasEnoughStableLocomotion;

  /// Consecutive `wlk` runs considered for level-walking gait analysis.
  final List<GaitSegment> gaitSegments;

  /// Prototype cadence summary computed from suitable locomotion signal
  /// slices — broader than [gaitSegments] (see [defaultLocomotionLabels]),
  /// so its step count can include stair runs that never appear there.
  final GaitCadenceSummary gaitCadence;

  /// Prototype walking-speed and step-length summary computed from suitable
  /// raw gait signal slices.  Null when no user height was provided.
  final GaitWalkingSpeedSummary gaitWalkingSpeed;

  /// Candidate gait segments that pass the app-level gate.
  List<GaitSegment> get suitableGaitSegments {
    return List.unmodifiable(
      gaitSegments.where((segment) => segment.isSuitable),
    );
  }

  /// Total number of windows inside suitable level-walking gait candidates.
  int get levelWalkingGaitWindowCount {
    return suitableGaitSegments.fold<int>(
      0,
      (sum, segment) => sum + segment.windows,
    );
  }

  /// Total duration inside suitable level-walking gait candidates.
  Duration get levelWalkingGaitDuration {
    final microseconds = suitableGaitSegments.fold<int>(
      0,
      (sum, segment) => sum + segment.duration.inMicroseconds,
    );
    return Duration(microseconds: microseconds);
  }

  /// Whether a level-walking gait-analysis candidate exists.
  bool get hasEnoughLevelWalkingGaitSegments => suitableGaitSegments.isNotEmpty;

  @override
  List<Object?> get props => [
    predictionCount,
    rawSmoothedChangeCount,
    rawSmoothedChangeFraction,
    effectiveLabelWindowCounts,
    rawLabelWindowCounts,
    stableLocomotionSegments,
    stableLocomotionWindowCount,
    stableLocomotionDuration,
    hasEnoughStableLocomotion,
    gaitSegments,
    gaitCadence,
    gaitWalkingSpeed,
  ];
}

/// Aggregates cadence results for suitable raw signal segments.
///
/// The mean uses segment duration as a project display rule: a longer raw
/// signal contributes proportionally more than a shorter one. This aggregation
/// rule is not clinically validated.
GaitCadenceSummary summarizeGaitCadence(
  List<GaitSignalSegment> signalSegments, {
  Duration minimumDuration = defaultCadenceMinimumDuration,
  double lowPassCutoffHz = defaultCadenceLowPassCutoffHz,
  double minimumCadenceStepsPerMinute = defaultCadenceMinimumStepsPerMinute,
  double maximumCadenceStepsPerMinute = defaultCadenceMaximumStepsPerMinute,
  double minimumPeakIntervalFraction =
      defaultCadenceMinimumPeakIntervalFraction,
  double peakThresholdStdMultiplier = defaultCadencePeakThresholdStdMultiplier,
  double minimumPeriodicity = defaultCadenceMinimumPeriodicity,
  double maximumEstimateDisagreement =
      defaultCadenceMaximumEstimateDisagreement,
  int minimumDetectedSteps = defaultCadenceMinimumDetectedSteps,
}) {
  if (signalSegments.isEmpty) {
    return const GaitCadenceSummary(
      signalSegmentCount: 0,
      sampledSignalSegmentCount: 0,
      computedResultCount: 0,
      averageCadenceStepsPerMinute: null,
      signalDuration: Duration.zero,
      totalStepCount: 0,
      temporalParameters: null,
      status: GaitCadenceStatus.empty,
      reason: noSuitableCadenceSignalReason,
      confidence: GaitCadenceConfidence.low,
      confidenceReason: noSuitableCadenceSignalReason,
    );
  }

  final sampledSignals = [
    for (final signal in signalSegments)
      if (signal.hasSamples) signal,
  ];
  if (sampledSignals.isEmpty) {
    return GaitCadenceSummary(
      signalSegmentCount: signalSegments.length,
      sampledSignalSegmentCount: 0,
      computedResultCount: 0,
      averageCadenceStepsPerMinute: null,
      signalDuration: Duration.zero,
      totalStepCount: 0,
      temporalParameters: null,
      status: GaitCadenceStatus.empty,
      reason: _firstEmptySignalReason(signalSegments),
      confidence: GaitCadenceConfidence.low,
      confidenceReason: _firstEmptySignalReason(signalSegments),
    );
  }

  final results = [
    for (final signal in sampledSignals)
      analyzeGaitCadence(
        signal,
        minimumDuration: minimumDuration,
        lowPassCutoffHz: lowPassCutoffHz,
        minimumCadenceStepsPerMinute: minimumCadenceStepsPerMinute,
        maximumCadenceStepsPerMinute: maximumCadenceStepsPerMinute,
        minimumPeakIntervalFraction: minimumPeakIntervalFraction,
        peakThresholdStdMultiplier: peakThresholdStdMultiplier,
        minimumPeriodicity: minimumPeriodicity,
        maximumEstimateDisagreement: maximumEstimateDisagreement,
        minimumDetectedSteps: minimumDetectedSteps,
      ),
  ];
  final computedResults = [
    for (final result in results)
      if (result.isComputed) result,
  ];
  final totalStepCount = computedResults.fold<int>(
    0,
    (sum, result) => sum + result.stepCount,
  );

  if (computedResults.isEmpty) {
    final firstResult = results.first;
    return GaitCadenceSummary(
      signalSegmentCount: signalSegments.length,
      sampledSignalSegmentCount: sampledSignals.length,
      computedResultCount: 0,
      averageCadenceStepsPerMinute: null,
      signalDuration: Duration.zero,
      totalStepCount: totalStepCount,
      temporalParameters: null,
      status: firstResult.status,
      reason: firstResult.reason,
      confidence: GaitCadenceConfidence.low,
      confidenceReason: firstResult.confidenceReason ?? firstResult.reason,
    );
  }

  final weightedDurationUs = computedResults.fold<int>(
    0,
    (sum, result) => sum + result.duration.inMicroseconds,
  );
  final weightedCadence = weightedDurationUs == 0
      ? null
      : computedResults.fold<double>(
              0,
              (sum, result) =>
                  sum +
                  result.cadenceStepsPerMinute * result.duration.inMicroseconds,
            ) /
            weightedDurationUs;
  final temporalParameters = summarizeGaitTemporalParameters(computedResults);
  final summaryConfidence = _lowestCadenceConfidence(computedResults);
  final confidenceReason = _firstCadenceConfidenceReason(computedResults);

  return GaitCadenceSummary(
    signalSegmentCount: signalSegments.length,
    sampledSignalSegmentCount: sampledSignals.length,
    computedResultCount: computedResults.length,
    averageCadenceStepsPerMinute: weightedCadence,
    signalDuration: Duration(microseconds: weightedDurationUs),
    totalStepCount: totalStepCount,
    temporalParameters: temporalParameters,
    status: weightedCadence == null
        ? GaitCadenceStatus.insufficientSignal
        : GaitCadenceStatus.computed,
    reason: weightedCadence == null ? cadenceSignalTooShortReason : null,
    confidence: summaryConfidence,
    confidenceReason: confidenceReason,
  );
}

GaitCadenceConfidence _lowestCadenceConfidence(
  List<GaitCadenceResult> results,
) {
  if (results.any(
    (result) => result.confidence == GaitCadenceConfidence.low,
  )) {
    return GaitCadenceConfidence.low;
  }
  if (results.any(
    (result) => result.confidence == GaitCadenceConfidence.moderate,
  )) {
    return GaitCadenceConfidence.moderate;
  }
  return GaitCadenceConfidence.high;
}

String? _firstCadenceConfidenceReason(List<GaitCadenceResult> results) {
  for (final result in results) {
    if (result.confidence == GaitCadenceConfidence.low &&
        result.confidenceReason != null) {
      return result.confidenceReason;
    }
  }
  return null;
}

String _firstEmptySignalReason(List<GaitSignalSegment> signalSegments) {
  for (final signal in signalSegments) {
    final reason = signal.emptyReason;
    if (reason != null) return reason;
  }
  return emptyCadenceSignalReason;
}

/// Wall-clock duration of [session]: the stop time minus the start time, or
/// while the session has no recorded stop time, the span up to the last
/// prediction. Returns [Duration.zero] for an empty session that never stopped,
/// and clamps any negative result to zero.
Duration sessionDuration(SessionLog session) {
  final predictions = session.predictions;
  final end =
      session.stoppedAt ??
      (predictions.isEmpty ? session.startedAt : predictions.last.timestamp);
  final span = end.difference(session.startedAt);
  return span.isNegative ? Duration.zero : span;
}

/// Per-class totals, sorted by occupied time descending (ties broken by class
/// code so the order is stable for a given input). `std`/`sit` windows are
/// merged into [restingActivityCode] (see its doc comment for why).
List<ClassTotal> computeClassTotals(SessionLog session) {
  final predictions = session.predictions;
  if (predictions.isEmpty) return const [];

  final counts = <String, int>{};
  for (final prediction in predictions) {
    final label = displayActivityCode(prediction.label);
    counts[label] = (counts[label] ?? 0) + 1;
  }

  final total = predictions.length;
  final durationUs = sessionDuration(session).inMicroseconds;

  final totals =
      <ClassTotal>[
        for (final entry in counts.entries)
          ClassTotal(
            label: entry.key,
            windows: entry.value,
            fraction: entry.value / total,
            time: Duration(
              microseconds: (durationUs * entry.value / total).round(),
            ),
          ),
      ]..sort((a, b) {
        final byWindows = b.windows.compareTo(a.windows);
        return byWindows != 0 ? byWindows : a.label.compareTo(b.label);
      });
  return totals;
}

/// Collapses consecutive same-label predictions into [TimelineSegment]s.
/// `std`/`sit` windows are merged into [restingActivityCode] (see its doc
/// comment for why), so a run alternating between the two becomes one segment.
List<TimelineSegment> computeTimeline(SessionLog session) {
  final predictions = session.predictions;
  if (predictions.isEmpty) return const [];

  final startedAt = session.startedAt;
  final duration = sessionDuration(session);

  Duration offsetAt(int index) {
    final span = predictions[index].timestamp.difference(startedAt);
    return span.isNegative ? Duration.zero : span;
  }

  final segments = <TimelineSegment>[];
  var runStart = 0;
  for (var i = 1; i <= predictions.length; i++) {
    final atEnd = i == predictions.length;
    if (!atEnd &&
        displayActivityCode(predictions[i].label) ==
            displayActivityCode(predictions[runStart].label)) {
      continue;
    }

    final start = runStart == 0 ? Duration.zero : offsetAt(runStart);
    var end = atEnd ? duration : offsetAt(i);
    if (end < start) end = start;

    segments.add(
      TimelineSegment(
        label: displayActivityCode(predictions[runStart].label),
        start: start,
        end: end,
        windows: i - runStart,
      ),
    );
    runStart = i;
  }
  return segments;
}

/// Computes raw-vs-smoothed HAR counts, stable locomotion, and gait candidates.
///
/// Pass [userHeightCm] to also compute the walking-speed and step-length
/// estimates.  When omitted, [SessionQualitySummary.gaitWalkingSpeed] will
/// have [GaitWalkingSpeedSummary.noHeight].
SessionQualitySummary computeSessionQualitySummary(
  SessionLog session, {
  double? userHeightCm,
  Set<String> locomotionLabels = defaultLocomotionLabels,
  int minStableLocomotionWindows = defaultStableLocomotionMinWindows,
  int minGaitCandidateWindows = defaultGaitCandidateMinWindows,
  Duration fallbackStepDuration = defaultPredictionStepDuration,
}) {
  assert(
    minStableLocomotionWindows > 0,
    'minStableLocomotionWindows must be positive',
  );
  assert(
    minGaitCandidateWindows > 0,
    'minGaitCandidateWindows must be positive',
  );
  assert(
    fallbackStepDuration > Duration.zero,
    'fallbackStepDuration must be positive',
  );

  final predictions = session.predictions;
  final effectiveCounts = <String, int>{};
  final rawCounts = <String, int>{};
  var changed = 0;

  for (final prediction in predictions) {
    effectiveCounts[prediction.label] =
        (effectiveCounts[prediction.label] ?? 0) + 1;
    rawCounts[prediction.rawLabel] = (rawCounts[prediction.rawLabel] ?? 0) + 1;
    if (prediction.wasSmoothed) changed++;
  }

  final stableLocomotionSegments = <StableLocomotionSegment>[];
  var runStart = -1;
  var runCounts = <String, int>{};

  void finishRun(int endIndexExclusive) {
    if (runStart < 0) return;

    final windows = endIndexExclusive - runStart;
    if (windows >= minStableLocomotionWindows) {
      final timeRange = predictionDisplayTimeRange(
        session,
        startIndex: runStart,
        endIndexExclusive: endIndexExclusive,
        fallbackStepDuration: fallbackStepDuration,
      );
      stableLocomotionSegments.add(
        StableLocomotionSegment(
          startIndex: runStart,
          endIndexExclusive: endIndexExclusive,
          windows: windows,
          startOffset: timeRange.startOffset,
          endOffset: timeRange.endOffset,
          effectiveLabelWindowCounts: Map.unmodifiable(runCounts),
        ),
      );
    }

    runStart = -1;
    runCounts = <String, int>{};
  }

  for (var i = 0; i < predictions.length; i++) {
    final label = predictions[i].label;
    if (locomotionLabels.contains(label)) {
      if (runStart < 0) {
        runStart = i;
        runCounts = <String, int>{};
      }
      runCounts[label] = (runCounts[label] ?? 0) + 1;
    } else {
      finishRun(i);
    }
  }
  finishRun(predictions.length);

  final stableWindowCount = stableLocomotionSegments.fold<int>(
    0,
    (sum, segment) => sum + segment.windows,
  );
  final stableDurationUs = stableLocomotionSegments.fold<int>(
    0,
    (sum, segment) => sum + segment.duration.inMicroseconds,
  );
  // Level-walking only: feeds walking-speed/step-length (level-gait model)
  // and the "Kandidati za analizu hoda" display.
  final gaitSegments = extractGaitSegments(
    session,
    minWindows: minGaitCandidateWindows,
    fallbackStepDuration: fallbackStepDuration,
  );
  final gaitSignalSegments = extractGaitSignalSegments(
    session,
    gaitSegments: gaitSegments,
  );

  // Broader than gaitSegments: step *counting* has no level-gait assumption
  // to protect, so stair runs contribute to cadence/step count even though
  // they're absent from gaitSegments and never feed walking-speed. See
  // defaultLocomotionLabels' doc comment (gait_segments.dart).
  final cadenceGaitSegments = extractGaitSegments(
    session,
    labels: defaultLocomotionLabels,
    minWindows: minGaitCandidateWindows,
    fallbackStepDuration: fallbackStepDuration,
  );
  final cadenceSignalSegments = extractGaitSignalSegments(
    session,
    gaitSegments: cadenceGaitSegments,
  );

  final gaitCadence = summarizeGaitCadence(cadenceSignalSegments);
  final gaitWalkingSpeed = userHeightCm != null
      ? summarizeGaitWalkingSpeed(
          gaitSignalSegments,
          cadenceResults: _cadenceResultsFor(gaitSignalSegments),
          userHeightCm: userHeightCm,
        )
      : const GaitWalkingSpeedSummary.noHeight();

  return SessionQualitySummary(
    predictionCount: predictions.length,
    rawSmoothedChangeCount: changed,
    rawSmoothedChangeFraction: predictions.isEmpty
        ? 0
        : changed / predictions.length,
    effectiveLabelWindowCounts: Map.unmodifiable(effectiveCounts),
    rawLabelWindowCounts: Map.unmodifiable(rawCounts),
    stableLocomotionSegments: List.unmodifiable(stableLocomotionSegments),
    stableLocomotionWindowCount: stableWindowCount,
    stableLocomotionDuration: Duration(microseconds: stableDurationUs),
    hasEnoughStableLocomotion: stableLocomotionSegments.isNotEmpty,
    gaitSegments: gaitSegments,
    gaitCadence: gaitCadence,
    gaitWalkingSpeed: gaitWalkingSpeed,
  );
}

/// Runs [analyzeGaitCadence] on each sampled segment and returns the results
/// in the same order as the sampled subset of [signalSegments]. Used internally
/// so [summarizeGaitWalkingSpeed] can reuse cadence values without recomputing.
List<GaitCadenceResult> _cadenceResultsFor(
  List<GaitSignalSegment> signalSegments,
) {
  return [
    for (final segment in signalSegments)
      if (segment.hasSamples) analyzeGaitCadence(segment),
  ];
}

/// Duration-weighted walking-speed and step-length summary across all suitable
/// gait signal segments.
///
/// [cadenceResults] must be the output of [_cadenceResultsFor] for the same
/// [signalSegments] — they are paired by index across sampled segments only.
GaitWalkingSpeedSummary summarizeGaitWalkingSpeed(
  List<GaitSignalSegment> signalSegments, {
  required List<GaitCadenceResult> cadenceResults,
  required double userHeightCm,
}) {
  if (signalSegments.isEmpty) {
    return const GaitWalkingSpeedSummary(
      signalSegmentCount: 0,
      computedResultCount: 0,
      averageWalkingSpeedMs: null,
      averageStepLengthM: null,
      status: GaitWalkingSpeedStatus.unavailable,
      reason: noSuitableCadenceSignalReason,
    );
  }

  final sampledSegments = [
    for (final s in signalSegments)
      if (s.hasSamples) s,
  ];

  assert(
    cadenceResults.length == sampledSegments.length,
    'cadenceResults must be aligned with sampled signalSegments',
  );

  final results = [
    for (var i = 0; i < sampledSegments.length; i++)
      analyzeGaitWalkingSpeed(
        sampledSegments[i],
        cadenceResult: cadenceResults[i],
        userHeightCm: userHeightCm,
      ),
  ];

  final computedResults = [
    for (final r in results)
      if (r.isComputed) r,
  ];

  if (computedResults.isEmpty) {
    return GaitWalkingSpeedSummary(
      signalSegmentCount: signalSegments.length,
      computedResultCount: 0,
      averageWalkingSpeedMs: null,
      averageStepLengthM: null,
      status: results.isEmpty
          ? GaitWalkingSpeedStatus.unavailable
          : results.first.status,
      reason: results.isEmpty
          ? noSuitableCadenceSignalReason
          : results.first.reason,
    );
  }

  // Duration-weighted averages — longer segments contribute proportionally
  // more, matching the weighting rule in summarizeGaitCadence.
  final totalDurationUs = sampledSegments
      .asMap()
      .entries
      .where((e) => results[e.key].isComputed)
      .fold<int>(
        0,
        (sum, e) => sum + e.value.gaitSegment.duration.inMicroseconds,
      );

  double weightedAverage(double Function(GaitWalkingSpeedResult) value) {
    if (totalDurationUs == 0) return 0;
    return sampledSegments
            .asMap()
            .entries
            .where((e) => results[e.key].isComputed)
            .fold<double>(
              0,
              (sum, e) =>
                  sum +
                  value(results[e.key]) *
                      e.value.gaitSegment.duration.inMicroseconds,
            ) /
        totalDurationUs;
  }

  return GaitWalkingSpeedSummary(
    signalSegmentCount: signalSegments.length,
    computedResultCount: computedResults.length,
    averageWalkingSpeedMs: weightedAverage((r) => r.walkingSpeedMs),
    averageStepLengthM: weightedAverage((r) => r.stepLengthM),
    status: GaitWalkingSpeedStatus.computed,
    reason: null,
  );
}

/// Croatian count agreement for the noun "prozor" (window).
String windowCountLabelHr(int count) {
  final ones = count % 10;
  final teens = count % 100;
  final noun = ones == 1 && teens != 11 ? 'prozor' : 'prozora';
  return '$count $noun';
}
