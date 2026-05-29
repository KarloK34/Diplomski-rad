import 'package:equatable/equatable.dart';

/// Statistics channel keys in display order.
const List<String> sensorStatisticsChannels = [
  'gravity.x',
  'gravity.y',
  'gravity.z',
  '‖gravity‖',
  'userAcceleration.x',
  'userAcceleration.y',
  'userAcceleration.z',
  'rotationRate.x',
  'rotationRate.y',
  'rotationRate.z',
];

/// An immutable snapshot of a channel's running mean and (population) standard
/// deviation, accumulated since the current run started.
class ChannelStatistics extends Equatable {
  /// Creates a snapshot.
  const ChannelStatistics({
    required this.mean,
    required this.standardDeviation,
  });

  /// A zeroed snapshot, used before any sample has arrived.
  const ChannelStatistics.zero() : mean = 0, standardDeviation = 0;

  /// Running mean of the channel.
  final double mean;

  /// Running population standard deviation (denominator N) of the channel.
  final double standardDeviation;

  @override
  List<Object?> get props => [mean, standardDeviation];
}
