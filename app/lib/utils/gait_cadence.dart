import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:gait_sense/models/sensor_sample.dart';
import 'package:gait_sense/utils/gait_signal_segments.dart';

/// No samples were provided for cadence estimation.
const String emptyCadenceSignalReason = 'empty_signal';

/// The sample timestamps are not strictly increasing.
const String invalidCadenceTimestampsReason = 'invalid_timestamps';

/// The signal is shorter than the app-level cadence gate.
const String cadenceSignalTooShortReason = 'signal_too_short';

/// Peak picking found fewer steps than the app-level cadence gate.
const String tooFewCadencePeaksReason = 'too_few_detected_steps';

/// Autocorrelation did not provide enough periodic evidence.
const String lowCadencePeriodicityReason = 'low_periodicity';

/// Peak-based and period-based cadence estimates differ materially.
const String cadenceEstimatesDisagreeReason = 'cadence_estimates_disagree';

/// Too few repeated events were available for stronger confidence.
const String limitedCadenceEvidenceReason = 'limited_cadence_evidence';

/// App-level minimum duration before cadence analysis.
///
/// This threshold is a project heuristic and is not a clinically validated
/// minimum recording length.
const Duration defaultCadenceMinimumDuration = Duration(seconds: 2);

/// Low-pass cutoff used to retain the step-related signal component.
///
/// Susi, Renaudin, and Lachapelle, "Motion Mode Recognition and Step Detection
/// Algorithms for Mobile Phone Users", Sensors, 2013,
/// https://doi.org/10.3390/s130201539, use low-pass processing around 3 Hz.
/// This implementation uses a dependency-free fourth-order Butterworth filter
/// rather than the 10th-order design in that paper, so the order is a project
/// adaptation and not a clinically validated design choice.
const double defaultCadenceLowPassCutoffHz = 3;

/// Lower cadence-search bound used by autocorrelation.
///
/// This broad bound is a project heuristic, not a clinically validated limit.
const double defaultCadenceMinimumStepsPerMinute = 60;

/// Upper cadence-search bound used by autocorrelation.
///
/// This broad bound is a project heuristic, not a clinically validated limit.
const double defaultCadenceMaximumStepsPerMinute = 210;

/// Fraction of the dominant period required between accepted peaks.
///
/// This duplicate-peak suppression ratio is a project heuristic. The use of a
/// signal-derived period follows the periodicity-based cadence premise in Wu
/// and Urbanek, "Application of de-shape synchrosqueezing to estimate gait
/// cadence from a single-sensor accelerometer placed in different body
/// locations", Physiological Measurement, 2023,
/// https://doi.org/10.1088/1361-6579/accefe.
const double defaultCadenceMinimumPeakIntervalFraction = 0.75;

/// Adaptive peak threshold multiplier applied to the signal standard deviation.
///
/// Adaptive thresholds follow Susi et al. (2013),
/// https://doi.org/10.3390/s130201539. The value 0.5 is a project heuristic and
/// is not a clinically validated step-detection threshold.
const double defaultCadencePeakThresholdStdMultiplier = 0.5;

/// Preferred minimum autocorrelation for periodic evidence.
///
/// Values just below this gate can still be reported as low-confidence
/// estimates when peak evidence is available. That soft-reporting rule is a
/// project heuristic and is not clinically validated.
const double defaultCadenceMinimumPeriodicity = 0.2;

/// Fraction of the periodicity gate below which cadence is not reported.
///
/// This soft lower bound is a project heuristic: it prevents near-threshold
/// walking segments from disappearing while still rejecting very weakly
/// periodic signals.
const double defaultCadenceReportablePeriodicityFraction = 0.75;

/// Autocorrelation below this value lowers the confidence label.
///
/// This quality threshold is a project heuristic and is not clinically
/// validated.
const double defaultCadenceModeratePeriodicity = 0.35;

/// Autocorrelation required for the high-confidence label.
///
/// This quality threshold is a project heuristic and is not clinically
/// validated.
const double defaultCadenceHighPeriodicity = 0.55;

/// Relative disagreement that lowers confidence in the cadence estimate.
///
/// This comparison threshold is a project heuristic. Comparing peak and
/// periodicity estimates addresses the harmonic ambiguity discussed by Wu and
/// Urbanek (2023), https://doi.org/10.1088/1361-6579/accefe.
const double defaultCadenceMaximumEstimateDisagreement = 0.15;

/// Agreement threshold for promoting long low-periodicity estimates.
///
/// This internal-consistency rule is a project heuristic and is not clinically
/// validated.
const double defaultCadenceStrongEstimateAgreement = 0.05;

/// Minimum accepted peaks for the internal-consistency confidence rule.
///
/// This count is a project heuristic and is not clinically validated.
const int defaultCadenceConsistentEstimateMinimumSteps = 12;

