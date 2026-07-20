import 'package:flutter/material.dart';
import 'package:gait_sense/models/metric_info.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/widgets/buttons/metric_info_button.dart';
import 'package:gait_sense/widgets/cards/app_card.dart';

/// A titled card wrapping an arbitrary [child] — used for charts, which need a
/// widget body rather than the row list an `InfoCard` takes.
class ChartCard extends StatelessWidget {
  /// Creates a card titled [title] (with optional [subtitle]) around [child],
  /// with an optional [info] button explaining the section.
  const ChartCard({
    required this.title,
    required this.child,
    this.subtitle,
    this.info,
    super.key,
  });

  /// Card title.
  final String title;

  /// Optional secondary line under the title.
  final String? subtitle;

  /// Card body.
  final Widget child;

  /// Explanation shown via an info button next to [title], if any.
  final MetricInfo? info;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: context.textStyles.titleMedium),
              ),
              if (info case final info?) MetricInfoButton(info: info),
            ],
          ),
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
