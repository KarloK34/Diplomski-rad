import 'package:flutter/material.dart';
import 'package:gait_sense/models/metric_info.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/widgets/buttons/metric_info_button.dart';

/// A muted label stacked above its value, e.g. inside a
/// `ClassificationQualitySection` or `GaitParametersSection`.
class LabeledValueRow extends StatelessWidget {
  /// Creates a row pairing [label] with [value], with an optional [info]
  /// button explaining the metric.
  const LabeledValueRow({
    required this.label,
    required this.value,
    this.info,
    super.key,
  });

  /// Field name.
  final String label;

  /// Field value, pre-formatted for display.
  final String value;

  /// Explanation shown via an info button next to [label], if any.
  final MetricInfo? info;

  @override
  Widget build(BuildContext context) {
    final muted = context.textStyles.bodySmall?.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.spacing.xxs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (info case final info?)
            Row(
              children: [
                Expanded(child: Text(label, style: muted)),
                MetricInfoButton(info: info),
              ],
            )
          else
            Text(label, style: muted),
          const SizedBox(height: 2),
          Text(value),
        ],
      ),
    );
  }
}
