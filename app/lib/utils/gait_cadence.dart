import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:gait_sense/models/sensor_sample.dart';
import 'package:gait_sense/utils/basic_statistics.dart' as stats;
import 'package:gait_sense/utils/butterworth_filter.dart';
import 'package:gait_sense/utils/gait_cadence_constants.dart';
import 'package:gait_sense/utils/gait_signal_segments.dart';

export 'package:gait_sense/utils/butterworth_filter.dart';
export 'package:gait_sense/utils/gait_cadence_constants.dart';

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
/// and the adaptive peak spacing; cross-checking the two is itself a project
/// construct, motivated by -- but not sourced from -- the harmonic-ambiguity
/// concern Wu and Urbanek (2023),
/// https://doi.org/10.1088/1361-6579/accefe, raise for cadence estimation.
/// Numeric quality gates not attributed to that paper are explicitly project
/// heuristics.
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

  final sampleInterval = medianSampleInterval(samples);
  final reportablePeriodicity =
      minimumPeriodicity * defaultCadenceReportablePeriodicityFraction;
  final candidates = [
    _analyzeCadenceSignal(
      samples,
      signal: _CadenceSignal.userAccelerationMagnitude,
      sampleIndexOffset: sampleIndexOffset,
      duration: duration,
      medianSampleInterval: sampleInterval,
      lowPassCutoffHz: lowPassCutoffHz,
      minimumCadenceStepsPerMinute: minimumCadenceStepsPerMinute,
      maximumCadenceStepsPerMinute: maximumCadenceStepsPerMinute,
      minimumPeakIntervalFraction: minimumPeakIntervalFraction,
      peakThresholdStdMultiplier: peakThresholdStdMultiplier,
      minimumPeriodicity: minimumPeriodicity,
      reportablePeriodicity: reportablePeriodicity,
      maximumEstimateDisagreement: maximumEstimateDisagreement,
      minimumDetectedSteps: minimumDetectedSteps,
    ),
    _analyzeCadenceSignal(
      samples,
      signal: _CadenceSignal.angularVelocityMagnitude,
      sampleIndexOffset: sampleIndexOffset,
      duration: duration,
      medianSampleInterval: sampleInterval,
      lowPassCutoffHz: lowPassCutoffHz,
      minimumCadenceStepsPerMinute: minimumCadenceStepsPerMinute,
      maximumCadenceStepsPerMinute: maximumCadenceStepsPerMinute,
      minimumPeakIntervalFraction: minimumPeakIntervalFraction,
      peakThresholdStdMultiplier: peakThresholdStdMultiplier,
      minimumPeriodicity: minimumPeriodicity,
      reportablePeriodicity: reportablePeriodicity,
      maximumEstimateDisagreement: maximumEstimateDisagreement,
      minimumDetectedSteps: minimumDetectedSteps,
    ),
  ];

  return _selectCadenceCandidate(candidates).result;
}

