import 'package:equatable/equatable.dart';
import 'package:gait_sense/models/activity_prediction.dart';
import 'package:gait_sense/models/session_log.dart';

/// Lifecycle of a recording session as seen by the UI isolate.
enum RecordingStatus {
  /// No session active; ready to start.
  idle,

  /// Start was pressed: the countdown is running and the sensor-readiness
  /// probe is waiting for a first sample. No session bookkeeping yet.
  preparing,

  /// A session is running and consuming predictions.
  recording,

  /// The session stopped and is being written to disk.
  saving,

  /// The session was saved; [RecordingSessionState.finishedSession] holds
  /// the result.
  saved,

  /// The countdown elapsed without a sensor sample arriving (missing
  /// hardware, or a denied motion-sensor permission) — no session started.
  unavailable,
}

/// State of the recording-session bloc.
class RecordingSessionState extends Equatable {
  /// Creates a state with all fields specified.
  const RecordingSessionState({
    required this.status,
    required this.elapsed,
    required this.predictionCount,
    required this.latencyP50Ms,
    required this.latencyP95Ms,
    this.latest,
    this.finishedSession,
    this.stoppedByLimit = false,
    this.countdownSecondsRemaining = 0,
  });

  /// The initial, idle state.
  const RecordingSessionState.initial()
    : status = RecordingStatus.idle,
      elapsed = Duration.zero,
      predictionCount = 0,
      latencyP50Ms = 0,
      latencyP95Ms = 0,
      latest = null,
      finishedSession = null,
      stoppedByLimit = false,
      countdownSecondsRemaining = 0;

  /// Where the session is in its lifecycle.
  final RecordingStatus status;

  /// Wall-clock time elapsed since the session started.
  final Duration elapsed;

  /// Number of predictions received in the active (or just-finished) session.
  final int predictionCount;

  /// The most recent prediction, or null before the first arrives.
  final ActivityPrediction? latest;

  /// Median inference latency over the rolling window, in milliseconds.
  final int latencyP50Ms;

  /// 95th-percentile inference latency over the rolling window, in ms.
  final int latencyP95Ms;

  /// The saved session, non-null exactly when [status] is
  /// [RecordingStatus.saved]; drives navigation to the summary screen.
  final SessionLog? finishedSession;

  /// Whether the session was stopped automatically because it reached the
  /// maximum allowed duration. False for user-initiated stops.
  final bool stoppedByLimit;

  /// Seconds left in the pre-recording countdown while [status] is
  /// [RecordingStatus.preparing]; meaningless otherwise.
  final int countdownSecondsRemaining;

  /// Whether a session is currently recording.
  bool get isRecording => status == RecordingStatus.recording;

  /// Whether a session is in progress somewhere between start and being
  /// saved. Preparing counts as active too: leaving mid-countdown would
  /// leave the controller armed with no visible way back to cancel it.
  bool get isSessionActive =>
      status == RecordingStatus.preparing ||
      status == RecordingStatus.recording ||
      status == RecordingStatus.saving;

  /// Returns a copy with the given fields replaced. Nullable fields cannot be
  /// cleared through this method; the idle state is built with the
  /// [RecordingSessionState.initial] constructor instead.
  RecordingSessionState copyWith({
    RecordingStatus? status,
    Duration? elapsed,
    int? predictionCount,
    ActivityPrediction? latest,
    int? latencyP50Ms,
    int? latencyP95Ms,
    SessionLog? finishedSession,
    bool? stoppedByLimit,
    int? countdownSecondsRemaining,
  }) {
    return RecordingSessionState(
      status: status ?? this.status,
      elapsed: elapsed ?? this.elapsed,
      predictionCount: predictionCount ?? this.predictionCount,
      latencyP50Ms: latencyP50Ms ?? this.latencyP50Ms,
      latencyP95Ms: latencyP95Ms ?? this.latencyP95Ms,
      latest: latest ?? this.latest,
      finishedSession: finishedSession ?? this.finishedSession,
      stoppedByLimit: stoppedByLimit ?? this.stoppedByLimit,
      countdownSecondsRemaining:
          countdownSecondsRemaining ?? this.countdownSecondsRemaining,
    );
  }

  @override
  List<Object?> get props => [
    status,
    elapsed,
    predictionCount,
    latest,
    latencyP50Ms,
    latencyP95Ms,
    finishedSession,
    stoppedByLimit,
    countdownSecondsRemaining,
  ];
}
