import 'package:flutter/material.dart';

/// Color tokens and Material color schemes for Gait Sense.
abstract final class AppColors {
  /// Primary brand color from the Stitch handoff.
  static const Color primary = Color(0xFF006565);

  /// High-emphasis primary container.
  static const Color primaryContainer = Color(0xFF008080);

  /// Technical neutral used for secondary UI.
  static const Color graphite = Color(0xFF455A64);

  /// Secondary analytical accent.
  static const Color cyan = Color(0xFF00ACC1);

  /// Warning color for cautionary states.
  static const Color warning = Color(0xFFE6A700);

  /// Error color for destructive states.
  static const Color error = Color(0xFFBA1A1A);

  /// Success color for completed readiness checks.
  static const Color success = Color(0xFF1B7F4A);

  /// Light surface background.
  static const Color lightSurface = Color(0xFFF8F9FA);

  /// Light elevated surface.
  static const Color lightSurfaceContainer = Color(0xFFEDEEEF);

  /// Light highest elevated surface.
  static const Color lightSurfaceContainerHighest = Color(0xFFE1E3E4);

  /// Light foreground color.
  static const Color lightOnSurface = Color(0xFF191C1D);

  /// Light secondary foreground color.
  static const Color lightOnSurfaceVariant = Color(0xFF3E4949);

  /// Dark surface background.
  static const Color darkSurface = Color(0xFF101414);

  /// Dark primary color.
  static const Color darkPrimary = Color(0xFFA3F0EF);

  /// Dark foreground color on primary.
  static const Color darkOnPrimary = Color(0xFF003737);

  /// Dark primary container color.
  static const Color darkPrimaryContainer = Color(0xFF87D4D3);

  /// Dark foreground color on primary container.
  static const Color darkOnPrimaryContainer = Color(0xFF005D5C);

  /// Dark secondary color.
  static const Color darkSecondary = Color(0xFFBEC9C8);

  /// Dark foreground color on secondary.
  static const Color darkOnSecondary = Color(0xFF283232);

  /// Dark secondary container color.
  static const Color darkSecondaryContainer = Color(0xFF3E4948);

  /// Dark foreground color on secondary container.
  static const Color darkOnSecondaryContainer = Color(0xFFACB7B6);

  /// Dark tertiary color.
  static const Color darkTertiary = Color(0xFFF3DAFF);

  /// Dark foreground color on tertiary.
  static const Color darkOnTertiary = Color(0xFF412258);

  /// Dark tertiary container color.
  static const Color darkTertiaryContainer = Color(0xFFE0B8F9);

  /// Dark foreground color on tertiary container.
  static const Color darkOnTertiaryContainer = Color(0xFF66457D);

  /// Dark error color.
  static const Color darkError = Color(0xFFFFB4AB);

  /// Dark foreground color on error.
  static const Color darkOnError = Color(0xFF690005);

  /// Dark error container color.
  static const Color darkErrorContainer = Color(0xFF93000A);

  /// Dark foreground color on error container.
  static const Color darkOnErrorContainer = Color(0xFFFFDAD6);

  /// Dark elevated surface.
  static const Color darkSurfaceContainer = Color(0xFF1C2020);

  /// Dark low elevated surface.
  static const Color darkSurfaceContainerLow = Color(0xFF181C1C);

  /// Dark lowest elevated surface.
  static const Color darkSurfaceContainerLowest = Color(0xFF0B0F0F);

  /// Dark high elevated surface.
  static const Color darkSurfaceContainerHigh = Color(0xFF272B2A);

  /// Dark highest elevated surface.
  static const Color darkSurfaceContainerHighest = Color(0xFF323535);

  /// Dark foreground color.
  static const Color darkOnSurface = Color(0xFFE0E3E2);

  /// Dark secondary foreground color.
  static const Color darkOnSurfaceVariant = Color(0xFFBEC9C8);

  /// Dark outline color.
  static const Color darkOutline = Color(0xFF889392);

  /// Dark boundary color.
  static const Color darkOutlineVariant = Color(0xFF64706F);

  /// Dark chart grid color.
  static const Color darkChartGrid = Color(0xFF64706F);

  /// Dark inverse surface color.
  static const Color darkInverseSurface = Color(0xFFE0E3E2);

  /// Dark foreground color on inverse surface.
  static const Color darkOnInverseSurface = Color(0xFF2D3131);

  /// Dark inverse primary color.
  static const Color darkInversePrimary = Color(0xFF0A6969);

  /// Dark surface tint color.
  static const Color darkSurfaceTint = Color(0xFF87D4D3);

  /// Dark bright surface color.
  static const Color darkSurfaceBright = Color(0xFF363A3A);

