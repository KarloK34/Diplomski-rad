import 'package:flutter/material.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/utils/duration_format.dart';

/// Progress bar and remaining-time label tracking [elapsed] against
/// [maxDuration].
class SessionLimitBar extends StatelessWidget {
  /// Creates the bar for a session [elapsed] time out of [maxDuration].
  const SessionLimitBar({
    required this.elapsed,
    required this.maxDuration,
    super.key,
  });

  /// Time elapsed in the current session.
  final Duration elapsed;

  /// Maximum allowed session duration.
  final Duration maxDuration;

  /// Below this much remaining time, the bar switches to the error color.
  static const _nearLimitThreshold = Duration(minutes: 5);

  @override
  Widget build(BuildContext context) {
    final fraction = (elapsed.inMilliseconds / maxDuration.inMilliseconds)
        .clamp(0.0, 1.0);
    final remaining = maxDuration - elapsed;
    final isNearLimit = remaining < _nearLimitThreshold;

    final colors = context.colors;
    final barColor = isNearLimit ? colors.error : colors.primary;
    final labelStyle = context.textStyles.bodySmall?.copyWith(
      color: isNearLimit ? colors.error : colors.onSurfaceVariant,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: LinearProgressIndicator(
            value: fraction,
            color: barColor,
            backgroundColor: colors.surfaceContainerHighest,
            minHeight: 3,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(height: context.spacing.xxs),
        Text('Preostalo: ${formatMmSs(remaining)}', style: labelStyle),
      ],
    );
  }
}
