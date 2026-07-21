import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/auth/auth_form_state.dart';
import 'package:gait_sense/blocs/auth/login_cubit.dart';
import 'package:gait_sense/widgets/dialogs/forgot_password_dialog.dart';

/// "Zaboravili ste lozinku?" link on the login screen.
///
/// Reads [LoginCubit] directly: opens [showForgotPasswordDialog] to collect
/// an email, then hands it to [LoginCubit.sendPasswordResetEmail]. Disables
/// itself while another submission on the same cubit is in flight.
class ForgotPasswordButton extends StatelessWidget {
  /// Creates the button.
  const ForgotPasswordButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LoginCubit, AuthFormState>(
      builder: (context, state) {
        final submitting = state.status == AuthFormStatus.submitting;
        return Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: submitting
                ? null
                : () => unawaited(_requestReset(context, state.email)),
            child: const Text('Zaboravili ste lozinku?'),
          ),
        );
      },
    );
  }

  Future<void> _requestReset(BuildContext context, String initialEmail) async {
    final email = await showForgotPasswordDialog(
      context,
      initialValue: initialEmail,
    );
    if (email == null || !context.mounted) return;
    await context.read<LoginCubit>().sendPasswordResetEmail(email);
  }
}