  /// Walking activity color.
  static const Color activityWalking = Color(0xFF007A78);

  /// Running activity color.
  static const Color activityRunning = Color(0xFFD04437);

  /// Sitting activity color.
  static const Color activitySitting = Color(0xFF5E6AD2);

  /// Standing activity color.
  static const Color activityStanding = Color(0xFF6E7979);

  /// Upstairs activity color.
  static const Color activityUpstairs = Color(0xFFB7791F);

  /// Downstairs activity color.
  static const Color activityDownstairs = Color(0xFF7B61FF);

  /// Material light color scheme.
  static final ColorScheme lightScheme =
      ColorScheme.fromSeed(
        seedColor: primaryContainer,
      ).copyWith(
        primary: primary,
        onPrimary: Colors.white,
        primaryContainer: primaryContainer,
        onPrimaryContainer: const Color(0xFFE3FFFE),
        secondary: const Color(0xFF4C616C),
        onSecondary: Colors.white,
        secondaryContainer: const Color(0xFFCFE6F2),
        onSecondaryContainer: const Color(0xFF071E27),
        tertiary: const Color(0xFF006370),
        onTertiary: Colors.white,
        tertiaryContainer: const Color(0xFF9EEFFF),
        onTertiaryContainer: const Color(0xFF001F24),
        error: error,
        onError: Colors.white,
        errorContainer: const Color(0xFFFFDAD6),
        onErrorContainer: const Color(0xFF93000A),
        surface: lightSurface,
        onSurface: lightOnSurface,
        onSurfaceVariant: lightOnSurfaceVariant,
        outline: const Color(0xFF6E7979),
        outlineVariant: const Color(0xFFBDC9C8),
        inverseSurface: const Color(0xFF2E3132),
        onInverseSurface: const Color(0xFFF0F1F2),
        inversePrimary: const Color(0xFF76D6D5),
        surfaceTint: const Color(0xFF006A6A),
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: const Color(0xFFF3F4F5),
        surfaceContainer: lightSurfaceContainer,
        surfaceContainerHigh: const Color(0xFFE7E8E9),
        surfaceContainerHighest: lightSurfaceContainerHighest,
        surfaceDim: const Color(0xFFD9DADB),
        surfaceBright: lightSurface,
      );

  /// Material dark color scheme.
  static final ColorScheme darkScheme =
      ColorScheme.fromSeed(
        seedColor: darkPrimary,
        brightness: Brightness.dark,
      ).copyWith(
        primary: darkPrimary,
        onPrimary: darkOnPrimary,
        primaryContainer: darkPrimaryContainer,
        onPrimaryContainer: darkOnPrimaryContainer,
        secondary: darkSecondary,
        onSecondary: darkOnSecondary,
        secondaryContainer: darkSecondaryContainer,
        onSecondaryContainer: darkOnSecondaryContainer,
        tertiary: darkTertiary,
        onTertiary: darkOnTertiary,
        tertiaryContainer: darkTertiaryContainer,
        onTertiaryContainer: darkOnTertiaryContainer,
        error: darkError,
        onError: darkOnError,
        errorContainer: darkErrorContainer,
        onErrorContainer: darkOnErrorContainer,
        surface: darkSurface,
        onSurface: darkOnSurface,
        onSurfaceVariant: darkOnSurfaceVariant,
        outline: darkOutline,
        outlineVariant: darkOutlineVariant,
        inverseSurface: darkInverseSurface,
        onInverseSurface: darkOnInverseSurface,
        inversePrimary: darkInversePrimary,
        surfaceTint: darkSurfaceTint,
        surfaceContainerLowest: darkSurfaceContainerLowest,
        surfaceContainerLow: darkSurfaceContainerLow,
        surfaceContainer: darkSurfaceContainer,
        surfaceContainerHigh: darkSurfaceContainerHigh,
        surfaceContainerHighest: darkSurfaceContainerHighest,
        surfaceDim: darkSurface,
        surfaceBright: darkSurfaceBright,
      );
}

