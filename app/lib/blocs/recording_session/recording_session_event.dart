import 'package:equatable/equatable.dart';
import 'package:gait_sense/models/activity_prediction.dart';

/// Base class for recording-session bloc events.
sealed class RecordingSessionEvent extends Equatable {
  /// Const base constructor.
  const RecordingSessionEvent();

  @override
  List<Object?> get props => [];
}

/// User requested to begin a recording session.
final class RecordingSessionStarted extends RecordingSessionEvent {
  /// Creates the start event.
  const RecordingSessionStarted();
}

/// User requested to end the active recording session.
final class RecordingSessionStopped extends RecordingSessionEvent {
  /// Creates the stop event.
  const RecordingSessionStopped();
}

/// User cancelled the pre-recording countdown before it committed to a
/// session — back to idle, controller stopped, nothing recorded.
final class RecordingSessionCountdownCancelled extends RecordingSessionEvent {
  /// Creates the cancel event.
  const RecordingSessionCountdownCancelled();
}

/// Internal: one second elapsed during `RecordingStatus.preparing`.
final class RecordingSessionCountdownTicked extends RecordingSessionEvent {
  /// Creates the countdown-tick event.
  const RecordingSessionCountdownTicked();
}

/// Discards the finished-session result and returns to the idle state.
final class RecordingSessionReset extends RecordingSessionEvent {
  /// Creates the reset event.
  const RecordingSessionReset();
}

/// Internal: one prediction arrived from the service isolate.
final class RecordingSessionPredictionReceived extends RecordingSessionEvent {
  /// Creates the event carrying the received [prediction].
  const RecordingSessionPredictionReceived(this.prediction);

  /// The prediction decoded from the service-isolate message.
  final ActivityPrediction prediction;

  @override
  List<Object?> get props => [prediction];
}

/// Internal: periodic tick that refreshes the elapsed-time readout and checks
/// the session duration limit.
final class RecordingSessionTicked extends RecordingSessionEvent {
  /// Creates the tick event.
  const RecordingSessionTicked();
}

/// Internal: the session reached `RecordingSessionBloc.maxSessionDuration`
/// and was stopped automatically.
final class RecordingSessionLimitReached extends RecordingSessionEvent {
  /// Creates the limit-reached event.
  const RecordingSessionLimitReached();
}
