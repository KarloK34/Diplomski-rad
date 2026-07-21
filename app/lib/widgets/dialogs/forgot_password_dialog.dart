import 'package:flutter/material.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/widgets/forms/email_field.dart';

/// Prompts for the email address to send a password-reset link to.
///
/// Resolves to the trimmed email if submitted, or `null` if dismissed.
Future<String?> showForgotPasswordDialog(
  BuildContext context, {
  required String initialValue,
}) {
  final formKey = GlobalKey<FormState>();
  var email = initialValue;
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Zaboravljena lozinka'),
      content: Form(
        key: formKey,
        child: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Unesite e-mail adresu na koju želite primiti '
                'poveznicu za resetiranje lozinke.',
              ),
              SizedBox(height: context.spacing.sm),
              EmailField(
                value: email,
                onChanged: (value) => setState(() => email = value),
              ),
              SizedBox(height: context.spacing.sm),
              Text(
                'Ako e-mail ne stigne u nekoliko minuta, provjerite i '
                'mapu neželjene pošte (spam).',
                style: context.textStyles.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Odustani'),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState?.validate() ?? false) {
              Navigator.of(dialogContext).pop(email.trim());
            }
          },
          child: const Text('Pošalji'),
        ),
      ],
    ),
  );
}
