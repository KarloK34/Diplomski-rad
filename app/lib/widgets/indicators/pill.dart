import 'package:flutter/material.dart';
import 'package:gait_sense/theme/theme_context.dart';

/// A compact rounded label with an optional leading color dot or icon, used for
/// at-a-glance session tags (activity, cadence, speed).
class Pill extends StatelessWidget {
  /// Creates a pill showing [label], optionally led by [dotColor] or [icon].
  const Pill({required this.label, this.dotColor, this.icon, super.key});

  /// Pill text.
  final String label;

  /// Leading dot color (e.g. an activity color); omitted when null.
  final Color? dotColor;

  /// Leading icon, shown when [dotColor] is null.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.sm,
        vertical: spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(context.radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotColor case final dotColor?) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: spacing.xxs),
          ] else if (icon case final icon?) ...[
            Icon(icon, size: 14, color: context.colors.onSurfaceVariant),
            SizedBox(width: spacing.xxs),
          ],
          Text(label, style: context.textStyles.bodySmall),
        ],
      ),
    );
  }
}
