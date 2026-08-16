import 'package:equatable/equatable.dart';

/// Lifecycle of a login/signup form submission.
enum AuthFormStatus {
  /// Not yet submitted.
  initial,

  /// Waiting on the sign-in/sign-up call.
  submitting,

  /// Succeeded — the router redirect takes over from here.
  success,

  /// The call failed; the state's `errorMessage` holds why.
  failure,
}

/// Which action put the form into [AuthFormStatus.submitting] — lets the UI
/// show a spinner on the button that was actually pressed instead of both.
enum AuthSubmitMethod {
  /// The email/password form was submitted.
  email,

  /// The Google sign-in flow was started.
  google,

  /// A password-reset email was requested.
  passwordReset,
}

/// Form state shared by `LoginCubit` and `SignupCubit` — both are a plain
/// email/password form with the same field shape, differing only in which
/// repository call and error messages `submitted()` uses. [firstName]/
/// [lastName] are populated by `SignupCubit` only; `LoginCubit` never sets
/// them and they stay at their default.
class AuthFormState extends Equatable {
  /// Creates a state with the given field values.
  const AuthFormState({
    this.email = '',
    this.password = '',
    this.firstName = '',
    this.lastName = '',
    this.status = AuthFormStatus.initial,
    this.submitMethod,
    this.errorMessage,
  });

  /// Current email field text.
  final String email;

  /// Current password field text.
  final String password;

  /// Current first name field text; signup-only.
  final String firstName;

  /// Current last name field text; signup-only.
  final String lastName;

  /// Where the submission currently stands.
  final AuthFormStatus status;

  /// Which action is in flight while [status] is [AuthFormStatus.submitting].
  final AuthSubmitMethod? submitMethod;

  /// Croatian message to show for [AuthFormStatus.failure], otherwise null.
  final String? errorMessage;

  /// [errorMessage] cannot be cleared through this method — construct a new
  /// [AuthFormState] directly when a fresh (error-free) state is needed.
  AuthFormState copyWith({
    String? email,
    String? password,
    String? firstName,
    String? lastName,
    AuthFormStatus? status,
  }) {
    return AuthFormState(
      email: email ?? this.email,
      password: password ?? this.password,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      status: status ?? this.status,
      submitMethod: submitMethod,
      errorMessage: errorMessage,
    );
  }

  /// Returns an editable-again state carrying over only the given fields —
  /// [status], [submitMethod], and [errorMessage] reset to their defaults, so
  /// editing a field after a failed submission clears the old error.
  AuthFormState editing({
    String? email,
    String? password,
    String? firstName,
    String? lastName,
  }) {
    return AuthFormState(
      email: email ?? this.email,
      password: password ?? this.password,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
    );
  }

  /// Returns a state with the fields preserved and [status] set to
  /// [AuthFormStatus.submitting] for [method].
  AuthFormState toSubmitting(AuthSubmitMethod method) {
    return AuthFormState(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      status: AuthFormStatus.submitting,
      submitMethod: method,
    );
  }

  /// Returns a state with the fields preserved and [status] set to
  /// [AuthFormStatus.failure] with [message].
  AuthFormState toFailure(String message) {
    return AuthFormState(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      status: AuthFormStatus.failure,
      errorMessage: message,
    );
  }

  @override
  List<Object?> get props => [
    email,
    password,
    firstName,
    lastName,
    status,
    submitMethod,
    errorMessage,
  ];
}
