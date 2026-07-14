import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/auth/auth_form_state.dart';
import 'package:gait_sense/repositories/auth_repository.dart';
import 'package:gait_sense/utils/auth_error_messages.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Owns the signup form's field values and submission lifecycle.
///
/// Route-scoped like `LoginCubit`, and follows the same fire-and-let-the-
/// router-redirect-react pattern on success.
class SignupCubit extends Cubit<AuthFormState> {
  /// Creates the cubit for [authRepository].
  SignupCubit({required AuthRepository authRepository})
    : this._(authRepository);

  SignupCubit._(this._authRepository) : super(const AuthFormState());

  final AuthRepository _authRepository;

  /// Updates the email field as the user types
  void emailChanged(String email) {
    emit(
      AuthFormState(
        email: email,
        password: state.password,
        firstName: state.firstName,
        lastName: state.lastName,
      ),
    );
  }

  /// Updates the password field as the user types
  void passwordChanged(String password) {
    emit(
      AuthFormState(
        email: state.email,
        password: password,
        firstName: state.firstName,
        lastName: state.lastName,
      ),
    );
  }

  /// Updates the first name field as the user types
  void firstNameChanged(String firstName) {
    emit(
      AuthFormState(
        email: state.email,
        password: state.password,
        firstName: firstName,
        lastName: state.lastName,
      ),
    );
  }

  /// Updates the last name field as the user types
  void lastNameChanged(String lastName) {
    emit(
      AuthFormState(
        email: state.email,
        password: state.password,
        firstName: state.firstName,
        lastName: lastName,
      ),
    );
  }

  /// Submits the current email/password/name to create a new account.
  Future<void> submitted() async {
    if (state.status == AuthFormStatus.submitting) return;
    emit(
      AuthFormState(
        email: state.email,
        password: state.password,
        firstName: state.firstName,
        lastName: state.lastName,
        status: AuthFormStatus.submitting,
        submitMethod: AuthSubmitMethod.email,
      ),
    );
    try {
      await _authRepository.signUpWithEmail(
        email: state.email,
        password: state.password,
        firstName: state.firstName,
        lastName: state.lastName,
      );
      // The router may have already navigated away and closed this cubit
      // while the await above was pending.
      if (isClosed) return;
      emit(state.copyWith(status: AuthFormStatus.success));
    } on FirebaseAuthException catch (error) {
      if (isClosed) return;
      emit(_failure(signupErrorMessage(error)));
    }
  }

  /// Starts the interactive Google sign-in flow — also serves as "register"
  /// for a first-time Google user, since Firebase creates the account
  /// automatically on first sign-in.
  Future<void> googleSignInRequested() async {
    if (state.status == AuthFormStatus.submitting) return;
    emit(
      AuthFormState(
        email: state.email,
        password: state.password,
        firstName: state.firstName,
        lastName: state.lastName,
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
        emit(
          AuthFormState(
            email: state.email,
            password: state.password,
            firstName: state.firstName,
            lastName: state.lastName,
          ),
        );
        return;
      }
      emit(_failure('Registracija putem Google računa nije uspjela.'));
    } on GoogleIdTokenMissingException {
      if (isClosed) return;
      emit(_failure('Registracija putem Google računa nije uspjela.'));
    } on FirebaseAuthException catch (error) {
      if (isClosed) return;
      emit(_failure(signupErrorMessage(error)));
    }
  }

  AuthFormState _failure(String message) {
    return AuthFormState(
      email: state.email,
      password: state.password,
      firstName: state.firstName,
      lastName: state.lastName,
      status: AuthFormStatus.failure,
      errorMessage: message,
    );
  }
}
