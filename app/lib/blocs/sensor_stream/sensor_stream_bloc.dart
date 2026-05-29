import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/sensor_stream/sensor_stream_event.dart';
import 'package:gait_sense/blocs/sensor_stream/sensor_stream_state.dart';
import 'package:gait_sense/models/channel_statistics.dart';
import 'package:gait_sense/models/sensor_sample.dart';
import 'package:gait_sense/services/sensor_service.dart';

/// Number of recent samples used to estimate the effective sampling rate.
const int _rateWindowSize = 200;

/// Numerically stable running mean/variance (Welford, 1962).
class _RunningStatistics {
  int _count = 0;
  double _mean = 0;
  double _sumOfSquaredDeltas = 0;

  void add(double value) {
    _count++;
    final delta = value - _mean;
    _mean += delta / _count;
    _sumOfSquaredDeltas += delta * (value - _mean);
  }

  void reset() {
    _count = 0;
    _mean = 0;
    _sumOfSquaredDeltas = 0;
  }

  ChannelStatistics snapshot() {
    if (_count == 0) return const ChannelStatistics.zero();
    // Population variance (denominator N), consistent with the per-window
    // normalization the feature pipeline uses.
    final variance = _sumOfSquaredDeltas / _count;
    return ChannelStatistics(
      mean: _mean,
      standardDeviation: sqrt(variance),
    );
  }
}

/// Wraps [SensorService] as a BLoC: forwards Start/Stop intents to the service,
/// subscribes to its sample stream, and exposes the latest sample plus a
/// measured sampling rate computed over a rolling window of timestamps.
class SensorStreamBloc extends Bloc<SensorStreamEvent, SensorStreamState> {
  /// Creates the bloc around a [SensorService].
  SensorStreamBloc({required this._sensorService})
    : super(const SensorStreamState.initial()) {
    on<SensorStreamStarted>(_onStarted);
    on<SensorStreamStopped>(_onStopped);
    on<SensorSampleReceived>(_onSampleReceived);
  }

  final SensorService _sensorService;
  StreamSubscription<void>? _sampleSubscription;

  /// Timestamps of the most recent samples, capped at [_rateWindowSize].
  final Queue<DateTime> _recentTimestamps = ListQueue<DateTime>();

  /// One running accumulator per channel in [sensorStatisticsChannels].
  final Map<String, _RunningStatistics> _channelStatistics = {
    for (final channel in sensorStatisticsChannels)
      channel: _RunningStatistics(),
  };

  Future<void> _onStarted(
    SensorStreamStarted event,
    Emitter<SensorStreamState> emit,
  ) async {
    if (state.isRunning) return;
    _recentTimestamps.clear();
    for (final accumulator in _channelStatistics.values) {
      accumulator.reset();
    }
    _sensorService.start();
    _sampleSubscription = _sensorService.samples.listen(
      (sample) => add(SensorSampleReceived(sample)),
    );
    emit(
      const SensorStreamState(
        isRunning: true,
        latestSample: null,
        measuredHertz: 0,
        sampleCount: 0,
        statistics: {},
      ),
    );
  }

  Future<void> _onStopped(
    SensorStreamStopped event,
    Emitter<SensorStreamState> emit,
  ) async {
    await _sampleSubscription?.cancel();
    _sampleSubscription = null;
    await _sensorService.stop();
    emit(state.copyWith(isRunning: false, measuredHertz: 0));
  }

  void _onSampleReceived(
    SensorSampleReceived event,
    Emitter<SensorStreamState> emit,
  ) {
    _recentTimestamps.addLast(event.sample.timestamp);
    while (_recentTimestamps.length > _rateWindowSize) {
      _recentTimestamps.removeFirst();
    }
    _accumulate(event.sample);
    emit(
      state.copyWith(
        latestSample: event.sample,
        sampleCount: state.sampleCount + 1,
        measuredHertz: _estimateHertz(),
        statistics: {
          for (final entry in _channelStatistics.entries)
            entry.key: entry.value.snapshot(),
        },
      ),
    );
  }

  void _accumulate(SensorSample sample) {
    final gravityMagnitude = sqrt(
      sample.gravityX * sample.gravityX +
          sample.gravityY * sample.gravityY +
          sample.gravityZ * sample.gravityZ,
    );
    _channelStatistics['gravity.x']!.add(sample.gravityX);
    _channelStatistics['gravity.y']!.add(sample.gravityY);
    _channelStatistics['gravity.z']!.add(sample.gravityZ);
    _channelStatistics['‖gravity‖']!.add(gravityMagnitude);
    _channelStatistics['userAcceleration.x']!.add(sample.userAccelerationX);
    _channelStatistics['userAcceleration.y']!.add(sample.userAccelerationY);
    _channelStatistics['userAcceleration.z']!.add(sample.userAccelerationZ);
    _channelStatistics['rotationRate.x']!.add(sample.rotationRateX);
    _channelStatistics['rotationRate.y']!.add(sample.rotationRateY);
    _channelStatistics['rotationRate.z']!.add(sample.rotationRateZ);
  }

  /// Estimates Hz from the rolling timestamp window.
  double _estimateHertz() {
    if (_recentTimestamps.length < 2) return 0;
    final spanMicroseconds = _recentTimestamps.last
        .difference(_recentTimestamps.first)
        .inMicroseconds;
    if (spanMicroseconds <= 0) return 0;
    final intervals = _recentTimestamps.length - 1;
    return intervals * 1e6 / spanMicroseconds;
  }

  @override
  Future<void> close() async {
    await _sampleSubscription?.cancel();
    await _sensorService.dispose();
    return super.close();
  }
}
