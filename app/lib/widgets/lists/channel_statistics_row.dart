import 'package:flutter/material.dart';
import 'package:gait_sense/theme/theme_context.dart';

/// One row of a `ChannelStatisticsTable`: channel name, mean, and standard
/// deviation.
class ChannelStatisticsRow extends StatelessWidget {
  /// Creates a data row, or a bold column-heading row when [isHeader] is
  /// true.
  const ChannelStatisticsRow({
    required this.channel,
    required this.mean,
    required this.standardDeviation,
    this.highlight = false,
    this.isHeader = false,
    super.key,
  });

  /// Channel label.
  final String channel;

  /// Pre-formatted mean value.
  final String mean;

  /// Pre-formatted standard deviation value.
  final String standardDeviation;

  /// Whether to bold the numeric columns (e.g. for gait-relevant channels).
  final bool highlight;

  /// Renders as the bold column-heading row instead of a data row.
  final bool isHeader;

  @override
  Widget build(BuildContext context) {
    final appTextStyles = context.appTextStyles;
    final numericStyle = highlight || isHeader
        ? appTextStyles.monospaceDataBold
        : appTextStyles.monospaceData;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              channel,
              style: isHeader ? appTextStyles.tableHeader : null,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(mean, textAlign: TextAlign.right, style: numericStyle),
          ),
          Expanded(
            flex: 2,
            child: Text(
              standardDeviation,
              textAlign: TextAlign.right,
              style: numericStyle,
            ),
          ),
        ],
      ),
    );
  }
}
