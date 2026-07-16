import 'package:flutter/material.dart';
import 'package:gait_sense/theme/theme_context.dart';

/// Footer control for an incrementally revealed list.
///
/// "Prikaži još" reveals [pageSize] more items at a time — never the rest of
/// the list at once, so a long history doesn't dump hundreds of rows into
/// view from a single tap. "Prikaži manje" collapses back to the first page.
class ShowMoreFooter extends StatelessWidget {
  /// Creates a show-more/show-less footer.
  const ShowMoreFooter({
    required this.hiddenCount,
    required this.canShowLess,
    required this.pageSize,
    required this.onShowMore,
    required this.onShowLess,
    super.key,
  });

  /// How many filtered items are not currently visible.
  final int hiddenCount;

  /// Whether more than one page is currently revealed.
  final bool canShowLess;

  /// How many items "Prikaži još" reveals per tap.
  final int pageSize;

  /// Called when "Prikaži još" is tapped.
  final VoidCallback onShowMore;

  /// Called when "Prikaži manje" is tapped.
  final VoidCallback onShowLess;

  @override
  Widget build(BuildContext context) {
    if (hiddenCount <= 0 && !canShowLess) return const SizedBox.shrink();

    final nextPageSize = hiddenCount < pageSize ? hiddenCount : pageSize;
    return Wrap(
      spacing: context.spacing.sm,
      children: [
        if (hiddenCount > 0)
          TextButton.icon(
            onPressed: onShowMore,
            icon: const Icon(Icons.expand_more),
            label: Text('Prikaži još ($nextPageSize)'),
          ),
        if (canShowLess)
          TextButton.icon(
            onPressed: onShowLess,
            icon: const Icon(Icons.expand_less),
            label: const Text('Prikaži manje'),
          ),
      ],
    );
  }
}