_CadenceCandidate _analyzeCadenceSignal(
  List<SensorSample> samples, {
  required _CadenceSignal signal,
  required int sampleIndexOffset,
  required Duration duration,
  required Duration medianSampleInterval,
  required double lowPassCutoffHz,
  required double minimumCadenceStepsPerMinute,
  required double maximumCadenceStepsPerMinute,
  required double minimumPeakIntervalFraction,
  required double peakThresholdStdMultiplier,
  required double minimumPeriodicity,
  required double reportablePeriodicity,
  required double maximumEstimateDisagreement,
  required int minimumDetectedSteps,
}) {
  final magnitudes = [
    for (final sample in samples) _cadenceSignalValue(sample, signal),
  ];
  final filtered = filterCadenceLowPassButterworth(
    samples,
    magnitudes,
    cutoffHz: lowPassCutoffHz,
  );
  final filteredMean = stats.mean(filtered);
  final filteredStd = stats.standardDeviation(filtered, filteredMean);
  final threshold = filteredMean + filteredStd * peakThresholdStdMultiplier;

  if (filteredStd <= 1e-9) {
    return _CadenceCandidate(
      signal: signal,
      result: _notComputed(
        duration: duration,
        adaptiveThreshold: threshold,
        status: GaitCadenceStatus.insufficientSignal,
        reason: tooFewCadencePeaksReason,
      ),
      isBoundaryArtifact: false,
    );
  }

  final periodEstimate = _estimateDominantPeriod(
    filtered,
    sampleInterval: medianSampleInterval,
    minimumCadenceStepsPerMinute: minimumCadenceStepsPerMinute,
    maximumCadenceStepsPerMinute: maximumCadenceStepsPerMinute,
  );
  if (periodEstimate == null) {
    return _CadenceCandidate(
      signal: signal,
      result: _notComputed(
        duration: duration,
        adaptiveThreshold: threshold,
        status: GaitCadenceStatus.insufficientSignal,
        reason: lowCadencePeriodicityReason,
      ),
      isBoundaryArtifact: false,
    );
  }
  if (periodEstimate.periodicity < reportablePeriodicity) {
    return _CadenceCandidate(
      signal: signal,
      result: _notComputed(
        duration: duration,
        dominantPeriod: periodEstimate.period,
        periodicity: periodEstimate.periodicity,
        adaptiveThreshold: threshold,
        status: GaitCadenceStatus.insufficientSignal,
        reason: lowCadencePeriodicityReason,
      ),
      isBoundaryArtifact: periodEstimate.isBoundaryArtifact,
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
    return _CadenceCandidate(
      signal: signal,
      result: GaitCadenceResult(
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
      ),
      isBoundaryArtifact: periodEstimate.isBoundaryArtifact,
    );
  }

  final firstPeakTime = samples[peaks.first.sampleIndex].timestamp;
  final lastPeakTime = samples[peaks.last.sampleIndex].timestamp;
  final peakSpan = lastPeakTime.difference(firstPeakTime);
  if (peakSpan <= Duration.zero) {
    return _CadenceCandidate(
      signal: signal,
      result: _notComputed(
        duration: duration,
        dominantPeriod: periodEstimate.period,
        periodicity: periodEstimate.periodicity,
        adaptiveThreshold: threshold,
        minimumPeakInterval: minimumPeakInterval,
        status: GaitCadenceStatus.invalidTimestamps,
        reason: invalidCadenceTimestampsReason,
      ),
      isBoundaryArtifact: periodEstimate.isBoundaryArtifact,
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

  return _CadenceCandidate(
    signal: signal,
    result: GaitCadenceResult(
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
    ),
    isBoundaryArtifact: periodEstimate.isBoundaryArtifact,
  );
}

_CadenceCandidate _selectCadenceCandidate(List<_CadenceCandidate> candidates) {
  final computed = [
    for (final candidate in candidates)
      if (candidate.result.isComputed) candidate,
  ];
  if (computed.isEmpty) {
    return candidates.first;
  }

  return computed.reduce(_betterCadenceCandidate);
}

_CadenceCandidate _betterCadenceCandidate(
  _CadenceCandidate left,
  _CadenceCandidate right,
) {
  if (left.isBoundaryArtifact != right.isBoundaryArtifact) {
    // A still-rising boundary correlation means the search range may have
    // truncated the true peak -- weaker evidence than a candidate whose
    // period is an interior local maximum the search actually observed
    // peaking, regardless of which raw correlation value is higher. Project
    // heuristic, not from Wu and Urbanek (2023); see the doc comment on
    // `_PeriodEstimate.isBoundaryArtifact` for the mechanism this responds
    // to (a fast-paced-walking undercount traced to this exact tie-break).
    return left.isBoundaryArtifact ? right : left;
  }

  final leftResult = left.result;
  final rightResult = right.result;
  final byConfidence =
      _confidenceRank(leftResult.confidence) -
      _confidenceRank(rightResult.confidence);
  if (byConfidence != 0) return byConfidence > 0 ? left : right;

  final leftPeriodicity = leftResult.periodicity ?? 0;
  final rightPeriodicity = rightResult.periodicity ?? 0;
  final periodicityDifference = leftPeriodicity - rightPeriodicity;
  if (periodicityDifference.abs() > 0.05) {
    return periodicityDifference > 0 ? left : right;
  }

  final leftDisagreement = _cadenceEstimateDisagreement(leftResult);
  final rightDisagreement = _cadenceEstimateDisagreement(rightResult);
  final disagreementDifference = leftDisagreement - rightDisagreement;
  if (disagreementDifference.abs() > 0.05) {
    return disagreementDifference < 0 ? left : right;
  }

  if (left.signal == _CadenceSignal.userAccelerationMagnitude) return left;
  if (right.signal == _CadenceSignal.userAccelerationMagnitude) return right;
  return left;
}

int _confidenceRank(GaitCadenceConfidence confidence) {
  return switch (confidence) {
    GaitCadenceConfidence.low => 0,
    GaitCadenceConfidence.moderate => 1,
    GaitCadenceConfidence.high => 2,
  };
}

double _cadenceEstimateDisagreement(GaitCadenceResult result) {
  final peakCadence = result.peakCadenceStepsPerMinute;
  final periodCadence = result.periodCadenceStepsPerMinute;
  if (peakCadence == null || periodCadence == null || periodCadence <= 0) {
    return double.infinity;
  }
  return (peakCadence - periodCadence).abs() / periodCadence;
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

double _angularVelocityMagnitude(SensorSample sample) {
  final value = math.sqrt(
    sample.rotationRateX * sample.rotationRateX +
        sample.rotationRateY * sample.rotationRateY +
        sample.rotationRateZ * sample.rotationRateZ,
  );
  return value.isFinite ? value : 0;
}

double _cadenceSignalValue(SensorSample sample, _CadenceSignal signal) {
  return switch (signal) {
    _CadenceSignal.userAccelerationMagnitude => _userAccelerationMagnitude(
      sample,
    ),
    _CadenceSignal.angularVelocityMagnitude => _angularVelocityMagnitude(
      sample,
    ),
  };
}

Duration _medianPeakInterval(List<SensorSample> samples, List<_Peak> peaks) {
  final intervals = [
    for (var i = 1; i < peaks.length; i++)
      samples[peaks[i].sampleIndex].timestamp
          .difference(samples[peaks[i - 1].sampleIndex].timestamp)
          .inMicroseconds
          .toDouble(),
  ];
  return Duration(microseconds: stats.median(intervals).round());
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

  final mean = stats.mean(values);
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
  final maximumBoundary = correlations[maximumLag]!;
  final boundaryAdded = maximumBoundary > correlations[maximumLag - 1]!;
  if (boundaryAdded) {
    localMaxima.add(MapEntry(maximumLag, maximumBoundary));
  }

  final preferredCandidates = localMaxima
      .where((entry) => entry.value.isFinite && entry.value > 0)
      .toList(growable: false);
  final usableCandidates = preferredCandidates.isEmpty
      ? correlations.entries
            .where((entry) => entry.value.isFinite && entry.value > 0)
            .toList(growable: false)
      : preferredCandidates;
  if (usableCandidates.isEmpty) {
    return null;
  }

  final strongestCorrelation = usableCandidates
      .map((entry) => entry.value)
      .reduce(math.max);
  final comparableCorrelation =
      strongestCorrelation * defaultCadenceComparablePeriodicityRatio;
  final selected = usableCandidates
      .where((entry) => entry.value >= comparableCorrelation)
      .reduce((earlier, entry) => entry.key < earlier.key ? entry : earlier);
  final bestLag = selected.key;
  final bestCorrelation = selected.value;

  final period = Duration(
    microseconds: sampleInterval.inMicroseconds * bestLag,
  );
  return _PeriodEstimate(
    period: period,
    periodicity: bestCorrelation.clamp(0, 1).toDouble(),
    isBoundaryArtifact: boundaryAdded && bestLag == maximumLag,
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

class _PeriodEstimate {
  const _PeriodEstimate({
    required this.period,
    required this.periodicity,
    required this.isBoundaryArtifact,
  });

  final Duration period;
  final double periodicity;

  /// Whether [period] was selected only because correlation was still
  /// rising at the search range's longest lag (see [_estimateDominantPeriod]).
  final bool isBoundaryArtifact;

  double get cadenceStepsPerMinute =>
      Duration.microsecondsPerMinute / period.inMicroseconds;
}

enum _CadenceSignal {
  userAccelerationMagnitude,
  angularVelocityMagnitude,
}

class _CadenceCandidate {
  const _CadenceCandidate({
    required this.signal,
    required this.result,
    required this.isBoundaryArtifact,
  });

  final _CadenceSignal signal;
  final GaitCadenceResult result;

  /// Mirrors [_PeriodEstimate.isBoundaryArtifact] for whichever period
  /// estimate produced [result]; `false` when no period estimate was
  /// reached at all (e.g. [GaitCadenceStatus.insufficientSignal] before
  /// autocorrelation ran).
  final bool isBoundaryArtifact;
}

class _ConfidenceAssessment {
  const _ConfidenceAssessment({
    required this.confidence,
    required this.reason,
  });

  final GaitCadenceConfidence confidence;
  final String? reason;
}

class _Peak {
  const _Peak({
    required this.sampleIndex,
    required this.value,
  });

  final int sampleIndex;
  final double value;
}
