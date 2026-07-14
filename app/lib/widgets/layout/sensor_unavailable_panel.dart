import 'package:flutter/material.dart';
import 'package:gait_sense/theme/theme_context.dart';

/// Shown when `RecordingStatus.unavailable`: the countdown elapsed without a
/// sensor sample arriving — missing hardware, or (on iOS) a denied Core
/// Motion permission produce the same signature, so this covers both.
class SensorUnavailablePanel extends StatelessWidget {
  /// Creates the panel.
  const SensorUnavailablePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: spacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sensors_off_outlined,
              size: 48,
              color: colors.error,
            ),
            SizedBox(height: spacing.lg),
            Text(
              'Senzori nedostupni',
              textAlign: TextAlign.center,
              style: context.textStyles.titleMedium,
            ),
            SizedBox(height: spacing.xxs),
            Text(
              'Nismo primili podatke sa senzora kretanja. Provjerite je li '
              'aplikaciji dopušteno korištenje senzora kretanja u '
              'postavkama uređaja, pa pokušajte ponovno.',
              textAlign: TextAlign.center,
              style: context.textStyles.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
