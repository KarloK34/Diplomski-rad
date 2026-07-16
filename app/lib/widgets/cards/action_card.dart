import 'package:flutter/material.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/widgets/cards/app_card.dart';

/// Icon plus title/subtitle row with a single call-to-action button.
class ActionCard extends StatelessWidget {
  /// Creates an action prompt card.
  const ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onPressed,
    this.iconColor,
    super.key,
  });

  /// Leading icon.
  final IconData icon;

  /// Primary label.
  final String title;

  /// Supporting description.
  final String subtitle;

  /// Label of the trailing [FilledButton].
  final String actionLabel;

  /// Called when the action button is pressed.
  final VoidCallback onPressed;

  /// Color of the leading icon; defaults to the theme's primary color.
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final colors = context.colors;
    final textStyles = context.textStyles;
    return AppCard(
      child: Row(
        children: [
          Icon(icon, size: 36, color: iconColor ?? colors.primary),
          SizedBox(width: spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textStyles.titleMedium),
                SizedBox(height: spacing.xxs),
                Text(
                  subtitle,
                  style: textStyles.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: spacing.sm),
          FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              minimumSize: Size(0, spacing.touchTarget),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
