import 'package:gait_sense/models/session_summary_record.dart';

/// Cross-session aggregations for the dashboard tiles.
///
/// Kept pure and platform-free so they can be unit-tested on the host VM; the
/// Home screen adds the display layer (formatting and empty-state dashes).

/// MotionSense level-walking class code (Malekzadeh et al., IoTDI 2019,
/// https://doi.org/10.1145/3302505.3310068).
const String walkingActivityLabel = 'wlk';

/// The dashboard's cross-session aggregates, computed together in one pass.
///
/// `averageCadenceStepsPerMinute` and `averageWalkingSpeedMs` are plain means
/// of the per-session averages (not duration-weighted) over sessions that
/// computed one, and null when none did; the per-session values are
/// themselves experimental estimates, so these are only an indicative trend
/// and are not clinically validated.
typedef SessionHistoryAggregates = ({
  Duration totalWalkingTime,
  double? averageCadenceStepsPerMinute,
  double? averageWalkingSpeedMs,
});

/// The result for an empty (or not-yet-loaded) session history.
const SessionHistoryAggregates emptySessionHistoryAggregates = (
  totalWalkingTime: Duration.zero,
  averageCadenceStepsPerMinute: null,
  averageWalkingSpeedMs: null,
);

/// Computes [SessionHistoryAggregates] over [sessions] in a single pass, so
/// the dashboard doesn't walk the (potentially large) history once per tile.
SessionHistoryAggregates sessionHistoryAggregates(
  List<SessionSummaryRecord> sessions,
) {
  var walkingTime = Duration.zero;
  var cadenceSum = 0.0;
  var cadenceCount = 0;
  var speedSum = 0.0;
  var speedCount = 0;

  for (final session in sessions) {
    for (final total in session.classTotals) {
      if (total.label == walkingActivityLabel) walkingTime += total.time;
    }

    final cadence = session.quality.gaitCadence.averageCadenceStepsPerMinute;
    if (cadence != null) {
      cadenceSum += cadence;
      cadenceCount++;
    }

    final speed = session.quality.gaitWalkingSpeed.averageWalkingSpeedMs;
    if (speed != null) {
      speedSum += speed;
      speedCount++;
    }
  }

  return (
    totalWalkingTime: walkingTime,
    averageCadenceStepsPerMinute: cadenceCount == 0
        ? null
        : cadenceSum / cadenceCount,
    averageWalkingSpeedMs: speedCount == 0 ? null : speedSum / speedCount,
  );
}
