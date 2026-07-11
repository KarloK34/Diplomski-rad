import 'package:flutter/material.dart';
import 'package:gait_sense/theme/theme_context.dart';

/// Responsive grid of equally sized tiles (e.g. `MetricTile`s).
///
/// Switches from 2 to 4 columns once the available width passes 560 dp so
/// wide phones/tablets don't waste horizontal space.
class MetricGrid extends StatelessWidget {
  /// Creates a grid laying out [tiles].
  const MetricGrid({required this.tiles, super.key});

  /// The tiles to lay out.
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 560;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isWide ? 4 : 2,
          mainAxisSpacing: spacing.sm,
          crossAxisSpacing: spacing.sm,
          childAspectRatio: isWide ? 1.65 : 1.35,
          children: tiles,
        );
      },
    );
  }
}
