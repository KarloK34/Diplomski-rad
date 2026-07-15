import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gait_sense/utils/validators.dart';

/// Themed body-height input in centimetres, with inline range validation.
///
/// Controller-based (unlike the other form fields in this directory) since
/// height can arrive asynchronously after first build — a one-shot
/// `initialValue` can't reflect a value that loads after the widget is
/// already on screen.
class HeightField extends StatelessWidget {
  /// Creates the field bound to [controller]. Set [required] to false to
  /// allow leaving it empty (e.g. a skippable onboarding step).
  const HeightField({
    required this.controller,
    this.required = true,
    super.key,
  });

  /// Backing controller — the caller owns its lifecycle.
  final TextEditingController controller;

  /// Whether an empty value fails validation.
  final bool required;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: const InputDecoration(
        labelText: 'Visina (cm)',
        hintText: 'npr. 175',
        border: OutlineInputBorder(),
        suffixText: 'cm',
      ),
      validator: (value) => heightRangeError(value, required: required),
    );
  }
}