/// Relative strength required to prefer a shorter autocorrelation maximum.
///
/// This harmonic-selection ratio is a project heuristic. Preferring the
/// shorter of similarly supported periods addresses the harmonic ambiguity
/// discussed by Wu and Urbanek (2023),
/// https://doi.org/10.1088/1361-6579/accefe.
const double defaultCadenceComparablePeriodicityRatio = 0.7;

/// App-level minimum number of detected peaks needed to report cadence.
///
/// This threshold is a project heuristic and is not a clinically validated
/// quality rule.
const int defaultCadenceMinimumDetectedSteps = 2;

/// Quality status for a cadence estimation attempt.
enum GaitCadenceStatus {
  /// Step count and cadence were computed.
  computed,

  /// The input sample list was empty.
  empty,

  /// The input did not contain enough usable signal.
  insufficientSignal,

  /// Sample timestamps were not suitable for duration-based cadence.
  invalidTimestamps,
}

/// Confidence label for an experimental cadence estimate.
enum GaitCadenceConfidence {
  /// The available evidence is weak or incomplete.
  low,

  /// Periodicity and peak evidence are mutually consistent.
  moderate,

  /// Strong periodicity and mutually consistent estimates were observed.
  high,
}

/// Step-count and cadence estimate derived from raw acceleration samples.
class GaitCadenceResult extends Equatable {
  /// Creates a cadence result.
  const GaitCadenceResult({
    required this.stepCount,
    required this.cadenceStepsPerMinute,
    required this.peakCadenceStepsPerMinute,
    required this.periodCadenceStepsPerMinute,
    required this.dominantPeriod,
    required this.periodicity,
    required this.adaptiveThreshold,
    required this.minimumPeakInterval,
    required this.duration,
    required this.detectedStepSampleIndices,
    required this.detectedStepOffsets,
    required this.status,
    required this.reason,
    required this.confidence,
    required this.confidenceReason,
  });

  /// Number of accepted acceleration peaks.
  final int stepCount;

  /// Peak-based cadence in steps per minute, or 0 when unavailable.
  final double cadenceStepsPerMinute;

  /// Cadence derived from the first-to-last accepted peak interval.
  final double? peakCadenceStepsPerMinute;

  /// Cadence derived from the dominant autocorrelation period.
  final double? periodCadenceStepsPerMinute;

  /// Dominant autocorrelation period, when one was identified.
  final Duration? dominantPeriod;

  /// Normalized autocorrelation at [dominantPeriod].
  final double? periodicity;

  /// Signal-adaptive amplitude threshold used for peak candidates.
  final double? adaptiveThreshold;

  /// Period-derived minimum interval used for peak suppression.
  final Duration? minimumPeakInterval;

  /// Signal duration from the first to the last raw sample timestamp.
  final Duration duration;

  /// Accepted peak indices.
  ///
  /// For [analyzeGaitCadence], indices are session-level when
  /// [GaitSignalSegment.startSampleIndex] is available; otherwise they are
  /// local to the provided sample list.
  final List<int> detectedStepSampleIndices;

  /// Accepted peak offsets from the first raw sample timestamp.
  final List<Duration> detectedStepOffsets;

  /// Availability status for this result.
  final GaitCadenceStatus status;

  /// Machine-readable reason when [status] is not
  /// [GaitCadenceStatus.computed].
  final String? reason;

  /// Experimental confidence label.
  final GaitCadenceConfidence confidence;

  /// Machine-readable reason for a low confidence label.
  final String? confidenceReason;

  /// Whether [stepCount] and [cadenceStepsPerMinute] are available outputs.
  bool get isComputed => status == GaitCadenceStatus.computed;

  @override
  List<Object?> get props => [
    stepCount,
    cadenceStepsPerMinute,
    peakCadenceStepsPerMinute,
    periodCadenceStepsPerMinute,
    dominantPeriod,
    periodicity,
    adaptiveThreshold,
    minimumPeakInterval,
    duration,
    detectedStepSampleIndices,
    detectedStepOffsets,
    status,
    reason,
    confidence,
    confidenceReason,
  ];
}

/// Temporal gait descriptors derived from accepted step-event timings.
///
/// Temporal gait analysis from acceleration signals is motivated by Zijlstra &
/// Hof, "Assessment of spatio-temporal gait parameters from trunk
/// accelerations during human walking", Gait & Posture, 2003,
/// https://doi.org/10.1016/S0966-6362(02)00190-X. The summary statistics here
/// are project display metrics computed from the app's experimental step
/// detector; they are not clinically validated.
class GaitTemporalParameters extends Equatable {
  /// Creates temporal gait parameters.
  const GaitTemporalParameters({
    required this.stepIntervalCount,
    required this.meanStepTime,
    required this.medianStepTime,
    required this.stepTimeStandardDeviation,
    required this.stepTimeCoefficientOfVariation,
    required this.minimumStepTime,
    required this.maximumStepTime,
    required this.meanInstantCadenceStepsPerMinute,
    required this.instantCadenceStandardDeviationStepsPerMinute,
    required this.instantCadenceCoefficientOfVariation,
    required this.gaitRegularity,
  });

