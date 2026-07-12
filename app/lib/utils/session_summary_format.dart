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
