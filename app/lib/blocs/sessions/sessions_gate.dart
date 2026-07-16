import 'dart:async';

import 'package:gait_sense/blocs/auth/auth_cubit.dart';
import 'package:gait_sense/blocs/auth/auth_state.dart';
import 'package:gait_sense/blocs/sessions/sessions_cubit.dart';

/// Binds [SessionsCubit] to the signed-in account off [AuthCubit]'s changes.
class SessionsGate {
  /// Drives [sessionsCubit] off [authCubit]'s changes.
  SessionsGate({
    required AuthCubit authCubit,
    required SessionsCubit sessionsCubit,
  }) : this._(authCubit, sessionsCubit);

  SessionsGate._(this._authCubit, this._sessionsCubit);

  final AuthCubit _authCubit;
  final SessionsCubit _sessionsCubit;

  // Assigned in start(), not inline.
  late final StreamSubscription<AuthState> _subscription;

  /// Starts listening. Must be called exactly once.
  void start() {
    _subscription = _authCubit.stream.listen(_onAuthChanged);
    _onAuthChanged(_authCubit.state);
  }

  void _onAuthChanged(AuthState state) {
    if (state.status == AuthStatus.authenticated && state.user != null) {
      _sessionsCubit.bind();
    } else if (state.status == AuthStatus.unauthenticated) {
      _sessionsCubit.clear();
    }
  }

  /// Stops listening. Must be called exactly once.
  void dispose() {
    unawaited(_subscription.cancel());
  }
}
