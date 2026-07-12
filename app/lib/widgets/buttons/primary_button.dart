import 'package:flutter/material.dart';

/// Full-width filled button that shows a spinner instead of [label] while
/// [loading], disabling itself so it can't be tapped twice.
class PrimaryButton extends StatelessWidget {
  /// Creates the button, calling [onPressed] on tap.
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    super.key,
  });

  /// Text shown when not [loading].
  final String label;

  /// Called when the button is tapped.
  final VoidCallback? onPressed;

  /// Whether to show a spinner and disable the button.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}
