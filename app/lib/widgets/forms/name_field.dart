import 'package:flutter/material.dart';
import 'package:gait_sense/utils/validators.dart';

/// A themed name input field with inline non-empty validation.
///
/// Controller-less like the email field — [value]/[onChanged] flow through
/// to whichever cubit owns the form state. Parameterized by [labelText]/
/// [fieldName] so one widget serves both "Ime" and "Prezime".
class NameField extends StatelessWidget {
  /// Creates the field bound to [value], calling [onChanged] on every edit.
  const NameField({
    required this.value,
    required this.onChanged,
    required this.labelText,
    required this.fieldName,
    this.textInputAction,
    super.key,
  });

  /// The field's current text.
  final String value;

  /// Called with the new text on every edit.
  final ValueChanged<String> onChanged;

  /// Field label shown above the input, e.g. `"Ime"`.
  final String labelText;

  /// Lowercase noun used in the validation message, e.g. `"ime"`.
  final String fieldName;

  /// Text input action button on the keyboard, e.g. "next" or "done".
  /// Defaults to "done" if not provided.
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value,
      onChanged: onChanged,
      textCapitalization: TextCapitalization.words,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(labelText: labelText),
      textInputAction: textInputAction ?? TextInputAction.done,
      validator: (value) => requiredNameError(value, fieldName),
    );
  }
}
