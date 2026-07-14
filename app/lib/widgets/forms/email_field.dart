import 'package:flutter/material.dart';
import 'package:gait_sense/utils/validators.dart';

/// A themed email input field with inline format validation.
///
/// Controller-less by design: [value]/[onChanged] flow through to whichever
/// cubit owns the form state, so there is no `TextEditingController` to
/// create or dispose here.
class EmailField extends StatelessWidget {
  /// Creates the field bound to [value], calling [onChanged] on every edit.
  const EmailField({
    required this.value,
    required this.onChanged,
    this.textInputAction,
    super.key,
  });

  /// The field's current text.
  final String value;

  /// Called with the new text on every edit.
  final ValueChanged<String> onChanged;

  /// The action button on the keyboard, e.g. "next" or "done".
  /// Defaults to "done" if not provided.
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value,
      onChanged: onChanged,
      keyboardType: TextInputType.emailAddress,
      autocorrect: false,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: const InputDecoration(labelText: 'E-mail adresa'),
      textInputAction: textInputAction ?? TextInputAction.done,
      validator: emailFormatError,
    );
  }
}
