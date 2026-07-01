import 'package:flutter/material.dart';

/// Radius tokens registered on [ThemeData.extensions].
@immutable
class GaitSenseRadii extends ThemeExtension<GaitSenseRadii> {
  /// Creates radius tokens.
  const GaitSenseRadii({
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.pill,
  });

  /// Default Gait Sense radius scale.
  static const GaitSenseRadii standard = GaitSenseRadii(
    sm: 4,
    md: 6,
    lg: 8,
    xl: 12,
    pill: 999,
  );

  /// Minimal radius for compact controls.
  final double sm;

  /// Default radius for buttons and inputs.
  final double md;

  /// Maximum card radius used by the app shell.
  final double lg;

  /// Prominent control radius.
  final double xl;

  /// Pill radius for chips and navigation indicators.
  final double pill;

  @override
  GaitSenseRadii copyWith({
    double? sm,
    double? md,
    double? lg,
    double? xl,
    double? pill,
  }) {
    return GaitSenseRadii(
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
      pill: pill ?? this.pill,
    );
  }

  @override
  GaitSenseRadii lerp(ThemeExtension<GaitSenseRadii>? other, double t) {
    if (other is! GaitSenseRadii) return this;
    return GaitSenseRadii(
      sm: _lerp(sm, other.sm, t),
      md: _lerp(md, other.md, t),
      lg: _lerp(lg, other.lg, t),
      xl: _lerp(xl, other.xl, t),
      pill: _lerp(pill, other.pill, t),
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}

/// Static radius aliases for constructors and const expressions.
abstract final class AppRadii {
  /// Complete radius token set.
  static const GaitSenseRadii tokens = GaitSenseRadii.standard;

  /// Minimal radius for compact controls.
  static const double sm = 4;

  /// Default radius for buttons and inputs.
  static const double md = 6;

  /// Maximum card radius used by the app shell.
  static const double lg = 8;

  /// Prominent control radius.
  static const double xl = 12;

  /// Pill radius for chips and navigation indicators.
  static const double pill = 999;
}
