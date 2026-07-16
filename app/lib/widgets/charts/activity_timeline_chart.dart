import 'package:flutter/material.dart';
import 'package:gait_sense/theme/activity_color.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/utils/session_summary.dart';

/// A single proportional band showing the session's activity sequence over
/// time, each segment sized by its window count and colored by activity.
///
/// A plain flex row (not a chart library) keeps the timeline exact and cheap;
/// colors match the distribution chart via the shared activity palette.
class ActivityTimelineChart extends StatelessWidget {
  /// Creates the band for [timeline] (collapsed same-label runs, in order).
  const ActivityTimelineChart({required this.timeline, super.key});

  /// Ordered timeline segments to lay out left-to-right.
  final List<TimelineSegment> timeline;

  @override
  Widget build(BuildContext context) {
    final colors = context.gaitColors;
    final radii = context.radii;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radii.sm),
      child: SizedBox(
        height: 18,
        child: Row(
          children: [
            for (final segment in timeline)
              Expanded(
                flex: segment.windows,
                child: ColoredBox(color: colors.forActivity(segment.label)),
              ),
          ],
        ),
      ),
    );
  }
}
