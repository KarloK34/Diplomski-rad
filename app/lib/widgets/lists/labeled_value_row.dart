import 'package:flutter/material.dart';
import 'package:gait_sense/theme/theme_context.dart';

/// A muted label stacked above its value, e.g. inside a
/// `SessionQualitySection`.
class LabeledValueRow extends StatelessWidget {
  /// Creates a row pairing [label] with [value].
  const LabeledValueRow({required this.label, required this.value, super.key});

  /// Field name.
  final String label;

  /// Field value, pre-formatted for display.
  final String value;

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
          Text(label, style: muted),
          const SizedBox(height: 2),
          Text(value),
        ],
      ),
    );
  }
}
