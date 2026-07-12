import 'package:flutter/material.dart';

/// Snackbar helper, replacing the repeated
/// `ScaffoldMessenger.of(context).showSnackBar(...)` boilerplate.
extension SnackBarContext on BuildContext {
  /// Shows [message] in a snackbar anchored to the nearest [Scaffold].
  void showSnackBar(String message, {Duration? duration}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration ?? const Duration(seconds: 4),
      ),
    );
  }
}
