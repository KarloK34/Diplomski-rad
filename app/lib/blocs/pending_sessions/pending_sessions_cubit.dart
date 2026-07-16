import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/pending_sessions/pending_sessions_state.dart';
import 'package:gait_sense/repositories/session_log_repository.dart';

/// Holds recording sessions recovered from disk that outlived an app kill
/// before the user saved or discarded them.
///
/// Local-only and account-independent (pending drafts live in the app's
/// documents directory, not Firestore) so, unlike `SessionsCubit`, this needs
/// no auth-driven gate — [refresh] runs once at startup and again whenever
/// the user resolves a recovered session.
class PendingSessionsCubit extends Cubit<PendingSessionsState> {
  /// Creates the cubit against [repository]; call [refresh] to populate it.
  PendingSessionsCubit({required SessionLogRepository repository})
    : this._(repository);

  PendingSessionsCubit._(this._repository)
    : super(const PendingSessionsState());

  final SessionLogRepository _repository;

  /// Re-scans `sessions/pending/` and replaces the current list.
  Future<void> refresh() async {
    final sessions = await _repository.listPendingDrafts();
    emit(PendingSessionsState(sessions: sessions));
  }
}
