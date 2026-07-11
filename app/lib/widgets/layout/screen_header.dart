import 'package:flutter/material.dart';
import 'package:gait_sense/theme/theme_context.dart';

/// Screen-level title with a de-emphasized subtitle beneath it.
class ScreenHeader extends StatelessWidget {
  /// Creates a header with [title] and [subtitle].
  const ScreenHeader({required this.title, required this.subtitle, super.key});

  /// Screen title.
  final String title;

  /// Supporting description shown under the title.
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final textStyles = context.textStyles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: textStyles.headlineMedium),
        SizedBox(height: spacing.xs),
        Text(
          subtitle,
          style: textStyles.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
