import 'package:equatable/equatable.dart';
import 'package:gait_sense/models/sensor_sample.dart';

/// Base class for sensor-stream bloc events.
sealed class SensorStreamEvent extends Equatable {
  const SensorStreamEvent();

  @override
  List<Object?> get props => [];
}

/// Requests the sensor stream to start sampling.
final class SensorStreamStarted extends SensorStreamEvent {
  /// Creates the start event.
  const SensorStreamStarted();
}

/// Requests the sensor stream to stop sampling.
final class SensorStreamStopped extends SensorStreamEvent {
  /// Creates the stop event.
  const SensorStreamStopped();
}

/// Internal event carrying one resampled sample from the service.
final class SensorSampleReceived extends SensorStreamEvent {
  /// Creates the event with the received [sample].
  const SensorSampleReceived(this.sample);

  /// The newly resampled sample.
  final SensorSample sample;

  @override
  List<Object?> get props => [sample];
}
