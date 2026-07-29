import 'package:flutter/material.dart';
import 'package:gait_sense/theme/theme_context.dart';

/// Shown while `RecordingStatus.idle`: no session has run yet, so there are
/// no readouts worth displaying — just a nudge toward the Start control.
class RecordingStartPanel extends StatelessWidget {
  /// Creates the panel.
  const RecordingStartPanel({super.key});

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
              Icons.play_circle_outline,
              size: 48,
              color: colors.primary,
            ),
            SizedBox(height: spacing.lg),
            Text(
              'Spremni za snimanje',
              textAlign: TextAlign.center,
              style: context.textStyles.titleMedium,
            ),
            SizedBox(height: spacing.xxs),
            Text(
              'Pritisnite gumb Start kad želite započeti snimanje hoda.',
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
