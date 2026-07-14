import 'package:equatable/equatable.dart';

/// Where an account stands with respect to onboarding.
enum OnboardingStatus {
  /// Not yet known — no signed-in user, or the Firestore read is in flight.
  unresolved,

  /// Signed in, and the account has not completed onboarding.
  pending,

  /// Signed in, and the account has completed onboarding.
  completed,
}

/// State of `OnboardingCubit`.
class OnboardingState extends Equatable {
  /// The initial state, before anything has been resolved.
  const OnboardingState.unresolved() : status = OnboardingStatus.unresolved;

  /// A signed-in account that has not completed onboarding yet.
  const OnboardingState.pending() : status = OnboardingStatus.pending;

  /// A signed-in account that has completed onboarding.
  const OnboardingState.completed() : status = OnboardingStatus.completed;

  /// Where the account currently stands.
  final OnboardingStatus status;

  @override
  List<Object?> get props => [status];
}
