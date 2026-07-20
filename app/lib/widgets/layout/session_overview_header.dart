import 'package:flutter/material.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/utils/session_metric_info.dart';
import 'package:gait_sense/utils/session_summary_format.dart';
import 'package:gait_sense/widgets/buttons/metric_info_button.dart';

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
        Row(
          children: [
            Text(
              'Početak: ${formatStartTimestamp(startedAt)}',
              style: textStyles.bodyMedium,
            ),
            const MetricInfoButton(info: sessionStartMetricInfo),
          ],
        ),
        SizedBox(height: spacing.xxs),
        Row(
          children: [
            Text(
              'Trajanje: ${formatElapsedClock(duration)}',
              style: textStyles.titleMedium,
            ),
            const MetricInfoButton(info: sessionDurationMetricInfo),
          ],
        ),
        SizedBox(height: spacing.xxs),
        Row(
          children: [
            Text('Broj predikcija: $predictionCount'),
            const MetricInfoButton(info: predictionCountMetricInfo),
          ],
        ),
      ],
    );
  }
}
