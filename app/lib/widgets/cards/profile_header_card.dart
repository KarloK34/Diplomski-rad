import 'package:flutter/material.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/widgets/cards/app_card.dart';

/// Avatar with a name/subtitle row, used atop the profile screen.
class ProfileHeaderCard extends StatelessWidget {
  /// Creates a profile header card for [name].
  const ProfileHeaderCard({
    required this.name,
    required this.subtitle,
    this.avatarIcon = Icons.person,
    super.key,
  });

  /// Display name.
  final String name;

  /// Supporting description under the name.
  final String subtitle;

  /// Icon shown inside the avatar circle.
  final IconData avatarIcon;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final colors = context.colors;
    final textStyles = context.textStyles;
    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: colors.primaryContainer,
            child: Icon(avatarIcon, color: colors.onPrimaryContainer),
          ),
          SizedBox(width: spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: textStyles.titleMedium),
                SizedBox(height: spacing.xxs),
                Text(
                  subtitle,
                  style: textStyles.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