  /// Number of consecutive step-to-step intervals used.
  final int stepIntervalCount;

  /// Mean duration between accepted consecutive steps.
  final Duration meanStepTime;

  /// Median duration between accepted consecutive steps.
  final Duration medianStepTime;

  /// Population standard deviation of step-to-step durations.
  final Duration stepTimeStandardDeviation;

  /// Step-time standard deviation divided by mean step time.
  ///
  /// This normalized variability metric is a project display rule and is not
  /// clinically validated.
  final double stepTimeCoefficientOfVariation;

  /// Shortest accepted step-to-step interval.
  final Duration minimumStepTime;

  /// Longest accepted step-to-step interval.
  final Duration maximumStepTime;

  /// Mean of per-interval cadence values.
  final double meanInstantCadenceStepsPerMinute;

  /// Population standard deviation of per-interval cadence values.
  final double instantCadenceStandardDeviationStepsPerMinute;

  /// Instant-cadence standard deviation divided by mean instant cadence.
  ///
  /// This normalized variability metric is a project display rule and is not
  /// clinically validated.
  final double instantCadenceCoefficientOfVariation;

  /// Autocorrelation-based regularity score inherited from cadence estimation.
  ///
  /// The periodicity-based interpretation follows Wu and Urbanek, "Application
  /// of de-shape synchrosqueezing to estimate gait cadence from a single-sensor
  /// accelerometer placed in different body locations", Physiological
  /// Measurement, 2023, https://doi.org/10.1088/1361-6579/accefe. The app-level
  /// score should be treated as an experimental signal-quality descriptor.
  final double? gaitRegularity;

  @override
  List<Object?> get props => [
    stepIntervalCount,
    meanStepTime,
    medianStepTime,
    stepTimeStandardDeviation,
    stepTimeCoefficientOfVariation,
    minimumStepTime,
    maximumStepTime,
    meanInstantCadenceStepsPerMinute,
    instantCadenceStandardDeviationStepsPerMinute,
    instantCadenceCoefficientOfVariation,
    gaitRegularity,
  ];
}

/// Computes temporal gait descriptors from one cadence result.
///
/// Intervals are calculated only between consecutive accepted peaks in the
/// same result. The statistics are app-level descriptors and are not clinically
/// validated.
GaitTemporalParameters? computeGaitTemporalParameters(
  GaitCadenceResult result,
) {
  if (!result.isComputed) return null;
  final intervalUs = _stepIntervalMicroseconds(result.detectedStepOffsets);
  return _temporalParametersFromIntervals(
    intervalUs,
    gaitRegularity: result.periodicity,
  );
}

/// Aggregates temporal descriptors across multiple cadence results.
///
/// Step intervals are pooled within each result, but no artificial interval is
/// created across gaps between separate gait segments. This aggregation is a
/// project display rule and is not clinically validated.
GaitTemporalParameters? summarizeGaitTemporalParameters(
  List<GaitCadenceResult> results,
) {
  final intervalUs = <int>[];
  var weightedRegularity = 0.0;
  var regularityWeight = 0;

  for (final result in results) {
    if (!result.isComputed) continue;
    final resultIntervals = _stepIntervalMicroseconds(
      result.detectedStepOffsets,
    );
    intervalUs.addAll(resultIntervals);

    final periodicity = result.periodicity;
    if (periodicity != null && resultIntervals.isNotEmpty) {
      weightedRegularity += periodicity * resultIntervals.length;
      regularityWeight += resultIntervals.length;
    }
  }

  return _temporalParametersFromIntervals(
    intervalUs,
    gaitRegularity: regularityWeight == 0
        ? null
        : weightedRegularity / regularityWeight,
  );
}

