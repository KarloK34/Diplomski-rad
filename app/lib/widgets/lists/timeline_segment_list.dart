import 'package:flutter/material.dart';
import 'package:gait_sense/utils/activity_labels.dart';
import 'package:gait_sense/utils/gait_quality_format.dart';
import 'package:gait_sense/utils/session_summary.dart';
import 'package:gait_sense/utils/session_summary_format.dart';
import 'package:gait_sense/widgets/lists/collapsible_list.dart';
import 'package:gait_sense/widgets/lists/timeline_segment_row.dart';

/// A collapsible list of [TimelineSegmentRow]s for a session's timeline.
class TimelineSegmentList extends StatelessWidget {
  /// Creates a collapsible timeline segment list for [timeline].
  const TimelineSegmentList({required this.timeline, super.key});

  /// The segments to display, in chronological order.
  final List<TimelineSegment> timeline;

  @override
  Widget build(BuildContext context) {
    return CollapsibleList(
      children: [
        for (final segment in timeline)
          TimelineSegmentRow(
            timeRangeLabel: formatTimelineSegmentTimeRange(segment),
            activityLabel: activityLabelHr(segment.label),
            windowCountLabel: windowCountLabelHr(segment.windows),
          ),
      ],
    );
  }
}
