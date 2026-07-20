import 'package:flutter/material.dart';
import 'package:gait_sense/models/metric_info.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/widgets/buttons/metric_info_button.dart';
import 'package:gait_sense/widgets/cards/app_card.dart';

/// Compact label/value tile used in metric grids, with an optional [info]
/// button explaining the metric.
class MetricTile extends StatelessWidget {
  /// Creates a tile showing [value] under [label].
  const MetricTile({
    required this.label,
    required this.value,
    this.info,
    super.key,
  });

  /// Metric name.
  final String label;

  /// Metric value, pre-formatted for display.
  final String value;

  /// Explanation shown via an info button next to [label], if any.
  final MetricInfo? info;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: context.textStyles.labelLarge?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
              if (info case final info?) MetricInfoButton(info: info),
            ],
          ),
          // Scale down (never wrap) so multi-word values like "110 kor/min"
          // stay on one line within the fixed tile height.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: context.appTextStyles.dataDisplay),
          ),
        ],
      ),
    );
  }
}
