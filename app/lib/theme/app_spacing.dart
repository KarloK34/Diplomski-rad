import 'package:flutter/material.dart';

/// Spacing tokens registered on [ThemeData.extensions].
@immutable
class GaitSenseSpacing extends ThemeExtension<GaitSenseSpacing> {
  /// Creates spacing tokens.
  const GaitSenseSpacing({
    required this.xxs,
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.screenMargin,
    required this.touchTarget,
    required this.prominentActionHeight,
  });

  /// Default Gait Sense spacing scale.
  static const GaitSenseSpacing standard = GaitSenseSpacing(
    xxs: 4,
    xs: 8,
    sm: 12,
    md: 16,
    lg: 24,
    xl: 32,
    screenMargin: 16,
    touchTarget: 48,
    prominentActionHeight: 56,
  );

  /// Smallest inner gap.
  final double xxs;

  /// Base grid unit.
  final double xs;

  /// Compact content gap.
  final double sm;

  /// Default section gap.
  final double md;

  /// Large section gap.
  final double lg;

  /// Screen-level vertical gap.
  final double xl;

  /// Default horizontal screen margin.
  final double screenMargin;

  /// Minimum comfortable tap target.
  final double touchTarget;

  /// Primary recording action height.
  final double prominentActionHeight;

  @override
  GaitSenseSpacing copyWith({
    double? xxs,
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
    double? screenMargin,
    double? touchTarget,
    double? prominentActionHeight,
  }) {
    return GaitSenseSpacing(
      xxs: xxs ?? this.xxs,
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
      screenMargin: screenMargin ?? this.screenMargin,
      touchTarget: touchTarget ?? this.touchTarget,
      prominentActionHeight:
          prominentActionHeight ?? this.prominentActionHeight,
    );
  }

  @override
  GaitSenseSpacing lerp(ThemeExtension<GaitSenseSpacing>? other, double t) {
    if (other is! GaitSenseSpacing) return this;
    return GaitSenseSpacing(
      xxs: _lerp(xxs, other.xxs, t),
      xs: _lerp(xs, other.xs, t),
      sm: _lerp(sm, other.sm, t),
      md: _lerp(md, other.md, t),
      lg: _lerp(lg, other.lg, t),
      xl: _lerp(xl, other.xl, t),
      screenMargin: _lerp(screenMargin, other.screenMargin, t),
      touchTarget: _lerp(touchTarget, other.touchTarget, t),
      prominentActionHeight: _lerp(
        prominentActionHeight,
        other.prominentActionHeight,
        t,
      ),
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}

/// Static spacing aliases for constructors and const expressions.
abstract final class AppSpacing {
  /// Complete spacing token set.
  static const GaitSenseSpacing tokens = GaitSenseSpacing.standard;

  /// Smallest inner gap.
  static const double xxs = 4;

  /// Base grid unit.
  static const double xs = 8;

  /// Compact content gap.
  static const double sm = 12;

  /// Default section gap.
  static const double md = 16;

  /// Large section gap.
  static const double lg = 24;

  /// Screen-level vertical gap.
  static const double xl = 32;

  /// Default horizontal screen margin.
  static const double screenMargin = 16;

  /// Minimum comfortable tap target.
  static const double touchTarget = 48;

  /// Primary recording action height.
  static const double prominentActionHeight = 56;
}
