import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/sessions/sessions_state.dart';
import 'package:gait_sense/models/session_summary_record.dart';
import 'package:gait_sense/repositories/session_repository.dart';
import 'package:gait_sense/utils/session_aggregates.dart';

/// Holds the signed-in account's saved sessions, fed by a single live
/// Firestore listener shared across the Home and Sessions tabs.
///
/// Binding is driven externally by `SessionsGate` off auth changes.
class SessionsCubit extends Cubit<SessionsState> {
  /// Creates the cubit against [repository]; call [bind] once authenticated.
  SessionsCubit({required SessionRepository repository}) : this._(repository);

  SessionsCubit._(this._repository) : super(const SessionsState.initial());

  final SessionRepository _repository;
  StreamSubscription<List<SessionSummaryRecord>>? _subscription;

  /// (Re)subscribes to the current account's sessions.
  void bind() {
    unawaited(_subscription?.cancel());
    emit(state.copyWith(status: SessionsStatus.loading));
    _subscription = _repository.watchSessions().listen(
      (sessions) => emit(
        SessionsState(
          status: SessionsStatus.ready,
          sessions: sessions,
          aggregates: sessionHistoryAggregates(sessions),
        ),
      ),
      onError: (Object error) =>
          emit(state.copyWith(status: SessionsStatus.error, error: error)),
    );
  }

  /// Drops the subscription and clears state on sign-out.
  void clear() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    emit(const SessionsState.initial());
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
