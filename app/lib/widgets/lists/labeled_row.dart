import 'package:flutter/material.dart';
import 'package:gait_sense/theme/theme_context.dart';

/// A label on the left and its value right-aligned, e.g. inside an
/// `InfoCard`.
class LabeledRow extends StatelessWidget {
  /// Creates a row pairing [label] with [value].
  const LabeledRow({required this.label, required this.value, super.key});

  /// Field name.
  final String label;

  /// Field value, pre-formatted for display.
  final String value;

  @override
  Widget build(BuildContext context) {
    final textStyles = context.textStyles;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.spacing.xxs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: textStyles.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
          Text(value, style: textStyles.bodyMedium),
        ],
      ),
    );
  }
}
