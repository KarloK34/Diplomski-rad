import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/auth/auth_form_state.dart';
import 'package:gait_sense/blocs/auth/login_cubit.dart';
import 'package:gait_sense/extensions/snackbar_context.dart';

/// Shows a snackbar when sign-in fails, or when a password-reset email is
/// sent (successfully or not).
class LoginListener extends StatelessWidget {
  /// Wraps [child] with the failure/password-reset snackbar side effects.
  const LoginListener({required this.child, super.key});

  /// The subtree rendering the current state.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<LoginCubit, AuthFormState>(
      listenWhen: (previous, current) =>
          (current.status == AuthFormStatus.failure &&
              previous.status != AuthFormStatus.failure) ||
          (current.status == AuthFormStatus.success &&
              current.submitMethod == AuthSubmitMethod.passwordReset &&
              previous.status != AuthFormStatus.success),
      listener: (context, state) {
        if (state.status == AuthFormStatus.success) {
          context.showSnackBar(
            'Ako račun s ovom e-mail adresom postoji, poveznica '
            'za resetiranje lozinke će biti poslana.',
          );
          return;
        }
        final message = state.errorMessage;
        if (message != null) {
          context.showSnackBar(message);
        }
      },
      child: child,
    );
  }
}
