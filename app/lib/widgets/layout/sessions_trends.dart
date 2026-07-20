import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/sessions_list/sessions_list_cubit.dart';
import 'package:gait_sense/models/session_summary_record.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/utils/gait_metric_info.dart';
import 'package:gait_sense/utils/session_metric_info.dart';
import 'package:gait_sense/utils/sessions_filter.dart';
import 'package:gait_sense/widgets/cards/chart_card.dart';
import 'package:gait_sense/widgets/charts/activity_comparison_chart.dart';
import 'package:gait_sense/widgets/charts/metric_trend_chart.dart';

/// Cross-session insight charts for the Sessions tab: cadence, walking-speed,
/// and step-length trends over time, plus an activity-mix comparison of
/// recent sessions.
///
/// Each chart appears only once it has enough data; with too few sessions a
/// short hint is shown instead. Scoped by the same period/activity filters
/// the sessions history list above it uses, via the shared
/// [SessionsListCubit] — one set of page-level filters drives both instead
/// of a separate lookback selector.
class SessionsTrends extends StatelessWidget {
  /// Creates the trends section for [sessions] (newest first).
  const SessionsTrends({required this.sessions, super.key});

  /// The full, unfiltered session history, newest first (as the cubit emits
  /// it).
  final List<SessionSummaryRecord> sessions;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final colors = context.gaitColors;
    final chronological = sessions.reversed.toList();
    final hasHistory = chronological.length >= 2;

    final listState = context.watch<SessionsListCubit>().state;
    final scoped = filterSessions(
      chronological,
      period: listState.period,
      activity: listState.activity,
    );

    final cadencePoints = [
      for (final session in scoped)
        if (session.quality.gaitCadence.averageCadenceStepsPerMinute
            case final cadence?)
          MetricTrendPoint(time: session.startedAt, value: cadence),
    ];
    final speedPoints = [
      for (final session in scoped)
        if (session.quality.gaitWalkingSpeed.averageWalkingSpeedMs
            case final speed?)
          MetricTrendPoint(time: session.startedAt, value: speed),
    ];
    final stepLengthPoints = [
      for (final session in scoped)
        if (session.quality.gaitWalkingSpeed.averageStepLengthM
            case final length?)
          MetricTrendPoint(time: session.startedAt, value: length),
    ];

    final cards = <Widget>[
      if (cadencePoints.length >= 2)
        ChartCard(
          title: 'Trend kadence',
          subtitle: 'Prosječna kadenca po sesiji (kor/min)',
          info: cadenceMetricInfo,
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
          info: walkingSpeedMetricInfo,
          child: MetricTrendChart(
            points: speedPoints,
            color: colors.chartComparison,
            formatValue: (value) => value.toStringAsFixed(1),
          ),
        ),
      if (stepLengthPoints.length >= 2)
        ChartCard(
          title: 'Trend duljine koraka',
          subtitle: 'Prosječna duljina koraka po sesiji (cm)',
          info: stepLengthMetricInfo,
          child: MetricTrendChart(
            points: stepLengthPoints,
            color: colors.warning,
            formatValue: (value) => (value * 100).round().toString(),
          ),
        ),
      if (scoped.length >= 2)
        ChartCard(
          title: 'Usporedba aktivnosti',
          subtitle: 'Udio aktivnosti u odabranim sesijama',
          info: activityComparisonMetricInfo,
          child: ActivityComparisonChart(sessions: scoped),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Trendovi', style: context.textStyles.titleLarge),
        SizedBox(height: spacing.md),
        if (!hasHistory)
          Text(
            'Trendovi će se prikazati nakon više spremljenih sesija.',
            style: context.textStyles.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          )
        else if (cards.isEmpty)
          Text(
            'Nema sesija za odabrani filtar.',
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
