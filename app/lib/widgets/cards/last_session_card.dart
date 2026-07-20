import 'package:flutter/material.dart';
import 'package:gait_sense/models/session_summary_record.dart';
import 'package:gait_sense/utils/activity_labels.dart';
import 'package:gait_sense/utils/session_summary_format.dart';
import 'package:gait_sense/widgets/cards/info_card.dart';
import 'package:gait_sense/widgets/lists/labeled_row.dart';

const String _dash = '–';

/// "Zadnja sesija" card: date, duration, dominant activity, cadence, and
/// walking speed for a single saved session — the per-session counterpart to
/// the dashboard's cross-session `MetricGrid` averages.
class LastSessionCard extends StatelessWidget {
  /// Creates a card summarizing [session].
  const LastSessionCard({required this.session, super.key});

  /// The session to summarize — normally the most recent saved one.
  final SessionSummaryRecord session;

  @override
  Widget build(BuildContext context) {
    final dominant = session.classTotals.isEmpty
        ? null
        : session.classTotals.first;
    final cadence = session.quality.gaitCadence.averageCadenceStepsPerMinute;
    final speed = session.quality.gaitWalkingSpeed.averageWalkingSpeedMs;

    return InfoCard(
      title: 'Zadnja sesija',
      rows: [
        LabeledRow(
          label: 'Datum',
          value: formatStartTimestamp(session.startedAt),
        ),
        LabeledRow(
          label: 'Trajanje',
          value: formatElapsedClock(session.duration),
        ),
        LabeledRow(
          label: 'Dominantna aktivnost',
          value: dominant == null ? _dash : activityLabelHr(dominant.label),
        ),
        LabeledRow(
          label: 'Kadenca',
          value: cadence == null ? _dash : formatCadenceValueHr(cadence),
        ),
        LabeledRow(
          label: 'Brzina',
          value: speed == null ? _dash : formatWalkingSpeedValueHr(speed),
        ),
      ],
    );
  }
}
