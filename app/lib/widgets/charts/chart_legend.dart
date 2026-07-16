import 'package:flutter/material.dart';
import 'package:gait_sense/theme/theme_context.dart';

/// One entry in a [ChartLegend]: a colored swatch and its label.
class ChartLegendEntry {
  /// Creates a legend entry.
  const ChartLegendEntry({required this.color, required this.label});

  /// Swatch color, matching the series it describes.
  final Color color;

  /// Human-readable series name.
  final String label;
}

/// A wrapping row of colored swatches and labels, shared by the charts.
class ChartLegend extends StatelessWidget {
  /// Creates a legend for [entries].
  const ChartLegend({required this.entries, super.key});

  /// The series shown in the legend.
  final List<ChartLegendEntry> entries;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Wrap(
      spacing: spacing.md,
      runSpacing: spacing.xs,
      children: [
        for (final entry in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: entry.color,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: spacing.xxs),
              Text(entry.label, style: context.textStyles.bodySmall),
            ],
          ),
      ],
    );
  }
}
