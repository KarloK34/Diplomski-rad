import 'package:equatable/equatable.dart';
import 'package:gait_sense/models/activity_prediction.dart';

/// Base class for UI-isolate recording-session events.
sealed class UiEvent extends Equatable {
  /// Const base constructor.
  const UiEvent();

  @override
  List<Object?> get props => [];
}

/// User requested to begin a recording session.
final class UiRecordingStarted extends UiEvent {
  /// Creates the start event.
  const UiRecordingStarted();
}

/// User requested to end the active recording session.
final class UiRecordingStopped extends UiEvent {
  /// Creates the stop event.
  const UiRecordingStopped();
}

/// Discards the finished-session result and returns to the idle state.
final class UiReset extends UiEvent {
  /// Creates the reset event.
  const UiReset();
}

/// Internal: one prediction arrived from the service isolate.
final class UiPredictionReceived extends UiEvent {
  /// Creates the event carrying the received [prediction].
  const UiPredictionReceived(this.prediction);

  /// The prediction decoded from the service-isolate message.
  final ActivityPrediction prediction;

  @override
  List<Object?> get props => [prediction];
}

/// Internal: periodic tick that refreshes the elapsed-time readout and checks
/// the session duration limit.
final class UiTicked extends UiEvent {
  /// Creates the tick event.
  const UiTicked();
}

/// Internal: the session reached `UiBloc.maxSessionDuration` and was stopped
/// automatically.
final class UiSessionLimitReached extends UiEvent {
  /// Creates the limit-reached event.
  const UiSessionLimitReached();
}
