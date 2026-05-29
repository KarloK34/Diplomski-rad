import 'package:equatable/equatable.dart';
import 'package:gait_sense/blocs/sensor_stream/sensor_stream_bloc.dart';
import 'package:gait_sense/models/channel_statistics.dart';
import 'package:gait_sense/models/sensor_sample.dart';

/// State of the sensor stream. Exposed by [SensorStreamBloc].
class SensorStreamState extends Equatable {
  /// Creates a state.
  const SensorStreamState({
    required this.isRunning,
    required this.latestSample,
    required this.measuredHertz,
    required this.sampleCount,
    required this.statistics,
  });

  /// The initial, idle state.
  const SensorStreamState.initial()
    : isRunning = false,
      latestSample = null,
      measuredHertz = 0,
      sampleCount = 0,
      statistics = const {};

  /// Whether the resampler is currently emitting samples.
  final bool isRunning;

  /// The most recently received sample, or null before the first one.
  final SensorSample? latestSample;

  /// Effective sampling rate (Hz) measured over a rolling window.
  final double measuredHertz;

  /// Total number of samples received in the current run.
  final int sampleCount;

  /// Per-channel mean/std accumulated since Start, keyed by the names in
  /// [sensorStatisticsChannels].
  final Map<String, ChannelStatistics> statistics;

  /// Returns a copy with the given fields replaced.
  SensorStreamState copyWith({
    bool? isRunning,
    SensorSample? latestSample,
    double? measuredHertz,
    int? sampleCount,
    Map<String, ChannelStatistics>? statistics,
  }) {
    return SensorStreamState(
      isRunning: isRunning ?? this.isRunning,
      latestSample: latestSample ?? this.latestSample,
      measuredHertz: measuredHertz ?? this.measuredHertz,
      sampleCount: sampleCount ?? this.sampleCount,
      statistics: statistics ?? this.statistics,
    );
  }

  @override
  List<Object?> get props => [
    isRunning,
    latestSample,
    measuredHertz,
    sampleCount,
    statistics,
  ];
}
