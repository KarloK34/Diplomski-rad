import 'package:gait_sense/utils/session_summary_format.dart';

/// Generic Croatian-locale display formatting (percentages, noun agreement,
/// durations) with no domain-specific content — see `gait_quality_format.dart`
/// and `session_summary_format.dart` for the domain formatters that build on
/// these.

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

/// Croatian count agreement for the noun "prozor" (window).
String windowCountLabelHr(int count) {
  final ones = count % 10;
  final teens = count % 100;
  final noun = ones == 1 && teens != 11 ? 'prozor' : 'prozora';
  return '$count $noun';
}

/// Formats [duration] as a clock once it passes a minute, or as fractional
/// seconds below that.
String formatDurationSecondsHr(Duration duration) {
  if (duration.inMinutes >= 1) return formatElapsedClock(duration);
  final seconds = duration.inMilliseconds / 1000;
  return '${seconds.toStringAsFixed(1).replaceAll('.', ',')} s';
}

/// Formats a step/stride time with two decimals — one decimal collapses
/// genuinely different sessions onto the same displayed value.
String formatStepTimeSecondsHr(Duration duration) {
  final seconds = duration.inMicroseconds / Duration.microsecondsPerSecond;
  return '${seconds.toStringAsFixed(2).replaceAll('.', ',')} s';
}
