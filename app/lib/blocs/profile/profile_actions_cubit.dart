import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/profile/profile_actions_state.dart';
import 'package:gait_sense/repositories/auth_repository.dart';

/// Owns the Profile screen's sign-out and password-reset side effects.
class ProfileActionsCubit extends Cubit<ProfileActionsState> {
  /// Creates the cubit for [authRepository].
  ProfileActionsCubit({required AuthRepository authRepository})
    : this._(authRepository);

  ProfileActionsCubit._(this._authRepository)
    : super(const ProfileActionsState());

  final AuthRepository _authRepository;

  /// Signs out of the current account.
  ///
  /// No success state is emitted beyond [ProfileActionStatus.idle] — the
  /// router's auth redirect navigates away from Profile once `AuthCubit`
  /// observes the signed-out user.
  Future<void> signOut() async {
    emit(const ProfileActionsState(status: ProfileActionStatus.signingOut));
    try {
      await _authRepository.signOut();
      if (isClosed) return;
      emit(const ProfileActionsState());
    } on Object {
      if (isClosed) return;
      emit(
        const ProfileActionsState(
          status: ProfileActionStatus.signOutFailure,
          message: 'Odjava nije uspjela. Pokušajte ponovo.',
        ),
      );
    }
  }

  /// Sends a password-reset link to [email].
  Future<void> sendPasswordReset(String email) async {
    emit(const ProfileActionsState(status: ProfileActionStatus.sendingReset));
    try {
      await _authRepository.sendPasswordResetEmail(email);
      if (isClosed) return;
      emit(
        ProfileActionsState(
          status: ProfileActionStatus.resetSuccess,
          message: 'E-poruka je poslana na $email.',
        ),
      );
    } on Object {
      if (isClosed) return;
      emit(
        const ProfileActionsState(
          status: ProfileActionStatus.resetFailure,
          message: 'Slanje nije uspjelo. Pokušajte ponovo.',
        ),
      );
    }
  }
}
