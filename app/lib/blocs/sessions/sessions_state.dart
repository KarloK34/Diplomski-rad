import 'package:equatable/equatable.dart';
import 'package:gait_sense/models/session_summary_record.dart';
import 'package:gait_sense/utils/session_aggregates.dart';

/// Whether the account's sessions are still loading, loaded, or failed.
enum SessionsStatus {
  /// No account is bound yet (signed out or before the first load).
  initial,

  /// Subscribed and awaiting the first snapshot.
  loading,

  /// At least one snapshot has arrived.
  ready,

  /// The stream reported an error.
  error,
}

/// State for the signed-in account's saved sessions, newest first.
class SessionsState extends Equatable {
  /// Creates a sessions state.
  const SessionsState({
    required this.status,
    this.sessions = const [],
    this.aggregates = emptySessionHistoryAggregates,
    this.error,
  });

  /// The signed-out / not-yet-loaded state.
  const SessionsState.initial() : this(status: SessionsStatus.initial);

  /// Where loading currently stands.
  final SessionsStatus status;

  /// Saved sessions, ordered newest first.
  final List<SessionSummaryRecord> sessions;

  /// Cross-session dashboard aggregates, computed once by the cubit when
  /// [sessions] last changed rather than on every rebuild that reads it.
  final SessionHistoryAggregates aggregates;

  /// The stream error when [status] is [SessionsStatus.error].
  final Object? error;

  /// The most recently recorded session, or null when there are none.
  SessionSummaryRecord? get latest =>
      sessions.isEmpty ? null : sessions.first;

  /// Copies with selected fields replaced.
  SessionsState copyWith({
    SessionsStatus? status,
    List<SessionSummaryRecord>? sessions,
    SessionHistoryAggregates? aggregates,
    Object? error,
  }) {
    return SessionsState(
      status: status ?? this.status,
      sessions: sessions ?? this.sessions,
      aggregates: aggregates ?? this.aggregates,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [status, sessions, aggregates, error];
}
