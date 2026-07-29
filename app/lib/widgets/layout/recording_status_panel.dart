import 'package:flutter/material.dart';
import 'package:gait_sense/blocs/recording_session/recording_session_state.dart';
import 'package:gait_sense/models/activity_prediction.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/utils/duration_format.dart';
import 'package:gait_sense/widgets/indicators/prediction_ticker.dart';
import 'package:gait_sense/widgets/indicators/session_limit_bar.dart';

/// Live HAR readouts: recording status, elapsed time, session limit,
/// prediction count, and the current per-window prediction.
class RecordingStatusPanel extends StatelessWidget {
  /// Creates the panel from the current recording [status] and readouts.
  const RecordingStatusPanel({
    required this.status,
    required this.elapsed,
    required this.maxSessionDuration,
    required this.predictionCount,
    required this.latest,
    super.key,
  });

  /// Where the session is in its lifecycle.
  final RecordingStatus status;

  /// Wall-clock time elapsed since the session started.
  final Duration elapsed;

  /// Maximum allowed session duration, shown via [SessionLimitBar] while
  /// recording.
  final Duration maxSessionDuration;

  /// Number of predictions received so far.
  final int predictionCount;

  /// Most recent prediction, or null before the first arrives.
  final ActivityPrediction? latest;

  @override
  Widget build(BuildContext context) {
    final textStyles = context.textStyles;
    final spacing = context.spacing;
    final muted = textStyles.bodyMedium?.copyWith(
      color: context.colors.onSurfaceVariant,
    );

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_statusLabel(status), style: textStyles.titleMedium),
          SizedBox(height: spacing.xs),
          Text(formatMmSs(elapsed), style: textStyles.displayMedium),
          if (status == RecordingStatus.recording) ...[
            SizedBox(height: spacing.xxs),
            SessionLimitBar(elapsed: elapsed, maxDuration: maxSessionDuration),
          ],
          SizedBox(height: spacing.lg),
          Text('Predikcija: $predictionCount', style: textStyles.bodyLarge),
          SizedBox(height: spacing.lg),
          PredictionTicker(latest: latest, style: muted),
        ],
      ),
    );
  }

  static String _statusLabel(RecordingStatus status) {
    switch (status) {
      case RecordingStatus.recording:
        return 'Snimanje u tijeku';
      case RecordingStatus.saving:
        return 'Spremanje…';
      case RecordingStatus.saved:
        return 'Zaustavljeno';
      // Not reached in practice — LiveHarContent renders a dedicated panel
      // for these three statuses instead of RecordingStatusPanel. Handled
      // here only so the switch stays exhaustive over RecordingStatus.
      case RecordingStatus.idle:
        return 'Zaustavljeno';
      case RecordingStatus.preparing:
        return 'Priprema…';
      case RecordingStatus.unavailable:
        return 'Senzori nedostupni';
    }
  }
}
