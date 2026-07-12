import 'package:flutter/material.dart';
import 'package:gait_sense/utils/validators.dart';

/// A themed password input field with an obscure/visible toggle.
///
/// Controller-less like the email field — only the obscure/visible toggle is
/// kept as local state, since it's ephemeral UI state that doesn't need to
/// survive navigation, justifying a [StatefulWidget] here.
class PasswordField extends StatefulWidget {
  /// Creates the field bound to [value], calling [onChanged] on every edit.
  const PasswordField({
    required this.value,
    required this.onChanged,
    this.labelText = 'Lozinka',
    super.key,
  });

  /// The field's current text.
  final String value;

  /// Called with the new text on every edit.
  final ValueChanged<String> onChanged;

  /// Field label, overridable for a "confirm password" variant.
  final String labelText;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: widget.value,
      onChanged: widget.onChanged,
      obscureText: _obscureText,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: widget.labelText,
        suffixIcon: IconButton(
          icon: Icon(
            _obscureText
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          onPressed: () => setState(() => _obscureText = !_obscureText),
        ),
      ),
      validator: passwordFormatError,
    );
  }
}
