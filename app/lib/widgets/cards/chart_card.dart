import 'package:flutter/material.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/widgets/cards/app_card.dart';

/// A titled card wrapping an arbitrary [child] — used for charts, which need a
/// widget body rather than the row list an `InfoCard` takes.
class ChartCard extends StatelessWidget {
  /// Creates a card titled [title] (with optional [subtitle]) around [child].
  const ChartCard({
    required this.title,
    required this.child,
    this.subtitle,
    super.key,
  });

  /// Card title.
  final String title;

  /// Optional secondary line under the title.
  final String? subtitle;

  /// Card body.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.textStyles.titleMedium),
          if (subtitle case final subtitle?) ...[
            SizedBox(height: spacing.xxs),
            Text(
              subtitle,
              style: context.textStyles.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
          SizedBox(height: spacing.md),
          child,
        ],
      ),
    );
  }
}
