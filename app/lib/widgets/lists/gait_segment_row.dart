import 'package:flutter/material.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/widgets/lists/segment_row_line.dart';

/// One level-walking gait-analysis candidate: time range, window count, and
/// per-label window counts.
class GaitSegmentRow extends StatelessWidget {
  /// Creates a row summarizing a suitable gait segment.
  const GaitSegmentRow({
    required this.timeRangeLabel,
    required this.windowCountLabel,
    super.key,
  });

  /// Pre-formatted analysis start-end offsets.
  final String timeRangeLabel;

  /// Pre-formatted window count.
  final String windowCountLabel;

  @override
  Widget build(BuildContext context) {
    final muted = context.textStyles.bodySmall?.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.spacing.xxs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentRowLine(
            timeRangeLabel: timeRangeLabel,
            content: const Text('Hodanje po ravnom'),
            trailingLabel: windowCountLabel,
            style: muted,
          ),
        ],
      ),
    );
  }
}
