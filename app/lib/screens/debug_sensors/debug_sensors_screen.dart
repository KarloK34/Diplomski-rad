import 'package:flutter/material.dart';
import 'package:gait_sense/screens/debug_sensors/debug_sensors_content.dart';
import 'package:gait_sense/screens/debug_sensors/debug_sensors_provider.dart';

/// Live readout of the resampled IMU channels, for verifying the sensor
/// pipeline (sampling rate, channel means/variances) during development.
class DebugSensorsScreen extends StatelessWidget {
  /// Creates the debug sensors screen.
  const DebugSensorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DebugSensorsProvider(child: DebugSensorsContent());
  }
}
