import 'dart:async';

import 'package:gait_sense/blocs/auth/auth_cubit.dart';
import 'package:gait_sense/blocs/auth/auth_state.dart';
import 'package:gait_sense/blocs/onboarding/onboarding_cubit.dart';

/// Bridges [AuthCubit] and [OnboardingCubit] — kept separate from both since
/// a Cubit holding another Cubit is a Bloc-to-Bloc anti-pattern.
class OnboardingGate {
  /// Drives [onboardingCubit] off [authCubit]'s changes.
  OnboardingGate({
    required AuthCubit authCubit,
    required OnboardingCubit onboardingCubit,
  }) : this._(authCubit, onboardingCubit);

  OnboardingGate._(this._authCubit, this._onboardingCubit);

  final AuthCubit _authCubit;
  final OnboardingCubit _onboardingCubit;

  // Assigned in start(), not inline: this field is read only in dispose(),
  // and late final initializers run on first read — an inline initializer
  // would defer listen() until dispose() cancels it immediately.
  late final StreamSubscription<AuthState> _subscription;

  /// Starts listening. Must be called exactly once.
  void start() {
    _subscription = _authCubit.stream.listen(_onAuthChanged);
    // Also replays the already-held state — the stream only carries changes
    // from here on.
    _onAuthChanged(_authCubit.state);
  }

  void _onAuthChanged(AuthState state) {
    final user = state.user;
    if (state.status == AuthStatus.authenticated && user != null) {
      unawaited(_onboardingCubit.resolveFor(user.uid));
    } else {
      _onboardingCubit.reset();
    }
  }

  /// Stops listening. Must be called exactly once.
  void dispose() {
    unawaited(_subscription.cancel());
  }
}
