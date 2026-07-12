import 'package:flutter/material.dart';

/// Shared time-label + content + trailing-count row layout used by
/// TimelineSegmentRow and GaitSegmentRow.
class SegmentRowLine extends StatelessWidget {
  /// Creates a row laying out [timeRangeLabel], [content], and
  /// [trailingLabel] with [style] applied to the muted labels.
  const SegmentRowLine({
    required this.timeRangeLabel,
    required this.content,
    required this.trailingLabel,
    required this.style,
    super.key,
  });

  /// Pre-formatted start-end offsets, given a fixed-width leading column.
  final String timeRangeLabel;

  /// The row's main content, given the remaining width.
  final Widget content;

  /// Pre-formatted trailing count.
  final String trailingLabel;

  /// Text style applied to [timeRangeLabel] and [trailingLabel].
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 120, child: Text(timeRangeLabel, style: style)),
        Expanded(child: content),
        Text(trailingLabel, style: style),
      ],
    );
  }
}
