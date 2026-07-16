import 'package:flutter/material.dart';
import 'package:gait_sense/theme/theme_context.dart';

/// A captioned, single-select row of [ChoiceChip]s for one filter facet.
class FilterChipGroup<T> extends StatelessWidget {
  /// Creates a chip group titled [label], offering [options] (each rendered
  /// via [optionLabels]) with [selected] active, calling [onSelected] when
  /// the user picks a different option.
  const FilterChipGroup({
    required this.label,
    required this.options,
    required this.optionLabels,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  /// Caption shown above the chips, naming this facet.
  final String label;

  /// The selectable values, in display order.
  final List<T> options;

  /// Display label for each value in [options].
  final Map<T, String> optionLabels;

  /// The currently active value.
  final T selected;

  /// Called with the newly picked value.
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.textStyles.labelMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        SizedBox(height: spacing.xs),
        Wrap(
          spacing: spacing.xs,
          runSpacing: spacing.xs,
          children: [
            for (final option in options)
              ChoiceChip(
                label: Text(optionLabels[option]!),
                selected: option == selected,
                onSelected: (_) => onSelected(option),
              ),
          ],
        ),
      ],
    );
  }
}
