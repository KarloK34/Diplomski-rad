import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/auth/auth_form_state.dart';
import 'package:gait_sense/repositories/auth_repository.dart';
import 'package:gait_sense/utils/auth_error_messages.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Owns the login form's field values and submission lifecycle.
///
/// On success, no navigation call is made here — the go_router
/// redirect reacts to `AuthCubit`'s state once Firebase's auth stream fires.
class LoginCubit extends Cubit<AuthFormState> {
  /// Creates the cubit for [authRepository].
  LoginCubit({required AuthRepository authRepository}) : this._(authRepository);

  LoginCubit._(this._authRepository) : super(const AuthFormState());

  final AuthRepository _authRepository;

  /// Updates the email field as the user types
  void emailChanged(String email) {
    emit(AuthFormState(email: email, password: state.password));
  }

  /// Updates the password field as the user types
  void passwordChanged(String password) {
    emit(AuthFormState(email: state.email, password: password));
  }

  /// Submits the current email/password.
  Future<void> submitted() async {
    if (state.status == AuthFormStatus.submitting) return;
    emit(
      AuthFormState(
        email: state.email,
        password: state.password,
        status: AuthFormStatus.submitting,
        submitMethod: AuthSubmitMethod.email,
      ),
    );
    try {
      await _authRepository.signInWithEmail(
        email: state.email,
        password: state.password,
      );
      // The router may have already navigated away and closed this cubit
      // while the await above was pending.
      if (isClosed) return;
      emit(state.copyWith(status: AuthFormStatus.success));
    } on FirebaseAuthException catch (error) {
      if (isClosed) return;
      emit(_failure(loginErrorMessage(error)));
    }
  }

  /// Starts the interactive Google sign-in flow.
  Future<void> googleSignInRequested() async {
    if (state.status == AuthFormStatus.submitting) return;
    emit(
      AuthFormState(
        email: state.email,
        password: state.password,
        status: AuthFormStatus.submitting,
        submitMethod: AuthSubmitMethod.google,
      ),
    );
    try {
      await _authRepository.signInWithGoogle();
      if (isClosed) return;
      emit(state.copyWith(status: AuthFormStatus.success));
    } on GoogleSignInException catch (error) {
      if (isClosed) return;
      if (error.code == GoogleSignInExceptionCode.canceled) {
        emit(AuthFormState(email: state.email, password: state.password));
        return;
      }
      emit(_failure('Prijava putem Google računa nije uspjela.'));
    } on GoogleIdTokenMissingException {
      if (isClosed) return;
      emit(_failure('Prijava putem Google računa nije uspjela.'));
    } on FirebaseAuthException catch (error) {
      if (isClosed) return;
      emit(_failure(loginErrorMessage(error)));
    }
  }

  AuthFormState _failure(String message) {
    return AuthFormState(
      email: state.email,
      password: state.password,
      status: AuthFormStatus.failure,
      errorMessage: message,
    );
  }
}
