import 'package:equatable/equatable.dart';
import 'package:gait_sense/models/feature_window.dart';

/// Base class for prediction bloc events.
sealed class PredictionEvent extends Equatable {
  const PredictionEvent();

  @override
  List<Object?> get props => [];
}

/// Starts consuming feature windows and producing predictions.
final class PredictionStarted extends PredictionEvent {
  /// Creates the start event.
  const PredictionStarted();
}

/// Stops consumption.
final class PredictionStopped extends PredictionEvent {
  /// Creates the stop event.
  const PredictionStopped();
}

/// Internal event carrying one feature window to classify.
final class PredictionWindowReceived extends PredictionEvent {
  /// Creates the event with the received [window].
  const PredictionWindowReceived(this.window);

  /// The window to run inference on.
  final FeatureWindow window;

  @override
  List<Object?> get props => [window];
}
