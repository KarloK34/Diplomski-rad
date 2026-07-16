import 'package:flutter/material.dart';

/// A vertical list that shows only [collapsedCount] children at first and
/// reveals the rest behind a toggle, so a long list does not bury the sections
/// below it behind excessive scrolling.
class CollapsibleList extends StatefulWidget {
  /// Creates a collapsible list of [children].
  const CollapsibleList({
    required this.children,
    this.collapsedCount = 5,
    super.key,
  });

  /// The full set of rows to display.
  final List<Widget> children;

  /// How many rows remain visible while collapsed.
  final int collapsedCount;

  @override
  State<CollapsibleList> createState() => _CollapsibleListState();
}

class _CollapsibleListState extends State<CollapsibleList> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final canCollapse = widget.children.length > widget.collapsedCount;
    final visible = _expanded || !canCollapse
        ? widget.children
        : widget.children.take(widget.collapsedCount).toList();
    final hiddenCount = widget.children.length - widget.collapsedCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...visible,
        if (canCollapse)
          TextButton.icon(
            onPressed: () => setState(() => _expanded = !_expanded),
            icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            label: Text(
              _expanded ? 'Prikaži manje' : 'Prikaži još ($hiddenCount)',
            ),
          ),
      ],
    );
  }
}
