import 'package:flutter/material.dart';
import 'package:gait_sense/theme/theme_context.dart';

/// Centered brand mark: icon badge, "Gait Sense" wordmark, and a [tagline].
///
/// Shared by the auth screens so the app identity reads consistently before
/// the sign-in/sign-up form.
class AppLogo extends StatelessWidget {
  /// Creates the brand mark with [tagline] shown under the wordmark.
  const AppLogo({required this.tagline, super.key});

  /// Supporting line shown under the "Gait Sense" wordmark.
  final String tagline;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.analytics_rounded,
            size: 32,
            color: colors.onPrimaryContainer,
          ),
        ),
        SizedBox(height: spacing.sm),
        Text(
          'Gait Sense',
          style: context.textStyles.headlineMedium?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: spacing.xxs),
        Text(
          tagline,
          textAlign: TextAlign.center,
          style: context.textStyles.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
