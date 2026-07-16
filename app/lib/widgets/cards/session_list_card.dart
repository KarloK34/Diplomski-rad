import 'package:flutter/material.dart';
import 'package:gait_sense/models/session_summary_record.dart';
import 'package:gait_sense/theme/activity_color.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/utils/activity_labels.dart';
import 'package:gait_sense/utils/session_summary_format.dart';
import 'package:gait_sense/widgets/indicators/pill.dart';

/// A tappable summary card for one saved session in the history list: start
/// time, duration, and pills for the dominant activity, cadence, and speed.
class SessionListCard extends StatelessWidget {
  /// Creates a card for [record], opening its detail view via [onTap].
  const SessionListCard({required this.record, required this.onTap, super.key});

  /// The session to summarize.
  final SessionSummaryRecord record;

  /// Called when the card is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final colors = context.gaitColors;
    final dominant = record.classTotals.isEmpty
        ? null
        : record.classTotals.first;
    final cadence = record.quality.gaitCadence.averageCadenceStepsPerMinute;
    final speed = record.quality.gaitWalkingSpeed.averageWalkingSpeedMs;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      formatStartTimestamp(record.startedAt),
                      style: context.textStyles.titleSmall,
                    ),
                  ),
                  Text(
                    formatElapsedClock(record.duration),
                    style: context.textStyles.labelLarge?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              SizedBox(height: spacing.sm),
              Wrap(
                spacing: spacing.xs,
                runSpacing: spacing.xs,
                children: [
                  if (dominant != null)
                    Pill(
                      dotColor: colors.forActivity(dominant.label),
                      label: activityLabelHr(dominant.label),
                    ),
                  if (cadence != null)
                    Pill(
                      icon: Icons.directions_walk,
                      label: formatCadenceValueHr(cadence),
                    ),
                  if (speed != null)
                    Pill(
                      icon: Icons.speed,
                      label: formatWalkingSpeedValueHr(speed),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
