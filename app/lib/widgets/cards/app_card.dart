import 'package:flutter/material.dart';
import 'package:gait_sense/theme/theme_context.dart';

/// Standard content card: a [Card] with the app's default inner padding.
///
/// The base building block for the other card widgets in this library —
/// reach for this directly whenever a screen needs an ad-hoc card that none
/// of the more specific widgets cover.
class AppCard extends StatelessWidget {
  /// Wraps [child] in a themed card.
  const AppCard({required this.child, this.padding, this.onTap, super.key});

  /// Card content.
  final Widget child;

  /// Inner padding; defaults to the standard `spacing.md` inset.
  final EdgeInsetsGeometry? padding;

  /// Called when the card is tapped; the card is inert (and shows no ink
  /// feedback) when null.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding ?? EdgeInsets.all(context.spacing.md),
      child: child,
    );
    if (onTap == null) return Card(child: content);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}
