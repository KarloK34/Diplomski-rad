import 'package:flutter/material.dart';
import 'package:gait_sense/theme/theme_context.dart';

/// Scaffold shared by static info screens (about, privacy): an app bar over a
/// scrollable, evenly spaced column of [children].
class InfoScreenScaffold extends StatelessWidget {
  /// Creates the scaffold with an app bar [title] and section [children].
  const InfoScreenScaffold({
    required this.title,
    required this.children,
    super.key,
  });

  /// App bar title.
  final String title;

  /// Section widgets, rendered in order with a gap between each.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final gap = SizedBox(height: context.spacing.lg);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(context.spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) gap,
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}
