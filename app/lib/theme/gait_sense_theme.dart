import 'package:flutter/material.dart';
import 'package:gait_sense/theme/app_colors.dart';
import 'package:gait_sense/theme/app_radii.dart';
import 'package:gait_sense/theme/app_spacing.dart';
import 'package:gait_sense/theme/app_text_styles.dart';

/// Material theme factory for Gait Sense.
abstract final class GaitSenseTheme {
  /// Light app theme.
  static ThemeData light() {
    return _buildTheme(
      colorScheme: AppColors.lightScheme,
      semanticColors: GaitSenseColors.light,
    );
  }

  /// Dark app theme.
  static ThemeData dark() {
    return _buildTheme(
      colorScheme: AppColors.darkScheme,
      semanticColors: GaitSenseColors.dark,
    );
  }

  static ThemeData _buildTheme({
    required ColorScheme colorScheme,
    required GaitSenseColors semanticColors,
  }) {
    final textTheme = _textTheme(colorScheme);
    final domainTextStyles = GaitSenseTextStyles.fromColorScheme(
      colorScheme,
      semanticColors: semanticColors,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLowest,
        border: _inputBorder(colorScheme.outlineVariant),
        enabledBorder: _inputBorder(colorScheme.outlineVariant),
        focusedBorder: _inputBorder(colorScheme.primary, width: 1.5),
        errorBorder: _inputBorder(colorScheme.error),
        focusedErrorBorder: _inputBorder(colorScheme.error, width: 1.5),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: _filledButtonStyle(colorScheme),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _outlinedButtonStyle(colorScheme),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          minimumSize: const Size(
            AppSpacing.touchTarget,
            AppSpacing.touchTarget,
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        extendedTextStyle: textTheme.labelLarge?.copyWith(
          color: colorScheme.onPrimaryContainer,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: colorScheme.surfaceContainerLowest,
        indicatorColor: colorScheme.primaryContainer.withValues(alpha: 0.18),
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelSmall),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
            size: 22,
          );
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        selectedColor: colorScheme.primaryContainer.withValues(alpha: 0.16),
        disabledColor: colorScheme.surfaceContainerHighest,
        labelStyle: textTheme.labelMedium,
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.primary,
        ),
        side: BorderSide(color: colorScheme.outlineVariant),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.surfaceContainerHighest,
        circularTrackColor: colorScheme.surfaceContainerHighest,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xxs,
        ),
        iconColor: colorScheme.onSurfaceVariant,
        textColor: colorScheme.onSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onInverseSurface,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainerLowest,
        modalBackgroundColor: colorScheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.xl),
          ),
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[
        semanticColors,
        GaitSenseSpacing.standard,
        GaitSenseRadii.standard,
        domainTextStyles,
      ],
    );
  }

  static TextTheme _textTheme(ColorScheme colorScheme) {
    return const TextTheme(
      displayLarge: TextStyle(
        fontSize: 57,
        height: 64 / 57,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        leadingDistribution: TextLeadingDistribution.even,
      ),
      displayMedium: TextStyle(
        fontSize: 45,
        height: 52 / 45,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        leadingDistribution: TextLeadingDistribution.even,
      ),
      displaySmall: TextStyle(
        fontSize: 36,
        height: 44 / 36,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        leadingDistribution: TextLeadingDistribution.even,
      ),
      headlineLarge: TextStyle(
        fontSize: 32,
        height: 40 / 32,
        fontWeight: FontWeight.w600,
        leadingDistribution: TextLeadingDistribution.even,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        height: 36 / 28,
        fontWeight: FontWeight.w500,
        leadingDistribution: TextLeadingDistribution.even,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        height: 32 / 24,
        fontWeight: FontWeight.w500,
        leadingDistribution: TextLeadingDistribution.even,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        height: 28 / 22,
        fontWeight: FontWeight.w500,
        leadingDistribution: TextLeadingDistribution.even,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w600,
        leadingDistribution: TextLeadingDistribution.even,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w500,
        leadingDistribution: TextLeadingDistribution.even,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        leadingDistribution: TextLeadingDistribution.even,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w400,
        leadingDistribution: TextLeadingDistribution.even,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w400,
        leadingDistribution: TextLeadingDistribution.even,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        leadingDistribution: TextLeadingDistribution.even,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        leadingDistribution: TextLeadingDistribution.even,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        height: 16 / 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        leadingDistribution: TextLeadingDistribution.even,
      ),
    ).apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
      decorationColor: colorScheme.onSurface,
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.md),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  static ButtonStyle _filledButtonStyle(ColorScheme colorScheme) {
    return FilledButton.styleFrom(
      minimumSize: const Size(
        AppSpacing.touchTarget,
        AppSpacing.touchTarget,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      textStyle: const TextStyle(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        leadingDistribution: TextLeadingDistribution.even,
      ),
    );
  }

  static ButtonStyle _outlinedButtonStyle(ColorScheme colorScheme) {
    return OutlinedButton.styleFrom(
      foregroundColor: colorScheme.primary,
      minimumSize: const Size(
        AppSpacing.touchTarget,
        AppSpacing.touchTarget,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      side: BorderSide(color: colorScheme.outline),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      textStyle: const TextStyle(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        leadingDistribution: TextLeadingDistribution.even,
      ),
    );
  }
}
