import 'package:flutter/material.dart';

/// A [ListTile] with a leading icon and, by default, a trailing chevron —
/// the standard row for navigable or previewed settings/insight entries.
class NavigationListTile extends StatelessWidget {
  /// Creates a navigation-style list row.
  const NavigationListTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.showChevron = true,
    super.key,
  });

  /// Leading icon.
  final IconData icon;

  /// Primary label.
  final String title;

  /// Optional supporting description.
  final String? subtitle;

  /// Called when the row is tapped; the row is inert when null.
  final VoidCallback? onTap;

  /// Whether to show the trailing chevron. Set to false for informational
  /// rows that aren't navigable.
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: showChevron ? const Icon(Icons.chevron_right) : null,
      onTap: onTap,
    );
  }
}
