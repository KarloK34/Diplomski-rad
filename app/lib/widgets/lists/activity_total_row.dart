import 'package:flutter/material.dart';
import 'package:gait_sense/theme/theme_context.dart';

/// An activity name with its formatted time/percentage share, right-aligned.
class ActivityTotalRow extends StatelessWidget {
  /// Creates a row pairing [activityLabel] with its [valueLabel].
  const ActivityTotalRow({
    required this.activityLabel,
    required this.valueLabel,
    super.key,
  });

  /// Croatian-mapped activity name.
  final String activityLabel;

  /// Pre-formatted time and percentage share.
  final String valueLabel;

  @override
  Widget build(BuildContext context) {
    final muted = context.textStyles.bodyMedium?.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.spacing.xxs),
      child: Row(
        children: [
          Expanded(child: Text(activityLabel)),
          Text(valueLabel, style: muted),
        ],
      ),
    );
  }
}
