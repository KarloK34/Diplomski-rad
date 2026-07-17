import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/pending_sessions/pending_sessions_cubit.dart';
import 'package:gait_sense/extensions/snackbar_context.dart';
import 'package:gait_sense/models/session_log.dart';
import 'package:gait_sense/models/session_summary_record.dart';
import 'package:gait_sense/repositories/session_log_repository.dart';
import 'package:gait_sense/repositories/session_repository.dart';
import 'package:gait_sense/screens/session_summary/session_summary_computation.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/utils/activity_labels.dart';
import 'package:gait_sense/utils/session_export.dart';
import 'package:gait_sense/utils/session_summary.dart';
import 'package:gait_sense/utils/session_summary_format.dart';
import 'package:gait_sense/widgets/widgets.dart';
import 'package:go_router/go_router.dart';

/// Renders the computed session summary: overview header, quality section,
/// per-class totals, timeline, and the save/export actions.
///
/// Nothing is persisted until the user taps save or export; backing out
/// without doing either asks for confirmation, since it discards the
/// recording along with its on-disk recovery draft (see
/// [SessionLogRepository.savePendingDraft]).
class SessionSummaryContent extends StatefulWidget {
  /// Creates the summary content for [session] with the computed [data].
  const SessionSummaryContent({
    required this.session,
    required this.data,
    this.heightCm,
    super.key,
  });

  /// The finished session being summarized.
  final SessionLog session;

  /// Aggregated totals, timeline, and quality metrics for [session].
  final SessionSummaryData data;

  /// Body height used for the walking-speed estimate, stored for traceability.
  final double? heightCm;

  @override
  State<SessionSummaryContent> createState() => _SessionSummaryContentState();
}

class _SessionSummaryContentState extends State<SessionSummaryContent> {
  bool _saving = false;

  /// Set once [_persistSession] succeeds, from either save or export — after
  /// that, backing out is a plain pop instead of a discard.
  bool _persisted = false;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final session = widget.session;
    final data = widget.data;
    final hasData = session.predictions.isNotEmpty;

    return PopScope(
      // Always intercepted so the discard-confirmation dialog and pending-
      // draft cleanup below run before the route actually pops; the explicit
      // `context.pop()` calls here and in `_saveSession` bypass this gate
      // themselves (go_router's pop reconciles its route list directly rather
      // than going through Navigator.maybePop), so they're unaffected.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _saving) return;
        await _handleBackNavigation(context, hasData: hasData);
      },
      child: Scaffold(
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
                      rows: [TimelineSegmentList(timeline: data.timeline)],
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
                        onPressed: hasData && !_saving
                            ? () => unawaited(_exportSession(context))
                            : null,
                        icon: const Icon(Icons.ios_share),
                        label: const Text('Izvezi sesiju'),
                      ),
                    ),
                    SizedBox(height: spacing.xs),
                    PrimaryButton(
                      label: 'Spremi sesiju',
                      loading: _saving,
                      onPressed: hasData ? _saveSession : null,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Confirms discarding (when there's data and it hasn't been persisted
  /// yet), cleans up the on-disk recovery draft, then pops.
  Future<void> _handleBackNavigation(
    BuildContext context, {
    required bool hasData,
  }) async {
    if (hasData && !_persisted) {
      final discard = await showConfirmationDialog(
        context,
        title: 'Odbaciti sesiju?',
        message:
            'Ako se vratite bez spremanja, ova sesija će biti trajno '
            'izbrisana.',
        confirmLabel: 'Odbaci sesiju',
      );
      if (!discard || !context.mounted) return;
    }

    if (!_persisted) {
      await context.read<SessionLogRepository>().deletePendingDraft(
        widget.session,
      );
      if (!context.mounted) return;
      unawaited(context.read<PendingSessionsCubit>().refresh());
    }

    if (context.mounted) context.pop();
  }

  /// Persists the session locally (durable) and to the cloud (offline-safe).
  ///
  /// Shared by save and export so exporting can never leave a session
  /// un-persisted: the local disk write is awaited so failures surface to the
  /// caller, while Firestore sync is fire-and-forget since it serves from the
  /// offline cache immediately and retries the network sync itself.
  Future<void> _persistSession() async {
    final session = widget.session;
    final data = widget.data;
    final logRepository = context.read<SessionLogRepository>();
    final sessionRepository = context.read<SessionRepository>();
    final record = SessionSummaryRecord.fromComputed(
      session: session,
      totals: data.totals,
      timeline: data.timeline,
      quality: data.quality,
      heightCm: widget.heightCm,
    );

    await logRepository.saveToDisk(session);
    // The recovery draft is superseded by the write above — clear it so a
    // future launch doesn't re-offer a session that's already durably saved.
    await logRepository.deletePendingDraft(session);
    _persisted = true;

    unawaited(
      sessionRepository
          .saveSession(record)
          .catchError(
            (Object error) => debugPrint('Session sync failed: $error'),
          ),
    );
    if (mounted) unawaited(context.read<PendingSessionsCubit>().refresh());
  }

  /// Saves the session via [_persistSession], then returns to the recording
  /// tab.
  Future<void> _saveSession() async {
    setState(() => _saving = true);
    try {
      await _persistSession();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      context.showSnackBar('Spremanje nije uspjelo: $error');
      return;
    }

    if (!mounted) return;
    context
      ..showSnackBar('Sesija spremljena')
      ..pop();
  }

  /// Persists the session via [_persistSession] — so a session can never be
  /// exported without also being saved — then writes a pretty-printed copy of
  /// the session JSON to the cache directory and hands it to the OS share
  /// sheet.
  Future<void> _exportSession(BuildContext context) async {
    final session = widget.session;

    setState(() => _saving = true);
    try {
      await _persistSession();
    } on Object catch (error) {
      if (!context.mounted) return;
      setState(() => _saving = false);
      context.showSnackBar('Spremanje nije uspjelo: $error');
      return;
    }

    try {
      if (!context.mounted) return;
      await shareSessionLog(context, session);
    } on Object catch (error) {
      if (!context.mounted) return;
      context.showSnackBar('Izvoz nije uspio: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
