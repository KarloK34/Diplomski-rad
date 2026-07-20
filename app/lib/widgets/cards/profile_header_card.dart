import 'package:flutter/material.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/widgets/avatars/user_avatar.dart';
import 'package:gait_sense/widgets/cards/app_card.dart';

/// Avatar with a name/subtitle row, used atop the profile screen.
class ProfileHeaderCard extends StatelessWidget {
  /// Creates a profile header card for [name].
  const ProfileHeaderCard({
    required this.name,
    required this.subtitle,
    this.avatarIcon = Icons.person,
    this.avatarUrl,
    this.onEditTap,
    super.key,
  });

  /// Display name.
  final String name;

  /// Supporting description under the name.
  final String subtitle;

  /// Icon shown inside the avatar circle when [avatarUrl] is null.
  final IconData avatarIcon;

  /// Account picture (e.g. the Google profile photo). Null falls back to
  /// [avatarIcon] — email/password accounts have no such picture.
  final String? avatarUrl;

  /// Called when the card is tapped to edit [name]; shows a trailing edit
  /// icon and makes the whole card tappable. The card is inert when null.
  final VoidCallback? onEditTap;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final colors = context.colors;
    final textStyles = context.textStyles;
    return AppCard(
      onTap: onEditTap,
      child: Row(
        children: [
          UserAvatar(radius: 28, imageUrl: avatarUrl, icon: avatarIcon),
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
          if (onEditTap != null)
            Icon(Icons.edit_outlined, color: colors.onSurfaceVariant),
        ],
      ),
    );
  }
}