/// Estimates step count and cadence from `segment.samples`.
///
/// This helper uses only the segment samples and their timestamps. The
/// orientation-independent dynamic-acceleration magnitude follows the mobile
/// phone setting in Susi et al. (2013),
/// https://doi.org/10.3390/s130201539, and the front-pocket, orientation-robust
/// motivation in Gadaleta and Rossi, "IDNet: Smartphone-based Gait Recognition
/// with Convolutional Neural Networks", Pattern Recognition, 2018,
/// https://doi.org/10.1016/j.patcog.2017.09.005. This implementation is an
/// experimental project estimator and is not clinically validated.
GaitCadenceResult analyzeGaitCadence(
  GaitSignalSegment segment, {
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
  return analyzeGaitCadenceSamples(
    segment.samples,
    sampleIndexOffset: segment.startSampleIndex ?? 0,
    minimumDuration: minimumDuration,
    lowPassCutoffHz: lowPassCutoffHz,
    minimumCadenceStepsPerMinute: minimumCadenceStepsPerMinute,
    maximumCadenceStepsPerMinute: maximumCadenceStepsPerMinute,
    minimumPeakIntervalFraction: minimumPeakIntervalFraction,
    peakThresholdStdMultiplier: peakThresholdStdMultiplier,
    minimumPeriodicity: minimumPeriodicity,
    maximumEstimateDisagreement: maximumEstimateDisagreement,
    minimumDetectedSteps: minimumDetectedSteps,
  );
}

/// Estimates step count and cadence from raw, timestamped IMU samples.
///
/// Cadence is reported from the median accepted-peak interval, which is a
/// project heuristic. Autocorrelation supplies an independent period estimate
/// and the adaptive peak spacing. This dual estimate follows the periodicity
/// motivation and harmonic caution in Wu and Urbanek (2023),
/// https://doi.org/10.1088/1361-6579/accefe. Numeric quality gates not
/// attributed to that paper are explicitly project heuristics.
GaitCadenceResult analyzeGaitCadenceSamples(
  List<SensorSample> samples, {
  int sampleIndexOffset = 0,
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
  assert(sampleIndexOffset >= 0, 'sampleIndexOffset must not be negative');
  assert(minimumDuration > Duration.zero, 'minimumDuration must be positive');
  assert(lowPassCutoffHz > 0, 'lowPassCutoffHz must be positive');
  assert(
    minimumCadenceStepsPerMinute > 0,
    'minimumCadenceStepsPerMinute must be positive',
  );
  assert(
    maximumCadenceStepsPerMinute > minimumCadenceStepsPerMinute,
    'maximumCadenceStepsPerMinute must exceed the minimum',
  );
  assert(
    minimumPeakIntervalFraction > 0 && minimumPeakIntervalFraction <= 1,
    'minimumPeakIntervalFraction must be in (0, 1]',
  );
  assert(
    peakThresholdStdMultiplier >= 0,
    'peakThresholdStdMultiplier must not be negative',
  );
  assert(
    minimumPeriodicity >= 0 && minimumPeriodicity <= 1,
    'minimumPeriodicity must be in [0, 1]',
  );
  assert(
    maximumEstimateDisagreement >= 0,
    'maximumEstimateDisagreement must not be negative',
  );
  assert(minimumDetectedSteps > 1, 'minimumDetectedSteps must exceed one');

  if (samples.isEmpty) {
    return _notComputed(
      status: GaitCadenceStatus.empty,
      reason: emptyCadenceSignalReason,
    );
  }

  if (samples.length < 2) {
    return _notComputed(
      status: GaitCadenceStatus.insufficientSignal,
      reason: cadenceSignalTooShortReason,
    );
  }

  final duration = samples.last.timestamp.difference(samples.first.timestamp);
  if (duration <= Duration.zero || !_hasStrictlyIncreasingTimestamps(samples)) {
    return _notComputed(
      status: GaitCadenceStatus.invalidTimestamps,
      reason: invalidCadenceTimestampsReason,
    );
  }

  if (duration < minimumDuration) {
    return _notComputed(
      duration: duration,
      status: GaitCadenceStatus.insufficientSignal,
      reason: cadenceSignalTooShortReason,
    );
  }

  final magnitudes = [
    for (final sample in samples) _userAccelerationMagnitude(sample),
  ];
  final filtered = filterCadenceLowPassButterworth(
    samples,
    magnitudes,
    cutoffHz: lowPassCutoffHz,
  );
  final filteredMean = _mean(filtered);
  final filteredStd = _standardDeviation(filtered, filteredMean);
  final threshold = filteredMean + filteredStd * peakThresholdStdMultiplier;

  if (filteredStd <= 1e-9) {
    return _notComputed(
      duration: duration,
      adaptiveThreshold: threshold,
      status: GaitCadenceStatus.insufficientSignal,
      reason: tooFewCadencePeaksReason,
    );
  }

  final medianSampleInterval = _medianSampleInterval(samples);
  final periodEstimate = _estimateDominantPeriod(
    filtered,
    sampleInterval: medianSampleInterval,
    minimumCadenceStepsPerMinute: minimumCadenceStepsPerMinute,
    maximumCadenceStepsPerMinute: maximumCadenceStepsPerMinute,
  );
  if (periodEstimate == null) {
    return _notComputed(
      duration: duration,
      adaptiveThreshold: threshold,
      status: GaitCadenceStatus.insufficientSignal,
      reason: lowCadencePeriodicityReason,
    );
  }
  final reportablePeriodicity =
      minimumPeriodicity * defaultCadenceReportablePeriodicityFraction;
  if (periodEstimate.periodicity < reportablePeriodicity) {
    return _notComputed(
      duration: duration,
      dominantPeriod: periodEstimate.period,
      periodicity: periodEstimate.periodicity,
      adaptiveThreshold: threshold,
      status: GaitCadenceStatus.insufficientSignal,
      reason: lowCadencePeriodicityReason,
    );
  }

  final minimumPeakInterval = Duration(
    microseconds:
        (periodEstimate.period.inMicroseconds * minimumPeakIntervalFraction)
            .round(),
  );
  final peaks = _detectPeaks(
    samples,
    filtered,
    threshold: threshold,
    minimumPeakInterval: minimumPeakInterval,
  );
  final detectedStepSampleIndices = [
    for (final peak in peaks) sampleIndexOffset + peak.sampleIndex,
  ];
  final detectedStepOffsets = [
    for (final peak in peaks)
      samples[peak.sampleIndex].timestamp.difference(samples.first.timestamp),
  ];

  if (peaks.length < minimumDetectedSteps) {
    return GaitCadenceResult(
      stepCount: peaks.length,
      cadenceStepsPerMinute: 0,
      peakCadenceStepsPerMinute: null,
      periodCadenceStepsPerMinute: periodEstimate.cadenceStepsPerMinute,
      dominantPeriod: periodEstimate.period,
      periodicity: periodEstimate.periodicity,
      adaptiveThreshold: threshold,
      minimumPeakInterval: minimumPeakInterval,
      duration: duration,
      detectedStepSampleIndices: List.unmodifiable(detectedStepSampleIndices),
      detectedStepOffsets: List.unmodifiable(detectedStepOffsets),
      status: GaitCadenceStatus.insufficientSignal,
      reason: tooFewCadencePeaksReason,
      confidence: GaitCadenceConfidence.low,
      confidenceReason: limitedCadenceEvidenceReason,
    );
  }

  final firstPeakTime = samples[peaks.first.sampleIndex].timestamp;
  final lastPeakTime = samples[peaks.last.sampleIndex].timestamp;
  final peakSpan = lastPeakTime.difference(firstPeakTime);
  if (peakSpan <= Duration.zero) {
    return _notComputed(
      duration: duration,
      dominantPeriod: periodEstimate.period,
      periodicity: periodEstimate.periodicity,
      adaptiveThreshold: threshold,
      minimumPeakInterval: minimumPeakInterval,
      status: GaitCadenceStatus.invalidTimestamps,
      reason: invalidCadenceTimestampsReason,
    );
  }

  final medianPeakInterval = _medianPeakInterval(samples, peaks);
  final peakCadence =
      Duration.microsecondsPerMinute / medianPeakInterval.inMicroseconds;
  final periodCadence = periodEstimate.cadenceStepsPerMinute;
  final disagreement = (peakCadence - periodCadence).abs() / periodCadence;
  final confidenceAssessment = _assessConfidence(
    peakCount: peaks.length,
    periodicity: periodEstimate.periodicity,
    estimateDisagreement: disagreement,
    minimumPeriodicity: minimumPeriodicity,
    reportablePeriodicity: reportablePeriodicity,
    maximumEstimateDisagreement: maximumEstimateDisagreement,
  );

  return GaitCadenceResult(
    stepCount: peaks.length,
    cadenceStepsPerMinute: peakCadence,
    peakCadenceStepsPerMinute: peakCadence,
    periodCadenceStepsPerMinute: periodCadence,
    dominantPeriod: periodEstimate.period,
    periodicity: periodEstimate.periodicity,
    adaptiveThreshold: threshold,
    minimumPeakInterval: minimumPeakInterval,
    duration: duration,
    detectedStepSampleIndices: List.unmodifiable(detectedStepSampleIndices),
    detectedStepOffsets: List.unmodifiable(detectedStepOffsets),
    status: GaitCadenceStatus.computed,
    reason: null,
    confidence: confidenceAssessment.confidence,
    confidenceReason: confidenceAssessment.reason,
  );
}

GaitCadenceResult _notComputed({
  required GaitCadenceStatus status,
  required String reason,
  Duration duration = Duration.zero,
  Duration? dominantPeriod,
  double? periodicity,
  double? adaptiveThreshold,
  Duration? minimumPeakInterval,
}) {
  return GaitCadenceResult(
    stepCount: 0,
    cadenceStepsPerMinute: 0,
    peakCadenceStepsPerMinute: null,
    periodCadenceStepsPerMinute: dominantPeriod == null
        ? null
        : Duration.microsecondsPerMinute / dominantPeriod.inMicroseconds,
    dominantPeriod: dominantPeriod,
    periodicity: periodicity,
    adaptiveThreshold: adaptiveThreshold,
    minimumPeakInterval: minimumPeakInterval,
    duration: duration,
    detectedStepSampleIndices: const [],
    detectedStepOffsets: const [],
    status: status,
    reason: reason,
    confidence: GaitCadenceConfidence.low,
    confidenceReason: reason,
  );
}

List<int> _stepIntervalMicroseconds(List<Duration> stepOffsets) {
  final intervalUs = <int>[];
  for (var i = 1; i < stepOffsets.length; i++) {
    final interval = stepOffsets[i] - stepOffsets[i - 1];
    if (interval > Duration.zero) {
      intervalUs.add(interval.inMicroseconds);
    }
  }
  return intervalUs;
}

GaitTemporalParameters? _temporalParametersFromIntervals(
  List<int> intervalUs, {
  required double? gaitRegularity,
}) {
  if (intervalUs.isEmpty) return null;

  final intervalValues = [
    for (final interval in intervalUs) interval.toDouble(),
  ];
  final meanIntervalUs = _mean(intervalValues);
  if (meanIntervalUs <= 0) return null;

  final stepTimeStdUs = _standardDeviation(intervalValues, meanIntervalUs);
  final instantCadenceValues = [
    for (final interval in intervalUs)
      Duration.microsecondsPerMinute / interval,
  ];
  final meanInstantCadence = _mean(instantCadenceValues);
  final instantCadenceStd = _standardDeviation(
    instantCadenceValues,
    meanInstantCadence,
  );

  return GaitTemporalParameters(
    stepIntervalCount: intervalUs.length,
    meanStepTime: _durationFromMicroseconds(meanIntervalUs),
    medianStepTime: _durationFromMicroseconds(_medianNumeric(intervalValues)),
    stepTimeStandardDeviation: _durationFromMicroseconds(stepTimeStdUs),
    stepTimeCoefficientOfVariation: stepTimeStdUs / meanIntervalUs,
    minimumStepTime: Duration(microseconds: intervalUs.reduce(math.min)),
    maximumStepTime: Duration(microseconds: intervalUs.reduce(math.max)),
    meanInstantCadenceStepsPerMinute: meanInstantCadence,
    instantCadenceStandardDeviationStepsPerMinute: instantCadenceStd,
    instantCadenceCoefficientOfVariation: meanInstantCadence <= 0
        ? 0
        : instantCadenceStd / meanInstantCadence,
    gaitRegularity: gaitRegularity,
  );
}

Duration _durationFromMicroseconds(double microseconds) {
  return Duration(microseconds: microseconds.round());
}

double _medianNumeric(List<double> values) {
  final sorted = List<double>.of(values)..sort();
  final middle = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[middle]
      : (sorted[middle - 1] + sorted[middle]) / 2;
}

bool _hasStrictlyIncreasingTimestamps(List<SensorSample> samples) {
  for (var i = 1; i < samples.length; i++) {
    final delta = samples[i].timestamp.difference(samples[i - 1].timestamp);
    if (delta <= Duration.zero) return false;
  }
  return true;
}

double _userAccelerationMagnitude(SensorSample sample) {
  final value = math.sqrt(
    sample.userAccelerationX * sample.userAccelerationX +
        sample.userAccelerationY * sample.userAccelerationY +
        sample.userAccelerationZ * sample.userAccelerationZ,
  );
  return value.isFinite ? value : 0;
}

/// Applies the Butterworth low-pass preprocessing motivated by Susi et al.
/// (2013), https://doi.org/10.3390/s130201539.
///
/// The paper uses a 10th-order Butterworth filter at 3 Hz for step detection.
/// This app uses a fourth-order second-order-section cascade and a
/// forward/backward pass as a dependency-free project adaptation. The
/// Butterworth filter family follows Butterworth, "On the Theory of Filter
/// Amplifiers", Experimental Wireless & the Wireless Engineer, 1930.
///
/// This function is intentionally public so numerical tests and offline
/// diagnostics can verify the same filter used by [analyzeGaitCadenceSamples].
/// The filtering approach is motivated by Susi et al. (2013),
/// https://doi.org/10.3390/s130201539, with the project adaptation described
/// above.
List<double> filterCadenceLowPassButterworth(
  List<SensorSample> samples,
  List<double> values, {
  required double cutoffHz,
}) {
  assert(
    samples.length == values.length,
    'samples and values must have the same length',
  );
  if (values.length < 2) return List.of(values);

  final sampleInterval = _medianSampleInterval(samples);
  if (sampleInterval <= Duration.zero) return List.of(values);

  final sampleRateHz =
      Duration.microsecondsPerSecond / sampleInterval.inMicroseconds;
  if (!sampleRateHz.isFinite || sampleRateHz <= 0) return List.of(values);

  final nyquistHz = sampleRateHz / 2;
  final boundedCutoffHz = math.min(cutoffHz, nyquistHz * 0.95);
  if (boundedCutoffHz <= 0) return List.of(values);

  final sections = _butterworthFourthOrderLowPassSections(
    cutoffHz: boundedCutoffHz,
    sampleRateHz: sampleRateHz,
  );
  final forward = _applyBiquadCascade(values, sections);
  final backwardInput = forward.reversed.toList(growable: false);
  final backward = _applyBiquadCascade(backwardInput, sections);

  return backward.reversed.toList(growable: false);
}

List<_BiquadCoefficients> _butterworthFourthOrderLowPassSections({
  required double cutoffHz,
  required double sampleRateHz,
}) {
  return [
    _lowPassBiquad(
      cutoffHz: cutoffHz,
      sampleRateHz: sampleRateHz,
      qualityFactor: 0.541196100146197,
    ),
    _lowPassBiquad(
      cutoffHz: cutoffHz,
      sampleRateHz: sampleRateHz,
      qualityFactor: 1.3065629648763766,
    ),
  ];
}

_BiquadCoefficients _lowPassBiquad({
  required double cutoffHz,
  required double sampleRateHz,
  required double qualityFactor,
}) {
  final omega = 2 * math.pi * cutoffHz / sampleRateHz;
  final sinOmega = math.sin(omega);
  final cosOmega = math.cos(omega);
  final alpha = sinOmega / (2 * qualityFactor);
  final b0 = (1 - cosOmega) / 2;
  final b1 = 1 - cosOmega;
  final b2 = (1 - cosOmega) / 2;
  final a0 = 1 + alpha;
  final a1 = -2 * cosOmega;
  final a2 = 1 - alpha;

  return _BiquadCoefficients(
    b0: b0 / a0,
    b1: b1 / a0,
    b2: b2 / a0,
    a1: a1 / a0,
    a2: a2 / a0,
  );
}

List<double> _applyBiquadCascade(
  List<double> values,
  List<_BiquadCoefficients> sections,
) {
  var filtered = List<double>.of(values, growable: false);
  for (final section in sections) {
    filtered = _applyBiquad(filtered, section);
  }
  return filtered;
}

List<double> _applyBiquad(
  List<double> values,
  _BiquadCoefficients coefficients,
) {
  final filtered = List<double>.filled(values.length, 0);
  var z1 = 0.0;
  var z2 = 0.0;
  for (var i = 0; i < values.length; i++) {
    final input = values[i];
    final output = coefficients.b0 * input + z1;
    z1 = coefficients.b1 * input - coefficients.a1 * output + z2;
    z2 = coefficients.b2 * input - coefficients.a2 * output;
    filtered[i] = output.isFinite ? output : 0;
  }
  return filtered;
}

Duration _medianSampleInterval(List<SensorSample> samples) {
  final intervals = [
    for (var i = 1; i < samples.length; i++)
      samples[i].timestamp.difference(samples[i - 1].timestamp).inMicroseconds,
  ]..sort();
  final middle = intervals.length ~/ 2;
  final median = intervals.length.isOdd
      ? intervals[middle]
      : ((intervals[middle - 1] + intervals[middle]) / 2).round();
  return Duration(microseconds: median);
}

Duration _medianPeakInterval(List<SensorSample> samples, List<_Peak> peaks) {
  final intervals = [
    for (var i = 1; i < peaks.length; i++)
      samples[peaks[i].sampleIndex].timestamp
          .difference(samples[peaks[i - 1].sampleIndex].timestamp)
          .inMicroseconds,
  ]..sort();
  final middle = intervals.length ~/ 2;
  final median = intervals.length.isOdd
      ? intervals[middle]
      : ((intervals[middle - 1] + intervals[middle]) / 2).round();
  return Duration(microseconds: median);
}

_PeriodEstimate? _estimateDominantPeriod(
  List<double> values, {
  required Duration sampleInterval,
  required double minimumCadenceStepsPerMinute,
  required double maximumCadenceStepsPerMinute,
}) {
  if (values.length < 3 || sampleInterval <= Duration.zero) return null;

  final sampleSeconds =
      sampleInterval.inMicroseconds / Duration.microsecondsPerSecond;
  final minimumPeriodSeconds = 60 / maximumCadenceStepsPerMinute;
  final maximumPeriodSeconds = 60 / minimumCadenceStepsPerMinute;
  final minimumLag = math.max(2, (minimumPeriodSeconds / sampleSeconds).ceil());
  final maximumLag = math.min(
    values.length - 2,
    (maximumPeriodSeconds / sampleSeconds).floor(),
  );
  if (maximumLag <= minimumLag) return null;

  final mean = _mean(values);
  final centered = [for (final value in values) value - mean];
  final correlations = <int, double>{};
  for (var lag = minimumLag; lag <= maximumLag; lag++) {
    var product = 0.0;
    var leftEnergy = 0.0;
    var rightEnergy = 0.0;
    for (var i = 0; i + lag < centered.length; i++) {
      final left = centered[i];
      final right = centered[i + lag];
      product += left * right;
      leftEnergy += left * left;
      rightEnergy += right * right;
    }
    final normalization = math.sqrt(leftEnergy * rightEnergy);
    correlations[lag] = normalization <= 0 ? 0 : product / normalization;
  }

  final localMaxima = <MapEntry<int, double>>[];
  for (var lag = minimumLag + 1; lag < maximumLag; lag++) {
    final previous = correlations[lag - 1]!;
    final current = correlations[lag]!;
    final next = correlations[lag + 1]!;
    if (current > previous && current >= next) {
      localMaxima.add(MapEntry(lag, current));
    }
  }

  final candidates = localMaxima.isEmpty
      ? correlations.entries.toList()
      : localMaxima;
  final strongestCorrelation = candidates
      .map((entry) => entry.value)
      .reduce(math.max);
  final comparableCorrelation =
      strongestCorrelation * defaultCadenceComparablePeriodicityRatio;
  final selected = candidates
      .where((entry) => entry.value >= comparableCorrelation)
      .reduce((earlier, entry) => entry.key < earlier.key ? entry : earlier);
  final bestLag = selected.key;
  final bestCorrelation = selected.value;
  if (!bestCorrelation.isFinite) {
    return null;
  }

  final period = Duration(
    microseconds: sampleInterval.inMicroseconds * bestLag,
  );
  return _PeriodEstimate(
    period: period,
    periodicity: bestCorrelation.clamp(0, 1).toDouble(),
  );
}

List<_Peak> _detectPeaks(
  List<SensorSample> samples,
  List<double> values, {
  required double threshold,
  required Duration minimumPeakInterval,
}) {
  final candidates = <_Peak>[];
  for (var i = 1; i < values.length - 1; i++) {
    if (values[i] > values[i - 1] &&
        values[i] >= values[i + 1] &&
        values[i] >= threshold) {
      candidates.add(_Peak(sampleIndex: i, value: values[i]));
    }
  }

  final strongestFirst = List<_Peak>.of(candidates)
    ..sort((a, b) {
      final byValue = b.value.compareTo(a.value);
      return byValue != 0 ? byValue : a.sampleIndex.compareTo(b.sampleIndex);
    });
  final accepted = <_Peak>[];
  for (final candidate in strongestFirst) {
    final isSeparated = accepted.every((peak) {
      final delta = samples[candidate.sampleIndex].timestamp
          .difference(samples[peak.sampleIndex].timestamp)
          .abs();
      return delta >= minimumPeakInterval;
    });
    if (isSeparated) accepted.add(candidate);
  }
  accepted.sort((a, b) => a.sampleIndex.compareTo(b.sampleIndex));
  return accepted;
}

_ConfidenceAssessment _assessConfidence({
  required int peakCount,
  required double periodicity,
  required double estimateDisagreement,
  required double minimumPeriodicity,
  required double reportablePeriodicity,
  required double maximumEstimateDisagreement,
}) {
  final hasStrongInternalConsistency =
      peakCount >= defaultCadenceConsistentEstimateMinimumSteps &&
      periodicity >= reportablePeriodicity &&
      estimateDisagreement <= defaultCadenceStrongEstimateAgreement;

  if (periodicity < minimumPeriodicity && !hasStrongInternalConsistency) {
    return const _ConfidenceAssessment(
      confidence: GaitCadenceConfidence.low,
      reason: lowCadencePeriodicityReason,
    );
  }
  if (estimateDisagreement > maximumEstimateDisagreement) {
    return const _ConfidenceAssessment(
      confidence: GaitCadenceConfidence.low,
      reason: cadenceEstimatesDisagreeReason,
    );
  }
  if (periodicity < defaultCadenceModeratePeriodicity &&
      !hasStrongInternalConsistency) {
    return const _ConfidenceAssessment(
      confidence: GaitCadenceConfidence.low,
      reason: lowCadencePeriodicityReason,
    );
  }
  if (peakCount < 4) {
    return const _ConfidenceAssessment(
      confidence: GaitCadenceConfidence.low,
      reason: limitedCadenceEvidenceReason,
    );
  }
  if (periodicity >= minimumPeriodicity &&
      periodicity >= defaultCadenceHighPeriodicity &&
      estimateDisagreement <= maximumEstimateDisagreement * 2 / 3 &&
      peakCount >= 6) {
    return const _ConfidenceAssessment(
      confidence: GaitCadenceConfidence.high,
      reason: null,
    );
  }
  return const _ConfidenceAssessment(
    confidence: GaitCadenceConfidence.moderate,
    reason: null,
  );
}

double _mean(List<double> values) {
  if (values.isEmpty) return 0;
  return values.reduce((a, b) => a + b) / values.length;
}

double _standardDeviation(List<double> values, double mean) {
  if (values.isEmpty) return 0;
  final variance =
      values
          .map((value) => math.pow(value - mean, 2).toDouble())
          .reduce((a, b) => a + b) /
      values.length;
  return math.sqrt(variance);
}

class _PeriodEstimate {
  const _PeriodEstimate({
    required this.period,
    required this.periodicity,
  });

  final Duration period;
  final double periodicity;

  double get cadenceStepsPerMinute =>
      Duration.microsecondsPerMinute / period.inMicroseconds;
}

class _ConfidenceAssessment {
  const _ConfidenceAssessment({
    required this.confidence,
    required this.reason,
  });

  final GaitCadenceConfidence confidence;
  final String? reason;
}

class _BiquadCoefficients {
  const _BiquadCoefficients({
    required this.b0,
    required this.b1,
    required this.b2,
    required this.a1,
    required this.a2,
  });

  final double b0;
  final double b1;
  final double b2;
  final double a1;
  final double a2;
}

class _Peak {
  const _Peak({
    required this.sampleIndex,
    required this.value,
  });

  final int sampleIndex;
  final double value;
}
