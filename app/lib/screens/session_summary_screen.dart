import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gait_sense/models/gait_segment.dart';
import 'package:gait_sense/models/session_log.dart';
import 'package:gait_sense/utils/activity_labels.dart';
import 'package:gait_sense/utils/session_summary.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Read-only summary of a finished recording session.
///
/// Renders the session header, per-class time totals (sorted by occupied time),
/// grouped-text activity segments, and gait-analysis candidates. Offers JSON
/// export through the system share sheet and a "new session" action that
/// returns to the live screen.
class SessionSummaryScreen extends StatelessWidget {
  /// Creates the summary screen for [session].
  const SessionSummaryScreen({required this.session, super.key});

  /// The finished session to summarize.
  final SessionLog session;

  @override
  Widget build(BuildContext context) {
    final totals = computeClassTotals(session);
    final timeline = computeTimeline(session);
    final quality = computeSessionQualitySummary(session);
    final hasData = session.predictions.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Sažetak sesije')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Header(session: session),
                const SizedBox(height: 24),
                _QualitySection(summary: quality),
                if (!hasData) ...[
                  const SizedBox(height: 24),
                  const Text('Nema predikcija u ovoj sesiji.'),
                ] else ...[
                  const SizedBox(height: 24),
                  _Section(
                    title: 'Udio po aktivnosti',
                    children: [
                      for (final total in totals) _ClassTotalRow(total: total),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _Section(
                    title: 'Vremenski slijed',
                    children: [
                      for (final segment in timeline)
                        _TimelineRow(segment: segment),
                    ],
                  ),
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
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
                  const SizedBox(height: 8),
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
          ),
        ],
      ),
    );
  }

  /// Writes a pretty-printed copy of the session JSON to the cache directory
  /// and hands it to the OS share sheet.
  ///
  /// The authoritative copy already lives under `<documents>/sessions/`
  /// (written on Stop by the repository); this transient cache copy exists only
  /// because the share sheet takes a file path. It is indented for human
  /// readability, unlike the compact persisted copy.
  Future<void> _exportSession(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
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
      messenger.showSnackBar(
        SnackBar(content: Text('Izvoz nije uspio: $error')),
      );
    }
  }
}

/// Session start time, duration, and total prediction count.
class _Header extends StatelessWidget {
  const _Header({required this.session});

  final SessionLog session;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Početak: ${_formatStartTime(session.startedAt)}',
          style: textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Trajanje: ${_formatClock(sessionDuration(session))}',
          style: textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text('Broj predikcija: ${session.predictions.length}'),
      ],
    );
  }
}

/// A titled block with a list of rows beneath it.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }
}

/// One per-class total: activity name on the left, time and percent on the
/// right.
class _ClassTotalRow extends StatelessWidget {
  const _ClassTotalRow({required this.total});

  final ClassTotal total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final percent = (total.fraction * 100).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(activityLabelHr(total.label))),
          Text('${_formatClock(total.time)} ($percent %)', style: muted),
        ],
      ),
    );
  }
}

class _QualitySection extends StatelessWidget {
  const _QualitySection({required this.summary});

  final SessionQualitySummary summary;

