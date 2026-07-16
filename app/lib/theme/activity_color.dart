import 'package:flutter/material.dart';
import 'package:gait_sense/theme/app_colors.dart';

/// Maps MotionSense activity class codes to their themed chart colors, so every
/// chart and legend colors an activity identically in light and dark.
///
/// Codes follow the MotionSense taxonomy (Malekzadeh et al., IoTDI 2019,
/// https://doi.org/10.1145/3302505.3310068).
extension ActivityColor on GaitSenseColors {
  /// Themed color for activity [code]; a neutral color for unknown codes.
  Color forActivity(String code) => switch (code) {
    'wlk' => activityWalking,
    'jog' => activityRunning,
    'sit' => activitySitting,
    'std' => activityStanding,
    'ups' => activityUpstairs,
    'dws' => activityDownstairs,
    _ => activityStanding,
  };
}
