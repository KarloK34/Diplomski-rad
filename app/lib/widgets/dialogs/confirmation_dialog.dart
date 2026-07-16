import 'package:flutter/material.dart';

/// Shows an [AlertDialog] asking the user to confirm a destructive or
/// otherwise consequential action.
///
/// Resolves to `true` only when the user taps the confirm action; dismissing
/// the dialog any other way (back button, tapping outside) resolves to
/// `false`.
Future<bool> showConfirmationDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Odustani',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
