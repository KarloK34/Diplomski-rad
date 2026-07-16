import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:gait_sense/theme/activity_color.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/utils/activity_labels.dart';
import 'package:gait_sense/utils/session_summary.dart';
import 'package:gait_sense/widgets/charts/chart_legend.dart';

/// Donut chart of how a session's time splits across activity classes.
class ActivityDistributionChart extends StatelessWidget {
  /// Creates the chart for [totals] (per-class time totals).
  const ActivityDistributionChart({required this.totals, super.key});

  /// Per-class totals to plot; sections follow this order.
  final List<ClassTotal> totals;

  @override
  Widget build(BuildContext context) {
    final colors = context.gaitColors;
    final spacing = context.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 44,
              sections: [
                for (final total in totals)
                  PieChartSectionData(
                    value: total.fraction * 100,
                    color: colors.forActivity(total.label),
                    // Hide labels on slivers so slices don't overlap text.
                    title: total.fraction >= 0.08
                        ? '${(total.fraction * 100).round()}%'
                        : '',
                    radius: 52,
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(height: spacing.sm),
        ChartLegend(
          entries: [
            for (final total in totals)
              ChartLegendEntry(
                color: colors.forActivity(total.label),
                label: activityLabelHr(total.label),
              ),
          ],
        ),
      ],
    );
  }
}
