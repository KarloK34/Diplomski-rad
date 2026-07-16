import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/utils/session_summary_format.dart';

/// One point on a [MetricTrendChart]: a value observed at a moment in time.
class MetricTrendPoint {
  /// Creates a trend point.
  const MetricTrendPoint({required this.time, required this.value});

  /// When the value was recorded (used for the x-axis label).
  final DateTime time;

  /// The plotted value.
  final double value;
}

/// A line chart of one metric across sessions over time, shared by the cadence
/// and walking-speed trends.
///
/// Expects [points] in chronological order (oldest first) and at least two of
/// them; the caller decides when there is enough data to show a trend.
class MetricTrendChart extends StatelessWidget {
  /// Creates the chart for [points], drawn in [color] with [formatValue] on the
  /// y-axis.
  const MetricTrendChart({
    required this.points,
    required this.color,
    required this.formatValue,
    super.key,
  });

  /// Chronological data points.
  final List<MetricTrendPoint> points;

  /// Line and fill color.
  final Color color;

  /// Formats a y-axis value for display.
  final String Function(double value) formatValue;

  @override
  Widget build(BuildContext context) {
    final colors = context.gaitColors;
    final textStyle = context.textStyles.bodySmall;
    final spacing = context.spacing;

    final values = points.map((point) => point.value).toList();
    var low = values.reduce(min);
    var high = values.reduce(max);
    if (low == high) {
      low -= 1;
      high += 1;
    }
    final padding = (high - low) * 0.15;
    final minY = low - padding;
    final maxY = high + padding;
    final yInterval = (maxY - minY) / 3;
    final labelEvery = points.length <= 6 ? 1 : (points.length / 6).ceil();

    return Container(
      padding: EdgeInsets.only(right: spacing.xs),
      height: 200,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (points.length - 1).toDouble(),
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: yInterval,
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
                reservedSize: 44,
                interval: yInterval,
                getTitlesWidget: (value, _) => Padding(
                  padding: EdgeInsets.only(right: spacing.xxs),
                  child: Text(formatValue(value), style: textStyle),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 28,
                getTitlesWidget: (value, _) {
                  final index = value.round();
                  if (index < 0 ||
                      index >= points.length ||
                      index % labelEvery != 0) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: EdgeInsets.only(top: spacing.xxs),
                    child: Text(
                      formatShortDate(points[index].time),
                      style: textStyle,
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < points.length; i++)
                  FlSpot(i.toDouble(), points[i].value),
              ],
              color: color,
              barWidth: 3,
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
