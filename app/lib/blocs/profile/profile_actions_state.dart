import 'package:equatable/equatable.dart';

/// Lifecycle of a `ProfileActionsCubit`-driven action.
enum ProfileActionStatus {
  /// No action in flight.
  idle,

  /// Waiting on the sign-out call.
  signingOut,

  /// Sign-out failed; the state's `message` holds why.
  signOutFailure,

  /// Waiting on the password-reset email call.
  sendingReset,

  /// The password-reset email was sent; `message` holds the confirmation.
  resetSuccess,

  /// Sending the password-reset email failed; `message` holds why.
  resetFailure,
}

/// State for the Profile screen's sign-out and password-reset actions.
class ProfileActionsState extends Equatable {
  /// Creates a profile-actions state.
  const ProfileActionsState({
    this.status = ProfileActionStatus.idle,
    this.message,
  });

  /// Where the current action stands.
  final ProfileActionStatus status;

  /// Croatian snackbar text for [ProfileActionStatus.signOutFailure],
  /// [ProfileActionStatus.resetSuccess] and [ProfileActionStatus.resetFailure];
  /// null otherwise.
  final String? message;

  @override
  List<Object?> get props => [status, message];
}
