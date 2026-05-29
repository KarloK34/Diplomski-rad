import 'package:flutter/material.dart';

/// Centralized text styles used across the Gait Sense app.
abstract final class AppTextStyles {
  /// Monospace style for numerical data cells.
  static const TextStyle monospaceData = TextStyle(fontFamily: 'monospace');

  /// Bold monospace variant for highlighted numerical cells.
  static const TextStyle monospaceDataBold = TextStyle(
    fontFamily: 'monospace',
    fontWeight: FontWeight.bold,
  );

  /// Bold style for table header cells.
  static const TextStyle tableHeader = TextStyle(fontWeight: FontWeight.bold);

  /// Warning style applied to out-of-range sensor readouts.
  static const TextStyle warning = TextStyle(color: Colors.orange);
}
