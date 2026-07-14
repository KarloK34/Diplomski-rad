import 'package:flutter/material.dart';
import 'package:gait_sense/theme/theme_context.dart';

/// Shown while `RecordingStatus.preparing`: a big countdown number plus a
/// reminder of where to put the phone before the countdown reaches zero.
class RecordingCountdownPanel extends StatelessWidget {
  /// Creates the panel counting down from [secondsRemaining].
  const RecordingCountdownPanel({required this.secondsRemaining, super.key});

  /// Seconds left before the session actually starts.
  final int secondsRemaining;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$secondsRemaining', style: context.textStyles.displayLarge),
          SizedBox(height: spacing.lg),
          Text(
            'Stavite mobitel uspravno u prednji džep',
            textAlign: TextAlign.center,
            style: context.textStyles.titleMedium,
          ),
          SizedBox(height: spacing.xxs),
          Text(
            'Snimanje počinje čim odbrojavanje istekne — vibracija javlja da '
            'je krenulo.',
            textAlign: TextAlign.center,
            style: context.textStyles.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
