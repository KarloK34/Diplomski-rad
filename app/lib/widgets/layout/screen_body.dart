import 'package:flutter/material.dart';
import 'package:gait_sense/theme/theme_context.dart';

/// Scrollable screen content with the standard screen margin applied.
class ScreenBody extends StatelessWidget {
  /// Creates the screen body from [children].
  const ScreenBody({required this.children, super.key});

  /// Content rendered in a [ListView], in order.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: EdgeInsets.all(context.spacing.screenMargin),
        children: children,
      ),
    );
  }
}
