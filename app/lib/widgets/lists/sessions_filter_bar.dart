import 'package:flutter/material.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/utils/sessions_filter.dart';
import 'package:gait_sense/widgets/indicators/pill.dart';
import 'package:gait_sense/widgets/lists/filter_chip_group.dart';

/// Collapsible period + activity filter facets for narrowing the Sessions
/// tab's history list, combined with an implicit AND.
///
/// Starts collapsed — the chip groups took up roughly a third of the screen
/// height, which is too much to show unconditionally on every visit, so they
/// are revealed on demand instead.
class SessionsFilterBar extends StatefulWidget {
  /// Creates a filter bar with [period] and [activity] active, calling
  /// [onPeriodSelected]/[onActivitySelected] when the user picks a different
  /// value in the respective facet.
  const SessionsFilterBar({
    required this.period,
    required this.activity,
    required this.onPeriodSelected,
    required this.onActivitySelected,
    super.key,
  });

  /// The currently active period filter.
  final SessionsPeriodFilter period;

  /// The currently active activity filter.
  final SessionsActivityFilter activity;

  /// Called with the newly picked period filter.
  final ValueChanged<SessionsPeriodFilter> onPeriodSelected;

  /// Called with the newly picked activity filter.
  final ValueChanged<SessionsActivityFilter> onActivitySelected;

  @override
  State<SessionsFilterBar> createState() => _SessionsFilterBarState();
}

class _SessionsFilterBarState extends State<SessionsFilterBar> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(context.radii.md),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: spacing.xs),
            child: Row(
              children: [
                Icon(
                  Icons.filter_list,
                  size: 20,
                  color: context.colors.onSurfaceVariant,
                ),
                SizedBox(width: spacing.xs),
                Text(
                  'Filteri',
                  style: context.textStyles.labelMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                if (!_expanded &&
                    (widget.period != SessionsPeriodFilter.all ||
                        widget.activity != SessionsActivityFilter.all)) ...[
                  SizedBox(width: spacing.xs),
                  Flexible(
                    child: Wrap(
                      spacing: spacing.xxs,
                      runSpacing: spacing.xxs,
                      children: [
                        if (widget.period != SessionsPeriodFilter.all)
                          Pill(
                            label: sessionsPeriodFilterLabelsHr[widget.period]!,
                          ),
                        if (widget.activity != SessionsActivityFilter.all)
                          Pill(
                            label:
                                sessionsActivityFilterLabelsHr[widget
                                    .activity]!,
                          ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: context.colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (_expanded) ...[
          SizedBox(height: spacing.xs),
          FilterChipGroup<SessionsPeriodFilter>(
            label: 'Razdoblje',
            options: SessionsPeriodFilter.values,
            optionLabels: sessionsPeriodFilterLabelsHr,
            selected: widget.period,
            onSelected: widget.onPeriodSelected,
          ),
          SizedBox(height: spacing.sm),
          FilterChipGroup<SessionsActivityFilter>(
            label: 'Aktivnost',
            options: SessionsActivityFilter.values,
            optionLabels: sessionsActivityFilterLabelsHr,
            selected: widget.activity,
            onSelected: widget.onActivitySelected,
          ),
        ],
      ],
    );
  }
}
