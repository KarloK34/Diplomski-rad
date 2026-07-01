import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gait_sense/theme/app_colors.dart';
import 'package:gait_sense/theme/app_radii.dart';
import 'package:gait_sense/theme/app_spacing.dart';
import 'package:gait_sense/theme/app_text_styles.dart';
import 'package:gait_sense/theme/gait_sense_theme.dart';
import 'package:gait_sense/theme/theme_context.dart';

void main() {
  test('light theme exposes core design tokens', () {
    final theme = GaitSenseTheme.light();
    final semanticColors = theme.extension<GaitSenseColors>();

    expect(theme.useMaterial3, isTrue);
    expect(theme.colorScheme.primary, AppColors.primary);
    expect(theme.colorScheme.surface, AppColors.lightSurface);
    expect(semanticColors?.warning, AppColors.warning);
    expect(semanticColors?.activityWalking, AppColors.activityWalking);
  });

  test('dark theme exposes semantic colors', () {
    final theme = GaitSenseTheme.dark();
    final semanticColors = theme.extension<GaitSenseColors>()!;
    final textStyles = theme.extension<GaitSenseTextStyles>();

    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.surface, AppColors.darkSurface);
    expect(theme.colorScheme.primary, AppColors.darkPrimary);
    expect(theme.colorScheme.primaryContainer, AppColors.darkPrimaryContainer);
    expect(theme.colorScheme.outlineVariant, AppColors.darkOutlineVariant);
    expect(
      theme.floatingActionButtonTheme.backgroundColor,
      theme.colorScheme.primaryContainer,
    );
    expect(
      theme.floatingActionButtonTheme.foregroundColor,
      theme.colorScheme.onPrimaryContainer,
    );
    expect(semanticColors.chartGrid, AppColors.darkChartGrid);
    expect(
      _contrastRatio(
        theme.colorScheme.outlineVariant,
        theme.colorScheme.surface,
      ),
      greaterThanOrEqualTo(3),
    );
    expect(
      _contrastRatio(semanticColors.chartGrid, theme.colorScheme.surface),
      greaterThanOrEqualTo(3),
    );
    expect(textStyles?.warning.color, semanticColors.warning);
  });

  test('theme tokens preserve implementation constraints', () {
    final theme = GaitSenseTheme.light();

    expect(AppSpacing.touchTarget, greaterThanOrEqualTo(48));
    expect(AppRadii.lg, lessThanOrEqualTo(8));
    expect(theme.textTheme.displayLarge?.letterSpacing, 0);
    expect(theme.textTheme.labelLarge?.letterSpacing, 0);
  });

  testWidgets('context exposes theme tokens', (tester) async {
    late ColorScheme colors;
    late TextTheme textStyles;
    late GaitSenseColors gaitColors;
    late GaitSenseSpacing spacing;
    late GaitSenseRadii radii;
    late TextStyle dataDisplay;

    await tester.pumpWidget(
      MaterialApp(
        theme: GaitSenseTheme.light(),
        home: Builder(
          builder: (context) {
            colors = context.colors;
            textStyles = context.textStyles;
            gaitColors = context.gaitColors;
            spacing = context.spacing;
            radii = context.radii;
            dataDisplay = context.appTextStyles.dataDisplay;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(colors.primary, AppColors.primary);
    expect(textStyles.bodyMedium, isNotNull);
    expect(gaitColors.warning, AppColors.warning);
    expect(spacing.md, AppSpacing.md);
    expect(radii.lg, AppRadii.lg);
    expect(dataDisplay.fontFamily, AppTextStyles.monospaceFontFamily);
  });
}

double _contrastRatio(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
