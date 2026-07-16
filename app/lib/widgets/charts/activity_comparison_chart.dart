import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:gait_sense/models/session_summary_record.dart';
import 'package:gait_sense/theme/activity_color.dart';
import 'package:gait_sense/theme/app_colors.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/utils/activity_labels.dart';
import 'package:gait_sense/utils/session_summary_format.dart';
import 'package:gait_sense/widgets/charts/chart_legend.dart';

/// Stacked bars comparing the activity mix (percent of windows) across recent
/// sessions, one bar per session.
///
/// Expects [sessions] in chronological order (oldest first).
class ActivityComparisonChart extends StatelessWidget {
  /// Creates the comparison chart for [sessions].
  const ActivityComparisonChart({required this.sessions, super.key});

  /// Sessions to compare, oldest first.
  final List<SessionSummaryRecord> sessions;

  @override
  Widget build(BuildContext context) {
    final colors = context.gaitColors;
    final textStyle = context.textStyles.bodySmall;

    // Canonical activity order (from the label map) restricted to what appears.
    final present = <String>[
      for (final code in activityLabelsHr.keys)
        if (sessions.any((s) => s.classTotals.any((t) => t.label == code)))
          code,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              maxY: 100,
              alignment: BarChartAlignment.spaceAround,
              barTouchData: const BarTouchData(enabled: false),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: 25,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: colors.chartGrid, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 25,
                    reservedSize: 36,
                    getTitlesWidget: (value, _) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text('${value.round()}%', style: textStyle),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, _) {
                      final index = value.round();
                      if (index < 0 || index >= sessions.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          formatShortDate(sessions[index].startedAt),
                          style: textStyle,
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < sessions.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [_rod(sessions[i], colors)],
                  ),
              ],
            ),
          ),
        ),
        SizedBox(height: context.spacing.sm),
        ChartLegend(
          entries: [
            for (final code in present)
              ChartLegendEntry(
                color: colors.forActivity(code),
                label: activityLabelHr(code),
              ),
          ],
        ),
      ],
    );
  }

  BarChartRodData _rod(SessionSummaryRecord session, GaitSenseColors colors) {
    final stack = <BarChartRodStackItem>[];
    var from = 0.0;
    for (final total in session.classTotals) {
      final to = from + total.fraction * 100;
      stack.add(
        BarChartRodStackItem(from, to, colors.forActivity(total.label)),
      );
      from = to;
    }
    return BarChartRodData(
      toY: from,
      width: 18,
      color: Colors.transparent,
      borderRadius: BorderRadius.zero,
      rodStackItems: stack,
    );
  }
}
