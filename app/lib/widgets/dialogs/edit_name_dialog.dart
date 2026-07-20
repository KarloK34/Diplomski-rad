import 'package:flutter/material.dart';
import 'package:gait_sense/widgets/forms/name_field.dart';

/// Shows a dialog to edit a display name, seeded with [initialValue].
///
/// Resolves to the trimmed new name, or `null` if the dialog was dismissed
/// without saving.
Future<String?> showEditNameDialog(
  BuildContext context, {
  required String initialValue,
}) {
  final formKey = GlobalKey<FormState>();
  var name = initialValue;
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Uredi ime'),
      content: Form(
        key: formKey,
        child: StatefulBuilder(
          builder: (context, setState) => NameField(
            value: name,
            onChanged: (value) => setState(() => name = value),
            labelText: 'Ime i prezime',
            fieldName: 'ime i prezime',
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
              Navigator.of(dialogContext).pop(name.trim());
            }
          },
          child: const Text('Spremi'),
        ),
      ],
    ),
  );
}
