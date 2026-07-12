import 'package:flutter/material.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/widgets/lists/segment_row_line.dart';

/// One timeline segment: time range, activity name, and window count.
class TimelineSegmentRow extends StatelessWidget {
  /// Creates a row summarizing one timeline segment.
  const TimelineSegmentRow({
    required this.timeRangeLabel,
    required this.activityLabel,
    required this.windowCountLabel,
    super.key,
  });

  /// Pre-formatted start-end offsets.
  final String timeRangeLabel;

  /// Croatian-mapped activity name.
  final String activityLabel;

  /// Pre-formatted window count.
  final String windowCountLabel;

  @override
  Widget build(BuildContext context) {
    final muted = context.textStyles.bodyMedium?.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.spacing.xxs),
      child: SegmentRowLine(
        timeRangeLabel: timeRangeLabel,
        content: Text(activityLabel),
        trailingLabel: windowCountLabel,
        style: muted,
      ),
    );
  }
}
