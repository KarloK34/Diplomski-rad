import 'package:flutter/material.dart';
import 'package:gait_sense/theme/app_colors.dart';

/// Centralized text styles used across the Gait Sense app.
abstract final class AppTextStyles {
  /// Monospace family used for technical readouts.
  static const String monospaceFontFamily = 'monospace';

  /// Large numerical metric style.
  static const TextStyle dataDisplay = TextStyle(
    fontFamily: monospaceFontFamily,
    fontSize: 28,
    height: 32 / 28,
    fontWeight: FontWeight.w700,
  );

  /// Compact chart label style.
  static const TextStyle chartLabel = TextStyle(
    fontFamily: monospaceFontFamily,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
  );

  /// Monospace style for numerical data cells.
  static const TextStyle monospaceData = TextStyle(
    fontFamily: monospaceFontFamily,
  );

  /// Bold monospace variant for highlighted numerical cells.
  static const TextStyle monospaceDataBold = TextStyle(
    fontFamily: monospaceFontFamily,
    fontWeight: FontWeight.bold,
  );

  /// Bold style for table header cells.
  static const TextStyle tableHeader = TextStyle(fontWeight: FontWeight.bold);

  /// Warning style applied to out-of-range sensor readouts.
  static const TextStyle warning = TextStyle(color: AppColors.warning);
}

/// Domain text styles registered on [ThemeData.extensions].
@immutable
class GaitSenseTextStyles extends ThemeExtension<GaitSenseTextStyles> {
  /// Creates domain text styles.
  const GaitSenseTextStyles({
    required this.dataDisplay,
    required this.chartLabel,
    required this.monospaceData,
    required this.monospaceDataBold,
    required this.tableHeader,
    required this.warning,
  });

  /// Creates domain text styles for the active color and semantic schemes.
  factory GaitSenseTextStyles.fromColorScheme(
    ColorScheme colorScheme, {
    required GaitSenseColors semanticColors,
  }) {
    return GaitSenseTextStyles(
      dataDisplay: AppTextStyles.dataDisplay.copyWith(
        color: colorScheme.primary,
      ),
      chartLabel: AppTextStyles.chartLabel.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
      monospaceData: AppTextStyles.monospaceData.copyWith(
        color: colorScheme.onSurface,
      ),
      monospaceDataBold: AppTextStyles.monospaceDataBold.copyWith(
        color: colorScheme.onSurface,
      ),
      tableHeader: AppTextStyles.tableHeader.copyWith(
        color: colorScheme.onSurface,
      ),
      warning: AppTextStyles.warning.copyWith(color: semanticColors.warning),
    );
  }

  /// Large numerical metric style.
  final TextStyle dataDisplay;

  /// Compact chart label style.
  final TextStyle chartLabel;

  /// Monospace style for numerical data cells.
  final TextStyle monospaceData;

  /// Bold monospace variant for highlighted numerical cells.
  final TextStyle monospaceDataBold;

  /// Bold style for table header cells.
  final TextStyle tableHeader;

  /// Warning style applied to out-of-range sensor readouts.
  final TextStyle warning;

  @override
  GaitSenseTextStyles copyWith({
    TextStyle? dataDisplay,
    TextStyle? chartLabel,
    TextStyle? monospaceData,
    TextStyle? monospaceDataBold,
    TextStyle? tableHeader,
    TextStyle? warning,
  }) {
    return GaitSenseTextStyles(
      dataDisplay: dataDisplay ?? this.dataDisplay,
      chartLabel: chartLabel ?? this.chartLabel,
      monospaceData: monospaceData ?? this.monospaceData,
      monospaceDataBold: monospaceDataBold ?? this.monospaceDataBold,
      tableHeader: tableHeader ?? this.tableHeader,
      warning: warning ?? this.warning,
    );
  }

  @override
  GaitSenseTextStyles lerp(
    ThemeExtension<GaitSenseTextStyles>? other,
    double t,
  ) {
    if (other is! GaitSenseTextStyles) return this;
    return GaitSenseTextStyles(
      dataDisplay: TextStyle.lerp(dataDisplay, other.dataDisplay, t)!,
      chartLabel: TextStyle.lerp(chartLabel, other.chartLabel, t)!,
      monospaceData: TextStyle.lerp(monospaceData, other.monospaceData, t)!,
      monospaceDataBold: TextStyle.lerp(
        monospaceDataBold,
        other.monospaceDataBold,
        t,
      )!,
      tableHeader: TextStyle.lerp(tableHeader, other.tableHeader, t)!,
      warning: TextStyle.lerp(warning, other.warning, t)!,
    );
  }
}
