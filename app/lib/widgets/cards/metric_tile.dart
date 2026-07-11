import 'package:flutter/material.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/widgets/cards/app_card.dart';

/// Compact label/value tile used in metric grids.
class MetricTile extends StatelessWidget {
  /// Creates a tile showing [value] under [label].
  const MetricTile({required this.label, required this.value, super.key});

  /// Metric name.
  final String label;

  /// Metric value, pre-formatted for display.
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: context.textStyles.labelLarge?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          Text(value, style: context.appTextStyles.dataDisplay),
        ],
      ),
    );
  }
}
