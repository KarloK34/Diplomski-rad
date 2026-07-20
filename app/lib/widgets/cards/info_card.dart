import 'package:flutter/material.dart';
import 'package:gait_sense/models/metric_info.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/widgets/buttons/metric_info_button.dart';
import 'package:gait_sense/widgets/cards/app_card.dart';

/// A titled card containing a vertical list of rows (e.g. `LabeledRow` or
/// `NavigationListTile` entries).
class InfoCard extends StatelessWidget {
  /// Creates a card titled [title] with [rows] stacked beneath it, with an
  /// optional [info] button explaining the section.
  const InfoCard({
    required this.title,
    required this.rows,
    this.info,
    super.key,
  });

  /// Card title.
  final String title;

  /// Rows rendered under the title, in order.
  final List<Widget> rows;

  /// Explanation shown via an info button next to [title], if any.
  final MetricInfo? info;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: context.textStyles.titleMedium),
              ),
              if (info case final info?) MetricInfoButton(info: info),
            ],
          ),
          SizedBox(height: context.spacing.sm),
          ...rows,
        ],
      ),
    );
  }
}
