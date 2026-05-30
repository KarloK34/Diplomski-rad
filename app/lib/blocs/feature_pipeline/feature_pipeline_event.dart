import 'package:equatable/equatable.dart';
import 'package:gait_sense/models/sensor_sample.dart';

/// Base class for feature-pipeline bloc events.
sealed class FeaturePipelineEvent extends Equatable {
  const FeaturePipelineEvent();

  @override
  List<Object?> get props => [];
}

/// Starts consuming samples from the sensor stream and producing windows.
final class FeaturePipelineStarted extends FeaturePipelineEvent {
  /// Creates the start event.
  const FeaturePipelineStarted();
}

/// Stops consumption and clears the trailing context buffer.
final class FeaturePipelineStopped extends FeaturePipelineEvent {
  /// Creates the stop event.
  const FeaturePipelineStopped();
}

/// Internal event carrying one sample from the sensor stream.
final class FeaturePipelineSampleReceived extends FeaturePipelineEvent {
  /// Creates the event with the received [sample].
  const FeaturePipelineSampleReceived(this.sample);

  /// The sample to feed into the streaming extractor.
  final SensorSample sample;

  @override
  List<Object?> get props => [sample];
}
