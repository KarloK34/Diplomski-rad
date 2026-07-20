import 'package:gait_sense/models/session_summary_record.dart';
import 'package:gait_sense/utils/session_summary.dart';

/// Cross-session aggregations for the dashboard tiles.
///
/// Kept pure and platform-free so they can be unit-tested on the host VM; the
/// Home screen adds the display layer (formatting and empty-state dashes).

/// MotionSense level-walking class code (Malekzadeh et al., IoTDI 2019,
/// https://doi.org/10.1145/3302505.3310068).
const String walkingActivityLabel = 'wlk';

/// The dashboard's cross-session aggregates, computed together in one pass.
///
/// `averageCadenceStepsPerMinute` and `averageWalkingSpeedMs` are duration-
/// weighted means of the per-session averages over sessions that computed
/// one (see [sessionHistoryAggregates] for the weight used), matching the
/// duration-weighting rule already used for the intra-session aggregation in
/// `summarizeGaitCadence`/`summarizeGaitWalkingSpeed` (session_summary.dart)
/// so a session with only a couple of minutes of usable gait signal doesn't
/// pull the trend as hard as one with much more. Null when no session
/// computed one; the per-session values are themselves experimental
/// estimates, so these are only an indicative trend and are not clinically
/// validated.
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
///
/// Both metrics are weighted by the exact same duration their per-session
/// average was itself weighted by, so cross-session aggregation doesn't
/// introduce any new approximation: cadence by
/// [GaitCadenceSummary.signalDuration] and speed by
/// [SessionQualitySummary.levelWalkingGaitDuration] (walking speed is only
/// ever computed from the level-walking gait segments that getter sums). A
/// session whose weight is zero (e.g. an older record saved before
/// [GaitCadenceSummary.signalDuration] was tracked, or a session too short
/// for either duration to be non-zero) still contributes its computed value
/// at a nominal weight of one, so it isn't silently dropped from the trend.
SessionHistoryAggregates sessionHistoryAggregates(
  List<SessionSummaryRecord> sessions,
) {
  var walkingTime = Duration.zero;
  var cadenceWeightedSum = 0.0;
  var cadenceWeight = 0.0;
  var speedWeightedSum = 0.0;
  var speedWeight = 0.0;

  for (final session in sessions) {
    for (final total in session.classTotals) {
      if (total.label == walkingActivityLabel) walkingTime += total.time;
    }

    final cadence = session.quality.gaitCadence.averageCadenceStepsPerMinute;
    if (cadence != null) {
      final weight = _weightOrNominal(
        session.quality.gaitCadence.signalDuration,
      );
      cadenceWeightedSum += cadence * weight;
      cadenceWeight += weight;
    }

    final speed = session.quality.gaitWalkingSpeed.averageWalkingSpeedMs;
    if (speed != null) {
      final weight = _weightOrNominal(
        session.quality.levelWalkingGaitDuration,
      );
      speedWeightedSum += speed * weight;
      speedWeight += weight;
    }
  }

  return (
    totalWalkingTime: walkingTime,
    averageCadenceStepsPerMinute: cadenceWeight == 0
        ? null
        : cadenceWeightedSum / cadenceWeight,
    averageWalkingSpeedMs: speedWeight == 0
        ? null
        : speedWeightedSum / speedWeight,
  );
}

/// [duration] in microseconds, or a nominal weight of one when it's zero —
/// see [sessionHistoryAggregates] for why a zero duration still counts.
double _weightOrNominal(Duration duration) {
  final microseconds = duration.inMicroseconds;
  return microseconds > 0 ? microseconds.toDouble() : 1.0;
}
