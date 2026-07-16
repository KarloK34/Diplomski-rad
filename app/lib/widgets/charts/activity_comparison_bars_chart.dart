import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:gait_sense/models/session_summary_record.dart';
import 'package:gait_sense/theme/activity_color.dart';
import 'package:gait_sense/theme/app_colors.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/utils/session_summary_format.dart';

/// Horizontally scrolling stacked bars comparing activity mix across
/// sessions, one bar per session.
///
/// Bars keep a fixed width and scroll instead of shrinking to fit, so the
/// session count is never capped.
class ActivityComparisonBarsChart extends StatelessWidget {
  /// Creates the bars chart for [sessions], scrolled via [scrollController].
  /// [bottomReservedSize] must match the fixed axis chart's so both plot
  /// areas end up the same height and their gridlines line up.
  const ActivityComparisonBarsChart({
    required this.sessions,
    required this.scrollController,
    required this.bottomReservedSize,
    super.key,
  });

  /// Sessions to compare, oldest first.
  final List<SessionSummaryRecord> sessions;

  /// Drives the horizontal scroll view and its scrollbar.
  final ScrollController scrollController;

  /// Reserved height for the bottom date-label row.
  final double bottomReservedSize;

  // Wide enough for the 18px rod plus its date label without crowding.
  static const double _slotWidth = 56;

  @override
  Widget build(BuildContext context) {
    final colors = context.gaitColors;
    final textStyle = context.textStyles.bodySmall;

    return LayoutBuilder(
      builder: (context, constraints) {
        final naturalWidth = sessions.length * _slotWidth;
        final chartWidth = naturalWidth < constraints.maxWidth
            ? constraints.maxWidth
            : naturalWidth;
        return Scrollbar(
          controller: scrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: chartWidth,
              child: BarChart(_chartData(colors, textStyle)),
            ),
          ),
        );
      },
    );
  }

  BarChartData _chartData(GaitSenseColors colors, TextStyle? textStyle) {
    return BarChartData(
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
        leftTitles: const AxisTitles(),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: bottomReservedSize,
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
          BarChartGroupData(x: i, barRods: [_rod(sessions[i], colors)]),
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
