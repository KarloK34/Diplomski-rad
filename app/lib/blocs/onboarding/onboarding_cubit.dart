import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/onboarding/onboarding_state.dart';
import 'package:gait_sense/repositories/onboarding_repository.dart';

/// Tracks whether the signed-in account has completed onboarding, for the
/// router's redirect gate to react to.
class OnboardingCubit extends Cubit<OnboardingState> {
  /// Creates the cubit backed by [repository].
  OnboardingCubit({required OnboardingRepository repository})
    : this._(repository);

  OnboardingCubit._(this._repository)
    : super(const OnboardingState.unresolved());

  final OnboardingRepository _repository;

  /// Resolves onboarding status for the now-signed-in account [uid].
  Future<void> resolveFor(String uid) async {
    try {
      final completed = await _repository.isCompleted(uid);
      emit(
        completed
            ? const OnboardingState.completed()
            : const OnboardingState.pending(),
      );
    } on Object catch (_) {
      // Fail open: a transient offline read must not re-show onboarding to a
      // returning user. Accepted trade-off: a brand-new signup that goes
      // offline immediately would also skip it — rare, and self-corrects
      // next successful read since the Firestore doc still says pending.
      emit(const OnboardingState.completed());
    }
  }

  /// Called on sign-out — nothing to gate until the next account resolves.
  void reset() => emit(const OnboardingState.unresolved());

  /// Marks [uid]'s account as having completed onboarding. Emits optimistic
  /// completion immediately; the Firestore write is queued offline by the
  /// SDK if disconnected, same as `SessionRepository.saveSession`.
  Future<void> markCompleted(String uid) async {
    emit(const OnboardingState.completed());
    await _repository.markCompleted(uid);
  }
}
