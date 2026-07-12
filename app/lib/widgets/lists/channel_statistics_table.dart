import 'package:flutter/material.dart';
import 'package:gait_sense/models/channel_statistics.dart';
import 'package:gait_sense/widgets/lists/channel_statistics_row.dart';

/// Scrollable per-channel mean/std table, with dividers grouping the
/// gait-relevant channels (gravity magnitude, userAcceleration).
class ChannelStatisticsTable extends StatelessWidget {
  /// Creates the table from a channel-name-keyed [statistics] map.
  const ChannelStatisticsTable({required this.statistics, super.key});

  /// Statistics keyed by channel name (see [sensorStatisticsChannels]).
  final Map<String, ChannelStatistics> statistics;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const ChannelStatisticsRow(
          channel: 'kanal',
          mean: 'μ',
          standardDeviation: 'σ',
          isHeader: true,
        ),
        const Divider(),
        for (final channel in sensorStatisticsChannels) ...[
          ChannelStatisticsRow(
            channel: channel,
            mean: (statistics[channel]?.mean ?? 0).toStringAsFixed(4),
            standardDeviation: (statistics[channel]?.standardDeviation ?? 0)
                .toStringAsFixed(4),
            highlight:
                channel.startsWith('userAcceleration') ||
                channel == '‖gravity‖',
          ),
          if (channel == '‖gravity‖') const Divider(),
          if (channel == 'userAcceleration.z') const Divider(),
        ],
      ],
    );
  }
}
