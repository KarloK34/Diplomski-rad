import 'package:flutter/material.dart';
import 'package:gait_sense/widgets/buttons/primary_button.dart';

/// Full-width outlined button — the low-emphasis counterpart to
/// [PrimaryButton], typically paired below it.
class SecondaryButton extends StatelessWidget {
  /// Creates the button, calling [onPressed] on tap.
  const SecondaryButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  /// Text shown on the button.
  final String label;

  /// Called when the button is tapped.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(onPressed: onPressed, child: Text(label)),
    );
  }
}