/// Extra semantic colors that do not fit directly into [ColorScheme].
@immutable
class GaitSenseColors extends ThemeExtension<GaitSenseColors> {
  /// Creates semantic colors for domain widgets.
  const GaitSenseColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.activityWalking,
    required this.activityRunning,
    required this.activitySitting,
    required this.activityStanding,
    required this.activityUpstairs,
    required this.activityDownstairs,
    required this.chartComparison,
    required this.chartGrid,
  });

  /// Light semantic color set.
  static const GaitSenseColors light = GaitSenseColors(
    success: AppColors.success,
    onSuccess: Colors.white,
    successContainer: Color(0xFFD8F5E4),
    onSuccessContainer: Color(0xFF06391F),
    warning: AppColors.warning,
    onWarning: Color(0xFF312400),
    warningContainer: Color(0xFFFFF0BF),
    onWarningContainer: Color(0xFF4A3700),
    activityWalking: AppColors.activityWalking,
    activityRunning: AppColors.activityRunning,
    activitySitting: AppColors.activitySitting,
    activityStanding: AppColors.activityStanding,
    activityUpstairs: AppColors.activityUpstairs,
    activityDownstairs: AppColors.activityDownstairs,
    chartComparison: Color(0xFF5B6EE1),
    chartGrid: Color(0xFFCBD5D5),
  );

  /// Dark semantic color set.
  static const GaitSenseColors dark = GaitSenseColors(
    success: Color(0xFF8ED6A9),
    onSuccess: Color(0xFF003919),
    successContainer: Color(0xFF0D5A31),
    onSuccessContainer: Color(0xFFD8F5E4),
    warning: Color(0xFFFFD45C),
    onWarning: Color(0xFF3A2A00),
    warningContainer: Color(0xFF5F4600),
    onWarningContainer: Color(0xFFFFF0BF),
    activityWalking: AppColors.darkPrimary,
    activityRunning: AppColors.darkError,
    activitySitting: AppColors.darkSecondary,
    activityStanding: AppColors.darkOutline,
    activityUpstairs: AppColors.darkTertiary,
    activityDownstairs: AppColors.darkTertiaryContainer,
    chartComparison: AppColors.darkTertiary,
    chartGrid: AppColors.darkChartGrid,
  );

  /// Success state color.
  final Color success;

  /// Foreground on [success].
  final Color onSuccess;

  /// Success container color.
  final Color successContainer;

  /// Foreground on [successContainer].
  final Color onSuccessContainer;

  /// Warning state color.
  final Color warning;

  /// Foreground on [warning].
  final Color onWarning;

  /// Warning container color.
  final Color warningContainer;

  /// Foreground on [warningContainer].
  final Color onWarningContainer;

  /// Walking activity visualization color.
  final Color activityWalking;

  /// Running activity visualization color.
  final Color activityRunning;

  /// Sitting activity visualization color.
  final Color activitySitting;

  /// Standing activity visualization color.
  final Color activityStanding;

  /// Upstairs activity visualization color.
  final Color activityUpstairs;

  /// Downstairs activity visualization color.
  final Color activityDownstairs;

  /// Comparison-series chart color.
  final Color chartComparison;

  /// Chart gridline color.
  final Color chartGrid;

  @override
  GaitSenseColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? activityWalking,
    Color? activityRunning,
    Color? activitySitting,
    Color? activityStanding,
    Color? activityUpstairs,
    Color? activityDownstairs,
    Color? chartComparison,
    Color? chartGrid,
  }) {
    return GaitSenseColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      activityWalking: activityWalking ?? this.activityWalking,
      activityRunning: activityRunning ?? this.activityRunning,
      activitySitting: activitySitting ?? this.activitySitting,
      activityStanding: activityStanding ?? this.activityStanding,
      activityUpstairs: activityUpstairs ?? this.activityUpstairs,
      activityDownstairs: activityDownstairs ?? this.activityDownstairs,
      chartComparison: chartComparison ?? this.chartComparison,
      chartGrid: chartGrid ?? this.chartGrid,
    );
  }

  @override
  GaitSenseColors lerp(ThemeExtension<GaitSenseColors>? other, double t) {
    if (other is! GaitSenseColors) return this;
    return GaitSenseColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      onSuccessContainer: Color.lerp(
        onSuccessContainer,
        other.onSuccessContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      onWarningContainer: Color.lerp(
        onWarningContainer,
        other.onWarningContainer,
        t,
      )!,
      activityWalking: Color.lerp(
        activityWalking,
        other.activityWalking,
        t,
      )!,
      activityRunning: Color.lerp(
        activityRunning,
        other.activityRunning,
        t,
      )!,
      activitySitting: Color.lerp(
        activitySitting,
        other.activitySitting,
        t,
      )!,
      activityStanding: Color.lerp(
        activityStanding,
        other.activityStanding,
        t,
      )!,
      activityUpstairs: Color.lerp(
        activityUpstairs,
        other.activityUpstairs,
        t,
      )!,
      activityDownstairs: Color.lerp(
        activityDownstairs,
        other.activityDownstairs,
        t,
      )!,
      chartComparison: Color.lerp(
        chartComparison,
        other.chartComparison,
        t,
      )!,
      chartGrid: Color.lerp(chartGrid, other.chartGrid, t)!,
    );
  }
}
