import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gait_sense/extensions/snackbar_context.dart';
import 'package:gait_sense/models/session_log.dart';
import 'package:gait_sense/screens/session_summary/session_summary_computation.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/utils/activity_labels.dart';
import 'package:gait_sense/utils/session_summary.dart';
import 'package:gait_sense/utils/session_summary_format.dart';
import 'package:gait_sense/widgets/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Renders the computed session summary: overview header, quality section,
/// per-class totals, timeline, and the export/new-session actions.
class SessionSummaryContent extends StatelessWidget {
  /// Creates the summary content for [session] with the computed [data].
  const SessionSummaryContent({
    required this.session,
    required this.data,
    super.key,
  });

  /// The finished session being summarized.
  final SessionLog session;

  /// Aggregated totals, timeline, and quality metrics for [session].
  final SessionSummaryData data;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final hasData = session.predictions.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Sažetak sesije')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(spacing.md),
              children: [
                SessionOverviewHeader(
                  startedAt: session.startedAt,
                  duration: sessionDuration(session),
                  predictionCount: session.predictions.length,
                ),
                SizedBox(height: spacing.lg),
                SessionQualitySection(summary: data.quality),
                if (!hasData) ...[
                  SizedBox(height: spacing.lg),
                  const Text('Nema predikcija u ovoj sesiji.'),
                ] else ...[
                  SizedBox(height: spacing.lg),
                  InfoCard(
                    title: 'Udio po aktivnosti',
                    rows: [
                      for (final total in data.totals)
                        ActivityTotalRow(
                          activityLabel: activityLabelHr(total.label),
                          valueLabel: formatClassTotalValue(total),
                        ),
                    ],
                  ),
                  SizedBox(height: spacing.lg),
                  InfoCard(
                    title: 'Vremenski slijed',
                    rows: [
                      for (final segment in data.timeline)
                        TimelineSegmentRow(
                          timeRangeLabel: formatTimelineSegmentTimeRange(
                            segment,
                          ),
                          activityLabel: activityLabelHr(segment.label),
                          windowCountLabel: windowCountLabelHr(
                            segment.windows,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.all(spacing.md),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: hasData
                          ? () => unawaited(_exportSession(context))
                          : null,
                      icon: const Icon(Icons.ios_share),
                      label: const Text('Izvezi sesiju'),
                    ),
                  ),
                  SizedBox(height: spacing.xs),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => context.pop(),
                      child: const Text('Nova sesija'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Writes a pretty-printed copy of the session JSON to the cache directory
  /// and hands it to the OS share sheet.
  ///
  /// The authoritative copy already lives under `<documents>/sessions/`
  /// (written on Stop by the repository); this transient cache copy exists
  /// only because the share sheet takes a file path.
  Future<void> _exportSession(BuildContext context) async {
    final renderBox = context.findRenderObject() as RenderBox?;
    final origin = renderBox != null && renderBox.hasSize
        ? renderBox.localToGlobal(Offset.zero) & renderBox.size
        : null;

    try {
      final directory = await getTemporaryDirectory();
      final stamp = session.startedAt.toIso8601String().replaceAll(':', '-');
      final file = File('${directory.path}/session_$stamp.json');
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(session.toJson()),
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Gait Sense — sesija',
          text: 'Zapis HAR sesije (${session.predictions.length} predikcija).',
          sharePositionOrigin: origin,
        ),
      );
    } on Exception catch (error) {
      if (!context.mounted) return;
      context.showSnackBar('Izvoz nije uspio: $error');
    }
  }
}
