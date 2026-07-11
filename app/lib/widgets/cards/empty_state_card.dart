import 'package:flutter/material.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/widgets/cards/app_card.dart';

/// Vertical placeholder card shown when a screen has no data yet: icon,
/// title, message, and an optional call-to-action button.
class EmptyStateCard extends StatelessWidget {
  /// Creates an empty-state placeholder card.
  const EmptyStateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    super.key,
  });

  /// Leading icon.
  final IconData icon;

  /// Primary label.
  final String title;

  /// Supporting description.
  final String message;

  /// Label of the optional call-to-action button.
  final String? actionLabel;

  /// Icon shown on the call-to-action button, if any.
  final IconData? actionIcon;

  /// Called when the call-to-action button is pressed. The button is only
  /// rendered when both this and [actionLabel] are set.
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final colors = context.colors;
    final textStyles = context.textStyles;
    final actionLabel = this.actionLabel;
    final onAction = this.onAction;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 36, color: colors.primary),
          SizedBox(height: spacing.md),
          Text(title, style: textStyles.titleMedium),
          SizedBox(height: spacing.xs),
          Text(
            message,
            style: textStyles.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            SizedBox(height: spacing.md),
            if (actionIcon != null)
              FilledButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon),
                label: Text(actionLabel),
              )
            else
              FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ],
      ),
    );
  }
}