  @override
  Widget build(BuildContext context) {
    final suitableGaitSegments = summary.suitableGaitSegments;
    return _Section(
      title: 'Pouzdanost sesije',
      children: [
        _QualityRow(
          label: 'Raw HAR rezultat',
          value: _formatLabelCounts(summary.rawLabelWindowCounts),
        ),
        _QualityRow(
          label: 'Smoothed HAR rezultat',
          value: _formatLabelCounts(summary.effectiveLabelWindowCounts),
        ),
        _QualityRow(
          label: 'Raw/smoothed promjene',
          value:
              '${windowCountLabelHr(summary.rawSmoothedChangeCount)} od '
              '${windowCountLabelHr(summary.predictionCount)}',
        ),
        _QualityRow(
          label: 'Promijenjeni prozori',
          value: _formatPercent(summary.rawSmoothedChangeFraction),
        ),
        _QualityRow(
          label: 'Stabilna lokomocija',
          value: summary.hasEnoughStableLocomotion ? 'Da' : 'Ne',
        ),
        _QualityRow(
          label: 'Trajanje stabilne lokomocije',
          value: _formatDurationSeconds(summary.stableLocomotionDuration),
        ),
        const SizedBox(height: 8),
        _QualityRow(
          label: 'Kandidati za analizu hoda',
          value: suitableGaitSegments.isEmpty
              ? 'Nema kandidata'
              : _segmentCountLabelHr(suitableGaitSegments.length),
        ),
        _QualityRow(
          label: 'Trajanje stabilnog hodanja po ravnom',
          value: _formatDurationSeconds(summary.levelWalkingGaitDuration),
        ),
        if (suitableGaitSegments.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Parametri hoda nisu izračunati jer nema dovoljno stabilnog '
              'hodanja po ravnom.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          )
        else ...[
          const SizedBox(height: 4),
          for (final segment in suitableGaitSegments)
            _GaitSegmentRow(segment: segment),
        ],
      ],
    );
  }
}

class _QualityRow extends StatelessWidget {
  const _QualityRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: muted),
          const SizedBox(height: 2),
          Text(value),
        ],
      ),
    );
  }
}

/// One suitable level-walking gait-analysis candidate.
class _GaitSegmentRow extends StatelessWidget {
  const _GaitSegmentRow({required this.segment});

  final GaitSegment segment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  '${_formatClock(segment.startOffset)} - '
                  '${_formatClock(segment.endOffset)}',
                  style: muted,
                ),
              ),
              const Expanded(child: Text('Hodanje po ravnom')),
              Text(windowCountLabelHr(segment.windows), style: muted),
            ],
          ),
          Text(_formatLabelCounts(segment.labelCounts), style: muted),
        ],
      ),
    );
  }
}

/// One timeline segment: time range, activity name, and window count.
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.segment});

  final TimelineSegment segment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '${_formatClock(segment.start)} – ${_formatClock(segment.end)}',
              style: muted,
            ),
          ),
          Expanded(child: Text(activityLabelHr(segment.label))),
          Text(windowCountLabelHr(segment.windows), style: muted),
        ],
      ),
    );
  }
}

String _two(int value) => value.toString().padLeft(2, '0');

String _formatLabelCounts(Map<String, int> counts) {
  if (counts.isEmpty) return 'nema predikcija';

  final entries = counts.entries.toList()
    ..sort((a, b) {
      final byWindows = b.value.compareTo(a.value);
      return byWindows != 0 ? byWindows : a.key.compareTo(b.key);
    });
  return entries
      .map((entry) => '${activityLabelHr(entry.key)}: ${entry.value}')
      .join(', ');
}

String _formatPercent(double fraction) {
  final percentage = fraction * 100;
  final rounded = percentage.roundToDouble();
  final decimals = (percentage - rounded).abs() < 0.05 ? 0 : 1;
  return '${percentage.toStringAsFixed(decimals).replaceAll('.', ',')} %';
}

String _segmentCountLabelHr(int count) {
  final ones = count % 10;
  final teens = count % 100;
  final noun = ones == 1 && teens != 11
      ? 'segment'
      : ones >= 2 && ones <= 4 && (teens < 12 || teens > 14)
      ? 'segmenta'
      : 'segmenata';
  return '$count $noun';
}

String _formatDurationSeconds(Duration duration) {
  if (duration.inMinutes >= 1) return _formatClock(duration);
  final seconds = duration.inMilliseconds / 1000;
  return '${seconds.toStringAsFixed(1).replaceAll('.', ',')} s';
}

/// Formats a duration as `mm:ss`, or `h:mm:ss` once it passes an hour.
String _formatClock(Duration d) {
  final hours = d.inHours;
  final minutes = _two(d.inMinutes.remainder(60));
  final seconds = _two(d.inSeconds.remainder(60));
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}

/// Formats a wall-clock start time as `dd.MM.yyyy. HH:mm` in local time.
String _formatStartTime(DateTime dt) {
  final local = dt.toLocal();
  return '${_two(local.day)}.${_two(local.month)}.${local.year}. '
      '${_two(local.hour)}:${_two(local.minute)}';
}
