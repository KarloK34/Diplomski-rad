import 'package:flutter/material.dart';
import 'package:gait_sense/theme/app_colors.dart';
import 'package:gait_sense/theme/app_radii.dart';
import 'package:gait_sense/theme/app_spacing.dart';
import 'package:gait_sense/theme/app_text_styles.dart';

/// Convenience accessors for the active Gait Sense theme.
extension GaitSenseThemeContext on BuildContext {
  /// Active Material theme.
  ThemeData get theme => Theme.of(this);

  /// Active Material color scheme.
  ColorScheme get colors => theme.colorScheme;

  /// Active Material text theme.
  TextTheme get textStyles => theme.textTheme;

  /// Gait Sense semantic colors.
  GaitSenseColors get gaitColors => theme.extension<GaitSenseColors>()!;

  /// Gait Sense domain text styles.
  GaitSenseTextStyles get appTextStyles {
    return theme.extension<GaitSenseTextStyles>()!;
  }

  /// Gait Sense spacing tokens.
  GaitSenseSpacing get spacing => theme.extension<GaitSenseSpacing>()!;

  /// Gait Sense radius tokens.
  GaitSenseRadii get radii => theme.extension<GaitSenseRadii>()!;
}
