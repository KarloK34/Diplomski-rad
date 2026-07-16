import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:gait_sense/theme/theme_context.dart';

/// Fixed, non-scrolling left percentage axis, rendered as its own [BarChart]
/// outside the horizontal scroll view so it stays visible while the bars
/// scroll underneath it.
class ActivityComparisonAxisChart extends StatelessWidget {
  /// Creates the axis chart. [bottomReservedSize] must match the scrolling
  /// bars chart's so both plot areas end up the same height and their
  /// gridlines line up.
  const ActivityComparisonAxisChart({
    required this.bottomReservedSize,
    super.key,
  });

  /// Reserved height for the (invisible) bottom title row.
  final double bottomReservedSize;

  static const double _leftReservedSize = 36;

  @override
  Widget build(BuildContext context) {
    final textStyle = context.textStyles.bodySmall;
    return BarChart(
      BarChartData(
        maxY: 100,
        barTouchData: const BarTouchData(enabled: false),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: bottomReservedSize,
              getTitlesWidget: (value, _) => const SizedBox.shrink(),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 25,
              reservedSize: _leftReservedSize,
              getTitlesWidget: (value, _) =>
                  Text('${value.round()}%', style: textStyle),
            ),
          ),
        ),
        barGroups: const [],
      ),
    );
  }
}
