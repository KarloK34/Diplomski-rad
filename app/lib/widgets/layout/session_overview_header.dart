import 'package:flutter/material.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/utils/session_summary_format.dart';

/// Session start time, duration, and total prediction count.
class SessionOverviewHeader extends StatelessWidget {
  /// Creates the header for a session that started at [startedAt].
  const SessionOverviewHeader({
    required this.startedAt,
    required this.duration,
    required this.predictionCount,
    super.key,
  });

  /// Wall-clock time the session started.
  final DateTime startedAt;

  /// Total session duration.
  final Duration duration;

  /// Number of predictions recorded during the session.
  final int predictionCount;

  @override
  Widget build(BuildContext context) {
    final textStyles = context.textStyles;
    final spacing = context.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Početak: ${formatStartTimestamp(startedAt)}',
          style: textStyles.bodyMedium,
        ),
        SizedBox(height: spacing.xxs),
        Text(
          'Trajanje: ${formatElapsedClock(duration)}',
          style: textStyles.titleMedium,
        ),
        SizedBox(height: spacing.xxs),
        Text('Broj predikcija: $predictionCount'),
      ],
    );
  }
}
