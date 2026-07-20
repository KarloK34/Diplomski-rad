import 'package:flutter/material.dart';
import 'package:gait_sense/models/metric_info.dart';
import 'package:gait_sense/theme/theme_context.dart';

/// Shows a bottom sheet explaining [info].
Future<void> showMetricInfoSheet(BuildContext context, MetricInfo info) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final spacing = sheetContext.spacing;
      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            spacing.md,
            spacing.xxs,
            spacing.md,
            spacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(info.title, style: sheetContext.textStyles.titleLarge),
              SizedBox(height: spacing.sm),
              Text(info.description, style: sheetContext.textStyles.bodyMedium),
            ],
          ),
        ),
      );
    },
  );
}
