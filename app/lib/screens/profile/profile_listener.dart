import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/profile/profile_actions_cubit.dart';
import 'package:gait_sense/blocs/profile/profile_actions_state.dart';
import 'package:gait_sense/extensions/snackbar_context.dart';

/// Shows a snackbar when a sign-out or password-reset action settles.
class ProfileListener extends StatelessWidget {
  /// Wraps [child] with the settle-snackbar side effect.
  const ProfileListener({required this.child, super.key});

  /// The subtree rendering the current state.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProfileActionsCubit, ProfileActionsState>(
      listenWhen: (previous, current) =>
          current.status != previous.status &&
          const [
            ProfileActionStatus.signOutFailure,
            ProfileActionStatus.resetSuccess,
            ProfileActionStatus.resetFailure,
          ].contains(current.status),
      listener: (context, state) {
        final message = state.message;
        if (message != null) {
          context.showSnackBar(message);
        }
      },
      child: child,
    );
  }
}
