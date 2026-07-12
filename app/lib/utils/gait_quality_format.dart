import 'package:gait_sense/models/gait_segment.dart';
import 'package:gait_sense/utils/activity_labels.dart';
import 'package:gait_sense/utils/gait_cadence.dart';
import 'package:gait_sense/utils/gait_signal_segments.dart';
import 'package:gait_sense/utils/gait_walking_speed.dart';
import 'package:gait_sense/utils/session_summary.dart';
import 'package:gait_sense/utils/session_summary_format.dart';

/// Display formatting for the session quality and gait-analysis section of
/// the session summary screen.

/// Formats per-label window counts, sorted by count descending.
String formatLabelCounts(Map<String, int> counts) {
  if (counts.isEmpty) return 'nema predikcija';

  final entries = counts.entries.toList()
    ..sort((a, b) {
      final byWindows = b.value.compareTo(a.value);
      return byWindows != 0 ? byWindows : a.key.compareTo(b.key);
    });
  return entries
      .map((entry) => '${activityLabelHr(entry.key)}: ${entry.value}')
      .join(', ');
}

/// Formats [fraction] as a Croatian-locale percentage.
String formatPercentHr(double fraction) {
  final percentage = fraction * 100;
  final rounded = percentage.roundToDouble();
  final decimals = (percentage - rounded).abs() < 0.05 ? 0 : 1;
  return '${percentage.toStringAsFixed(decimals).replaceAll('.', ',')} %';
}

/// Croatian count agreement for the noun "segment".
String formatSegmentCountHr(int count) {
  final ones = count % 10;
  final teens = count % 100;
  final noun = ones == 1 && teens != 11
      ? 'segment'
      : ones >= 2 && ones <= 4 && (teens < 12 || teens > 14)
      ? 'segmenta'
      : 'segmenata';
  return '$count $noun';
}

/// Formats [duration] as a clock once it passes a minute, or as fractional
/// seconds below that.
String formatDurationSecondsHr(Duration duration) {
  if (duration.inMinutes >= 1) return formatElapsedClock(duration);
  final seconds = duration.inMilliseconds / 1000;
  return '${seconds.toStringAsFixed(1).replaceAll('.', ',')} s';
}

/// Formats a summary's duration-weighted cadence, if computed.
String formatCadenceHr(GaitCadenceSummary cadence) {
  final value = cadence.averageCadenceStepsPerMinute;
  if (!cadence.hasComputedCadence || value == null) return 'Nije dostupna';
  return '${value.round()} koraka/min';
}

/// Formats a summary's total accepted step count, if cadence was computed.
String formatStepCountHr(GaitCadenceSummary cadence) {
  if (!cadence.hasComputedCadence) return 'Nije dostupno';
  return cadence.totalStepCount.toString();
}

/// Formats an instant-cadence standard deviation.
String formatCadenceSpreadHr(double stepsPerMinute) {
  return '${stepsPerMinute.round()} koraka/min';
}

/// Formats a gait regularity score, if available.
String formatGaitRegularityHr(double? regularity) {
  if (regularity == null) return 'Nije dostupna';
  return formatPercentHr(regularity);
}

/// Maps a cadence confidence level to its Croatian label.
String formatCadenceConfidenceHr(GaitCadenceConfidence confidence) {
  return switch (confidence) {
    GaitCadenceConfidence.low => 'Niska',
    GaitCadenceConfidence.moderate => 'Srednja',
    GaitCadenceConfidence.high => 'Visoka',
  };
}

/// Maps a low-confidence reason code to an explanatory Croatian message.
String formatCadenceConfidenceReasonHr(String? reason) {
  return switch (reason) {
    cadenceEstimatesDisagreeReason =>
      'Procjene iz vrhova i dominantnog perioda odstupaju.',
    lowCadencePeriodicityReason => 'Periodičnost signala je niska.',
    limitedCadenceEvidenceReason => 'Dostupno je malo ponovljenih koraka.',
    _ => 'Procjenu treba tumačiti oprezno.',
  };
}

/// Maps a cadence-unavailable reason code to an explanatory Croatian message.
String formatCadenceUnavailableReasonHr(String? reason) {
  switch (reason) {
    case noSuitableCadenceSignalReason:
      return 'Nema dovoljno stabilnog hodanja po ravnom.';
    case missingRawSamplesReason:
      return 'Nema spremljenog signala senzora.';
    case invalidSampleIndexRangeReason:
    case sampleIndexOutOfRangeReason:
    case invalidTimeOffsetRangeReason:
    case noSamplesInTimeRangeReason:
      return 'Signal hodanja nije dostupan za ovaj zapis.';
    case emptyCadenceSignalReason:
      return 'Nema dostupnog signala hodanja.';
    case cadenceSignalTooShortReason:
      return 'Signal hodanja je prekratak.';
    case tooFewCadencePeaksReason:
      return 'Nije detektirano dovoljno koraka.';
    case lowCadencePeriodicityReason:
      return 'Signal hodanja nema dovoljno jasnu periodičnost.';
    case invalidCadenceTimestampsReason:
      return 'Vremenske oznake signala nisu valjane.';
    default:
      return 'Kadenca nije dostupna.';
  }
}

/// Formats a summary's duration-weighted walking speed, if computed.
String formatWalkingSpeedHr(GaitWalkingSpeedSummary speed) {
  final value = speed.averageWalkingSpeedMs;
  if (!speed.hasComputedSpeed || value == null) return 'Nije dostupna';
  return '${value.toStringAsFixed(2).replaceAll('.', ',')} m/s';
}

/// Formats a summary's duration-weighted step length, if computed.
String formatStepLengthHr(GaitWalkingSpeedSummary speed) {
  final value = speed.averageStepLengthM;
  if (!speed.hasComputedSpeed || value == null) return 'Nije dostupna';
  return '${(value * 100).round()} cm';
}

/// Maps a walking-speed-unavailable reason code to an explanatory message.
String formatWalkingSpeedUnavailableReasonHr(GaitWalkingSpeedSummary speed) {
  return switch (speed.reason) {
    missingUserHeightReason =>
      'Visina nije postavljena — dodajte je u postavkama.',
    noSuitableCadenceSignalReason =>
      'Nema dovoljno stabilnog hodanja po ravnom.',
    cadenceNotComputedReason => 'Kadenca nije izračunata.',
    lowConfidenceCadenceReason =>
      'Kadenca je preniske pouzdanosti za procjenu brzine.',
    insufficientVerticalAmplitudeReason => 'Vertikalni signal je prenizak.',
    invalidPendulumGeometryReason =>
      'Geometrija modela nije valjana za ovaj signal.',
    implausibleStepLengthReason =>
      'Procijenjena duljina koraka je izvan očekivanog raspona.',
    _ => 'Brzina hoda nije dostupna.',
  };
}

/// Formats a gait segment's analysis start-end offsets.
String formatGaitSegmentTimeRange(GaitSegment segment) {
  return '${formatElapsedClock(segment.analysisStartOffset)} - '
      '${formatElapsedClock(segment.analysisEndOffset)}';
}
