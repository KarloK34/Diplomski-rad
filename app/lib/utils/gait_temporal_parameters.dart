import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:gait_sense/utils/basic_statistics.dart' as stats;
import 'package:gait_sense/utils/gait_cadence.dart';

/// Lower median-relative interval bound used for temporal variability.
///
/// This project quality rule reduces the influence of isolated duplicate peak
/// detections on temporal descriptors. It is not a clinically validated gait
/// variability filter.
const double defaultTemporalIntervalLowerMedianRatio = 0.5;

/// Upper median-relative interval bound used for temporal variability.
///
/// This project quality rule reduces the influence of missed peak detections
/// on temporal descriptors. Zijlstra & Hof (2003),
/// https://doi.org/10.1016/S0966-6362(02)00190-X, emphasize that temporal gait
/// parameters depend on correctly identified subsequent gait events; this app
/// treats the ratio itself as an unvalidated robustness guard.
const double defaultTemporalIntervalUpperMedianRatio = 1.5;

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
    required this.strideIntervalCount,
    required this.meanStrideTime,
    required this.strideTimeStandardDeviation,
    required this.strideTimeCoefficientOfVariation,
    required this.meanInstantCadenceStepsPerMinute,
    required this.instantCadenceStandardDeviationStepsPerMinute,
    required this.instantCadenceCoefficientOfVariation,
    required this.gaitRegularity,
  });

  /// Number of consecutive step-to-step intervals used after consistency
  /// filtering.
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

  /// Number of same-side step-event intervals used for stride timing after
  /// consistency filtering.
  ///
  /// With one phone in the pocket the app does not label left/right foot
  /// contacts. The stride interval is therefore approximated as the interval
  /// between every second accepted step event, following the stride-cycle
  /// timing premise in Zijlstra & Hof (2003),
  /// https://doi.org/10.1016/S0966-6362(02)00190-X.
  final int strideIntervalCount;

  /// Mean duration between every second accepted step event.
  final Duration? meanStrideTime;

  /// Population standard deviation of stride-time durations.
  final Duration? strideTimeStandardDeviation;

  /// Stride-time standard deviation divided by mean stride time.
  ///
  /// This normalized variability metric is a project display rule and is not
  /// clinically validated.
  final double? strideTimeCoefficientOfVariation;

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
    strideIntervalCount,
    meanStrideTime,
    strideTimeStandardDeviation,
    strideTimeCoefficientOfVariation,
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
  final intervalUs = _filterTemporalIntervals(
    _stepIntervalMicroseconds(result.detectedStepOffsets),
  );
  final strideIntervalUs = _filterTemporalIntervals(
    _strideIntervalMicroseconds(result.detectedStepOffsets),
  );
  return _temporalParametersFromIntervals(
    intervalUs,
    strideIntervalUs: strideIntervalUs,
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
  final strideIntervalUs = <int>[];
  var weightedRegularity = 0.0;
  var regularityWeight = 0;

  for (final result in results) {
    if (!result.isComputed) continue;
    final resultIntervals = _stepIntervalMicroseconds(
      result.detectedStepOffsets,
    );
    final filteredResultIntervals = _filterTemporalIntervals(resultIntervals);
    intervalUs.addAll(filteredResultIntervals);
    strideIntervalUs.addAll(
      _filterTemporalIntervals(
        _strideIntervalMicroseconds(result.detectedStepOffsets),
      ),
    );

    final periodicity = result.periodicity;
    if (periodicity != null && filteredResultIntervals.isNotEmpty) {
      weightedRegularity += periodicity * filteredResultIntervals.length;
      regularityWeight += filteredResultIntervals.length;
    }
  }

  return _temporalParametersFromIntervals(
    intervalUs,
    strideIntervalUs: strideIntervalUs,
    gaitRegularity: regularityWeight == 0
        ? null
        : weightedRegularity / regularityWeight,
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

List<int> _strideIntervalMicroseconds(List<Duration> stepOffsets) {
  final intervalUs = <int>[];
  for (var i = 2; i < stepOffsets.length; i++) {
    final interval = stepOffsets[i] - stepOffsets[i - 2];
    if (interval > Duration.zero) {
      intervalUs.add(interval.inMicroseconds);
    }
  }
  return intervalUs;
}

List<int> _filterTemporalIntervals(List<int> intervalUs) {
  if (intervalUs.length < 5) return intervalUs;

  final intervalValues = [
    for (final interval in intervalUs) interval.toDouble(),
  ];
  final medianUs = stats.median(intervalValues);
  if (medianUs <= 0) return intervalUs;

  final lower = medianUs * defaultTemporalIntervalLowerMedianRatio;
  final upper = medianUs * defaultTemporalIntervalUpperMedianRatio;
  final filtered = [
    for (final interval in intervalUs)
      if (interval > lower && interval < upper) interval,
  ];

  if (filtered.length < (intervalUs.length / 2).ceil()) {
    return intervalUs;
  }
  return filtered;
}

GaitTemporalParameters? _temporalParametersFromIntervals(
  List<int> intervalUs, {
  required List<int> strideIntervalUs,
  required double? gaitRegularity,
}) {
  if (intervalUs.isEmpty) return null;

  final stepStats = _intervalStatistics(intervalUs);
  if (stepStats == null) return null;
  final strideStats = _intervalStatistics(strideIntervalUs);

  final instantCadenceValues = [
    for (final interval in intervalUs)
      Duration.microsecondsPerMinute / interval,
  ];
  final meanInstantCadence = stats.mean(instantCadenceValues);
  final instantCadenceStd = stats.standardDeviation(
    instantCadenceValues,
    meanInstantCadence,
  );

  return GaitTemporalParameters(
    stepIntervalCount: intervalUs.length,
    meanStepTime: stepStats.mean,
    medianStepTime: stepStats.median,
    stepTimeStandardDeviation: stepStats.standardDeviation,
    stepTimeCoefficientOfVariation: stepStats.coefficientOfVariation,
    minimumStepTime: stepStats.minimum,
    maximumStepTime: stepStats.maximum,
    strideIntervalCount: strideIntervalUs.length,
    meanStrideTime: strideStats?.mean,
    strideTimeStandardDeviation: strideStats?.standardDeviation,
    strideTimeCoefficientOfVariation: strideStats?.coefficientOfVariation,
    meanInstantCadenceStepsPerMinute: meanInstantCadence,
    instantCadenceStandardDeviationStepsPerMinute: instantCadenceStd,
    instantCadenceCoefficientOfVariation: meanInstantCadence <= 0
        ? 0
        : instantCadenceStd / meanInstantCadence,
    gaitRegularity: gaitRegularity,
  );
}

_IntervalStatistics? _intervalStatistics(List<int> intervalUs) {
  if (intervalUs.isEmpty) return null;
  final intervalValues = [
    for (final interval in intervalUs) interval.toDouble(),
  ];
  final meanIntervalUs = stats.mean(intervalValues);
  if (meanIntervalUs <= 0) return null;

  final standardDeviationUs = stats.standardDeviation(
    intervalValues,
    meanIntervalUs,
  );
  return _IntervalStatistics(
    mean: _durationFromMicroseconds(meanIntervalUs),
    median: _durationFromMicroseconds(stats.median(intervalValues)),
    standardDeviation: _durationFromMicroseconds(standardDeviationUs),
    coefficientOfVariation: standardDeviationUs / meanIntervalUs,
    minimum: Duration(microseconds: intervalUs.reduce(math.min)),
    maximum: Duration(microseconds: intervalUs.reduce(math.max)),
  );
}

Duration _durationFromMicroseconds(double microseconds) {
  return Duration(microseconds: microseconds.round());
}

class _IntervalStatistics {
  const _IntervalStatistics({
    required this.mean,
    required this.median,
    required this.standardDeviation,
    required this.coefficientOfVariation,
    required this.minimum,
    required this.maximum,
  });

  final Duration mean;
  final Duration median;
  final Duration standardDeviation;
  final double coefficientOfVariation;
  final Duration minimum;
  final Duration maximum;
}
