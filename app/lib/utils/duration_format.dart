import 'package:gait_sense/utils/session_summary_format.dart';

/// Formats [duration] as `mm:ss`, clamping negative durations to `00:00`.
///
/// Delegates to [formatElapsedClock] for the zero-padding logic; the live
/// recording/session-limit durations this is used for never reach an hour
/// (`defaultMaxSessionDuration` caps at 30 minutes), so its hour prefix never
/// triggers here.
String formatMmSs(Duration duration) {
  if (duration.isNegative) return '00:00';
  return formatElapsedClock(duration);
}
