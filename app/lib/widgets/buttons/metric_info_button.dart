import 'package:flutter/material.dart';
import 'package:gait_sense/models/metric_info.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/widgets/dialogs/metric_info_sheet.dart';

/// Small icon button that opens `showMetricInfoSheet` for [info].
class MetricInfoButton extends StatelessWidget {
  /// Creates an info button for [info].
  const MetricInfoButton({required this.info, super.key});

  /// The explanation shown when tapped.
  final MetricInfo info;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.info_outline, size: 18),
      visualDensity: VisualDensity.compact,
      color: context.colors.onSurfaceVariant,
      tooltip: '${info.title} - objašnjenje',
      onPressed: () => showMetricInfoSheet(context, info),
    );
  }
}
