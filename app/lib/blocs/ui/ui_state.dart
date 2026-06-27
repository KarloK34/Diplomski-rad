import 'package:equatable/equatable.dart';
import 'package:gait_sense/models/activity_prediction.dart';
import 'package:gait_sense/models/session_log.dart';

/// Lifecycle of a recording session as seen by the UI isolate.
enum RecordingStatus {
  /// No session active; ready to start.
  idle,

  /// A session is running and consuming predictions.
  recording,

  /// The session stopped and is being written to disk.
  saving,

  /// The session was saved; [UiState.finishedSession] holds the result.
  saved,
}

/// State of the UI-isolate recording bloc.
class UiState extends Equatable {
  /// Creates a state with all fields specified.
  const UiState({
    required this.status,
    required this.elapsed,
    required this.predictionCount,
    required this.latencyP50Ms,
    required this.latencyP95Ms,
    this.latest,
    this.finishedSession,
    this.stoppedByLimit = false,
  });

  /// The initial, idle state.
  const UiState.initial()
    : status = RecordingStatus.idle,
      elapsed = Duration.zero,
      predictionCount = 0,
      latencyP50Ms = 0,
      latencyP95Ms = 0,
      latest = null,
      finishedSession = null,
      stoppedByLimit = false;

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

  /// Whether a session is currently recording.
  bool get isRecording => status == RecordingStatus.recording;

  /// Returns a copy with the given fields replaced. Nullable fields cannot be
  /// cleared through this method; the idle state is built with the
  /// [UiState.initial] constructor instead.
  UiState copyWith({
    RecordingStatus? status,
    Duration? elapsed,
    int? predictionCount,
    ActivityPrediction? latest,
    int? latencyP50Ms,
    int? latencyP95Ms,
    SessionLog? finishedSession,
    bool? stoppedByLimit,
  }) {
    return UiState(
      status: status ?? this.status,
      elapsed: elapsed ?? this.elapsed,
      predictionCount: predictionCount ?? this.predictionCount,
      latencyP50Ms: latencyP50Ms ?? this.latencyP50Ms,
      latencyP95Ms: latencyP95Ms ?? this.latencyP95Ms,
      latest: latest ?? this.latest,
      finishedSession: finishedSession ?? this.finishedSession,
      stoppedByLimit: stoppedByLimit ?? this.stoppedByLimit,
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
  ];
}
