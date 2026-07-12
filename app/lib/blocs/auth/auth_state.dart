import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Whether the signed-in status is still being determined, or resolved.
enum AuthStatus {
  /// Firebase's first `authStateChanges` event has not arrived yet.
  unknown,

  /// A user is signed in.
  authenticated,

  /// No user is signed in.
  unauthenticated,
}

/// Current sign-in status, mirrored from `AuthRepository.authStateChanges`.
class AuthState extends Equatable {
  /// Creates a state with the given [status] and [user].
  const AuthState({required this.status, this.user});

  /// The initial state, before the first auth event has arrived.
  const AuthState.unknown() : status = AuthStatus.unknown, user = null;

  /// A signed-in state for [user].
  const AuthState.authenticated(this.user) : status = AuthStatus.authenticated;

  /// The signed-out state.
  const AuthState.unauthenticated()
    : status = AuthStatus.unauthenticated,
      user = null;

  /// Where sign-in status currently stands.
  final AuthStatus status;

  /// The signed-in user, non-null exactly when [status] is
  /// [AuthStatus.authenticated].
  final User? user;

  @override
  List<Object?> get props => [status, user];
}
