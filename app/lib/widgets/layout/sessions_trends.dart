import 'package:flutter/material.dart';
import 'package:gait_sense/models/session_summary_record.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/widgets/cards/chart_card.dart';
import 'package:gait_sense/widgets/charts/activity_comparison_chart.dart';
import 'package:gait_sense/widgets/charts/metric_trend_chart.dart';

/// Cross-session insight charts for the Sessions tab: cadence and walking-speed
/// trends over time, plus an activity-mix comparison of recent sessions.
///
/// Each chart appears only once it has enough data; with too few sessions a
/// short hint is shown instead.
class SessionsTrends extends StatelessWidget {
  /// Creates the trends section for [sessions] (newest first).
  const SessionsTrends({required this.sessions, super.key});

  /// Sessions to derive trends from, newest first (as the cubit emits them).
  final List<SessionSummaryRecord> sessions;

  static const int _maxComparisonBars = 8;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final colors = context.gaitColors;
    final chronological = sessions.reversed.toList();

    final cadencePoints = [
      for (final session in chronological)
        if (session.quality.gaitCadence.averageCadenceStepsPerMinute
            case final cadence?)
          MetricTrendPoint(time: session.startedAt, value: cadence),
    ];
    final speedPoints = [
      for (final session in chronological)
        if (session.quality.gaitWalkingSpeed.averageWalkingSpeedMs
            case final speed?)
          MetricTrendPoint(time: session.startedAt, value: speed),
    ];
    final comparison = chronological.length > _maxComparisonBars
        ? chronological.sublist(chronological.length - _maxComparisonBars)
        : chronological;

    final cards = <Widget>[
      if (cadencePoints.length >= 2)
        ChartCard(
          title: 'Trend kadence',
          subtitle: 'Prosječna kadenca po sesiji (kor/min)',
          child: MetricTrendChart(
            points: cadencePoints,
            color: colors.activityWalking,
            formatValue: (value) => value.round().toString(),
          ),
        ),
      if (speedPoints.length >= 2)
        ChartCard(
          title: 'Trend brzine hoda',
          subtitle: 'Prosječna brzina hoda po sesiji (m/s)',
          child: MetricTrendChart(
            points: speedPoints,
            color: colors.chartComparison,
            formatValue: (value) => value.toStringAsFixed(1),
          ),
        ),
      if (comparison.length >= 2)
        ChartCard(
          title: 'Usporedba aktivnosti',
          subtitle: 'Udio aktivnosti u zadnjim sesijama',
          child: ActivityComparisonChart(sessions: comparison),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Trendovi', style: context.textStyles.titleLarge),
        SizedBox(height: spacing.md),
        if (cards.isEmpty)
          Text(
            'Trendovi će se prikazati nakon više spremljenih sesija.',
            style: context.textStyles.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          )
        else
          for (final card in cards) ...[card, SizedBox(height: spacing.md)],
      ],
    );
  }
}
