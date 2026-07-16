import 'package:gait_sense/utils/session_summary.dart';

/// Display formatting for the session overview header, activity totals, and
/// timeline sections of the session summary screen.

String _two(int value) => value.toString().padLeft(2, '0');

/// Formats [duration] as `mm:ss`, or `h:mm:ss` once it passes an hour.
String formatElapsedClock(Duration duration) {
  final hours = duration.inHours;
  final minutes = _two(duration.inMinutes.remainder(60));
  final seconds = _two(duration.inSeconds.remainder(60));
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}

/// Formats a wall-clock start time as `dd.MM.yyyy. HH:mm` in local time.
String formatStartTimestamp(DateTime dateTime) {
  final local = dateTime.toLocal();
  return '${_two(local.day)}.${_two(local.month)}.${local.year}. '
      '${_two(local.hour)}:${_two(local.minute)}';
}

/// Formats a date as `dd.MM` in local time, for chart axis labels.
String formatShortDate(DateTime dateTime) {
  final local = dateTime.toLocal();
  return '${_two(local.day)}.${_two(local.month)}';
}

/// Formats a class total as its occupied time and percentage share.
String formatClassTotalValue(ClassTotal total) {
  final percent = (total.fraction * 100).round();
  return '${formatElapsedClock(total.time)} ($percent %)';
}

/// Formats a timeline segment's start-end offsets.
String formatTimelineSegmentTimeRange(TimelineSegment segment) {
  return '${formatElapsedClock(segment.start)} – '
      '${formatElapsedClock(segment.end)}';
}

/// Formats an accumulated walking time as `X h Y min`, `Y min`, or `< 1 min`.
String formatWalkingDurationHr(Duration duration) {
  if (duration.inSeconds == 0) return '0 min';
  if (duration.inMinutes == 0) return '< 1 min';
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  return hours > 0 ? '$hours h $minutes min' : '$minutes min';
}

/// Formats cadence in whole steps per minute, e.g. `112 kor/min`.
String formatCadenceValueHr(double stepsPerMinute) =>
    '${stepsPerMinute.round()} kor/min';

/// Formats walking speed with one decimal, e.g. `1.2 m/s`.
String formatWalkingSpeedValueHr(double metersPerSecond) =>
    '${metersPerSecond.toStringAsFixed(1)} m/s';
