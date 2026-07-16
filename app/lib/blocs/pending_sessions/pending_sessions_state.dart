import 'package:equatable/equatable.dart';
import 'package:gait_sense/models/session_log.dart';

/// Sessions recovered from `<documents>/sessions/pending/` — recordings that
/// were stopped but never reached an explicit save or discard before the app
/// was killed.
class PendingSessionsState extends Equatable {
  /// Creates a pending-sessions state.
  const PendingSessionsState({this.sessions = const []});

  /// Recovered drafts, unsorted beyond whatever order the filesystem scan
  /// returned.
  final List<SessionLog> sessions;

  @override
  List<Object?> get props => [sessions];
}
