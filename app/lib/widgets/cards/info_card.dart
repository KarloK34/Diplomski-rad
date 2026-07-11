import 'package:flutter/material.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/widgets/cards/app_card.dart';

/// A titled card containing a vertical list of rows (e.g. `LabeledRow` or
/// `NavigationListTile` entries).
class InfoCard extends StatelessWidget {
  /// Creates a card titled [title] with [rows] stacked beneath it.
  const InfoCard({required this.title, required this.rows, super.key});

  /// Card title.
  final String title;

  /// Rows rendered under the title, in order.
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.textStyles.titleMedium),
          SizedBox(height: context.spacing.sm),
          ...rows,
        ],
      ),
    );
  }
}
