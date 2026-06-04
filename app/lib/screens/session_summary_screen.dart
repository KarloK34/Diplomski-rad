import 'package:flutter/material.dart';
import 'package:gait_sense/models/session_log.dart';

/// Read-only summary of a finished recording session.
///
/// Renders the session's time bounds and prediction count. Per-class totals, a
/// grouped activity timeline, and JSON export are layered on top of this.
class SessionSummaryScreen extends StatelessWidget {
  /// Creates the summary screen for [session].
  const SessionSummaryScreen({required this.session, super.key});

  /// The finished session to summarize.
  final SessionLog session;

  @override
  Widget build(BuildContext context) {
    final stoppedAt = session.stoppedAt;
    final duration = stoppedAt == null
        ? Duration.zero
        : stoppedAt.difference(session.startedAt);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Sažetak sesije')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trajanje: ${_formatDuration(duration)}',
                style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Broj predikcija: ${session.predictions.length}'),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Nova sesija'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }
}
