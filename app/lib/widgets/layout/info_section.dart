import 'package:flutter/material.dart';
import 'package:gait_sense/theme/theme_context.dart';

/// A titled paragraph, as used on static info screens (about, privacy).
class InfoSection extends StatelessWidget {
  /// Creates a section with [title] and [body].
  const InfoSection({required this.title, required this.body, super.key});

  /// Section heading.
  final String title;

  /// Section body text.
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: context.textStyles.titleMedium),
        SizedBox(height: context.spacing.xxs),
        Text(
          body,
          style: context.textStyles.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
