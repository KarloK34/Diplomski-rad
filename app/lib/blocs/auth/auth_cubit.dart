import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/auth/auth_state.dart';
import 'package:gait_sense/repositories/auth_repository.dart';

/// Mirrors `AuthRepository.authStateChanges` into an [AuthState] for the whole
/// app to react to — chiefly the router's redirect gate.
class AuthCubit extends Cubit<AuthState> {
  /// Subscribes to [authRepository]'s auth-state stream immediately.
  AuthCubit({required AuthRepository authRepository}) : this._(authRepository);

  AuthCubit._(this._authRepository) : super(const AuthState.unknown()) {
    _subscription = _authRepository.authStateChanges.listen((user) {
      emit(
        user == null
            ? const AuthState.unauthenticated()
            : AuthState.authenticated(user),
      );
    });
  }

  final AuthRepository _authRepository;
  late final StreamSubscription<User?> _subscription;

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
