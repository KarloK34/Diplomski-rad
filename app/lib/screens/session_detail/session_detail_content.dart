import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/models/session_summary_record.dart';
import 'package:gait_sense/repositories/session_repository.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/utils/session_summary_format.dart';
import 'package:gait_sense/widgets/widgets.dart';
import 'package:go_router/go_router.dart';

/// Read-only detail view of a saved session, rebuilt from its persisted
/// summary: overview, activity charts, timeline, and the gait-quality section.
///
/// Reuses the same presentational widgets as the post-recording summary so a
/// stored session renders identically on any device, plus charts for the
/// visual breakdown.
class SessionDetailContent extends StatelessWidget {
  /// Creates the detail view for [record].
  const SessionDetailContent({required this.record, super.key});

  /// The persisted session being shown.
  final SessionSummaryRecord record;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final hasData = record.classTotals.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(formatStartTimestamp(record.startedAt)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Obriši sesiju',
            onPressed: () => unawaited(_confirmDelete(context)),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(spacing.md),
        children: [
          SessionOverviewHeader(
            startedAt: record.startedAt,
            duration: record.duration,
            predictionCount: record.predictionCount,
          ),
          if (hasData) ...[
            SizedBox(height: spacing.lg),
            ChartCard(
              title: 'Udio po aktivnosti',
              child: ActivityDistributionChart(totals: record.classTotals),
            ),
            SizedBox(height: spacing.lg),
            ChartCard(
              title: 'Vremenski slijed',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ActivityTimelineChart(timeline: record.timeline),
                  SizedBox(height: spacing.sm),
                  TimelineSegmentList(timeline: record.timeline),
                ],
              ),
            ),
          ],
          SizedBox(height: spacing.lg),
          SessionQualitySection(summary: record.quality),
          if (!hasData) ...[
            SizedBox(height: spacing.lg),
            const Text('Nema predikcija u ovoj sesiji.'),
          ],
        ],
      ),
    );
  }

  /// Confirms, then deletes this session and returns to the list.
  Future<void> _confirmDelete(BuildContext context) async {
    final repository = context.read<SessionRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Obriši sesiju?',
      message: 'Ova radnja trajno uklanja spremljenu sesiju.',
      confirmLabel: 'Obriši',
    );
    if (!confirmed) return;

    unawaited(
      repository
          .deleteSession(record.id)
          .catchError(
            (Object error) => debugPrint('Session delete failed: $error'),
          ),
    );
    if (!context.mounted) return;
    context.pop();
    messenger.showSnackBar(const SnackBar(content: Text('Sesija obrisana')));
  }
}
