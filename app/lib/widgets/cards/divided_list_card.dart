import 'package:flutter/material.dart';

/// A [Card] containing a vertical list of [items] (e.g.
/// `NavigationListTile`s) separated by thin dividers.
class DividedListCard extends StatelessWidget {
  /// Creates a card listing [items] with dividers between them.
  const DividedListCard({required this.items, super.key});

  /// Rows to render, separated by a 1px [Divider].
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            items[i],
          ],
        ],
      ),
    );
  }
}
