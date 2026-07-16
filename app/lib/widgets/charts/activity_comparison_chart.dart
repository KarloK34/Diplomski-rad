import 'package:flutter/material.dart';
import 'package:gait_sense/models/session_summary_record.dart';
import 'package:gait_sense/theme/activity_color.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/utils/activity_labels.dart';
import 'package:gait_sense/widgets/charts/activity_comparison_axis_chart.dart';
import 'package:gait_sense/widgets/charts/activity_comparison_bars_chart.dart';
import 'package:gait_sense/widgets/charts/chart_legend.dart';

/// Stacked bars comparing the activity mix (percent of windows) across recent
/// sessions, one bar per session.
///
/// Expects [sessions] in chronological order (oldest first). Bars keep a
/// fixed width and scroll horizontally instead of shrinking to fit, so the
/// session count is never capped; the chart opens scrolled to the most
/// recent session.
class ActivityComparisonChart extends StatefulWidget {
  /// Creates the comparison chart for [sessions].
  const ActivityComparisonChart({required this.sessions, super.key});

  /// Sessions to compare, oldest first.
  final List<SessionSummaryRecord> sessions;

  @override
  State<ActivityComparisonChart> createState() =>
      _ActivityComparisonChartState();
}

class _ActivityComparisonChartState extends State<ActivityComparisonChart> {
  // Left axis is rendered as its own fixed chart outside the horizontal
  // scroll view, so it stays visible while bars scroll underneath it.
  static const double _leftAxisWidth = 40;
  static const double _bottomReservedSize = 28;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.gaitColors;
    final sessions = widget.sessions;

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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                width: _leftAxisWidth,
                child: ActivityComparisonAxisChart(
                  bottomReservedSize: _bottomReservedSize,
                ),
              ),
              Expanded(
                child: ActivityComparisonBarsChart(
                  sessions: sessions,
                  scrollController: _scrollController,
                  bottomReservedSize: _bottomReservedSize,
                ),
              ),
            ],
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
}
