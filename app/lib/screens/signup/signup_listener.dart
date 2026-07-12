import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/auth/auth_form_state.dart';
import 'package:gait_sense/blocs/auth/signup_cubit.dart';
import 'package:gait_sense/extensions/snackbar_context.dart';

/// Shows a snackbar when registration fails.
class SignupListener extends StatelessWidget {
  /// Wraps [child] with the failure-snackbar side effect.
  const SignupListener({required this.child, super.key});

  /// The subtree rendering the current state.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<SignupCubit, AuthFormState>(
      listenWhen: (previous, current) =>
          current.status == AuthFormStatus.failure &&
          previous.status != AuthFormStatus.failure,
      listener: (context, state) {
        final message = state.errorMessage;
        if (message != null) {
          context.showSnackBar(message);
        }
      },
      child: child,
    );
  }
}
