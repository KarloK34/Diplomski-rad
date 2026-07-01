import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/models/gait_segment.dart';
import 'package:gait_sense/models/session_log.dart';
import 'package:gait_sense/services/user_preferences_repository.dart';
import 'package:gait_sense/utils/activity_labels.dart';
import 'package:gait_sense/utils/gait_cadence.dart';
import 'package:gait_sense/utils/gait_signal_segments.dart';
import 'package:gait_sense/utils/gait_walking_speed.dart';
import 'package:gait_sense/utils/session_summary.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// ---------------------------------------------------------------------------
// Top-level isolate entry point
// ---------------------------------------------------------------------------

/// Input bundle passed to the worker isolate via [compute].
///
/// [compute] accepts a single SendPort-serialisable argument, so the session
/// and optional user height are bundled here.
class _SummaryInput {
  const _SummaryInput({required this.session, this.userHeightCm});

  final SessionLog session;
  final double? userHeightCm;
}

/// Aggregated summary data computed off the UI isolate.
class _SummaryData {
  const _SummaryData({
    required this.totals,
    required this.timeline,
    required this.quality,
  });

  final List<ClassTotal> totals;
  final List<TimelineSegment> timeline;
  final SessionQualitySummary quality;
}

/// Entry point for [compute]. Must be a top-level function.
_SummaryData _computeSummaryData(_SummaryInput input) {
  return _SummaryData(
    totals: computeClassTotals(input.session),
    timeline: computeTimeline(input.session),
    quality: computeSessionQualitySummary(
      input.session,
      userHeightCm: input.userHeightCm,
    ),
  );
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Read-only summary of a finished recording session.
///
/// Heavy aggregation (class totals, timeline, gait cadence) is offloaded to a
/// worker isolate via [compute] so the UI thread is never blocked, even for
/// sessions that accumulated tens of thousands of raw IMU samples.  A
/// [CircularProgressIndicator] is shown while the worker runs.
///
/// Renders the session header, per-class time totals (sorted by occupied
/// time), grouped-text activity segments, and gait-analysis candidates.
/// Offers JSON export through the system share sheet and a "new session"
/// action that returns to the live screen.
class SessionSummaryScreen extends StatefulWidget {
  /// Creates the summary screen for [session].
  const SessionSummaryScreen({required this.session, super.key});

  /// The finished session to summarize.
  final SessionLog session;

  @override
  State<SessionSummaryScreen> createState() => _SessionSummaryScreenState();
}

class _SessionSummaryScreenState extends State<SessionSummaryScreen> {
  late final Future<_SummaryData> _summaryFuture;

  Future<_SummaryInput> _buildInput() async {
    final prefs = context.read<UserPreferencesRepository>();
    final heightCm = await prefs.getHeightCm();
    return _SummaryInput(session: widget.session, userHeightCm: heightCm);
  }

  @override
  void initState() {
    super.initState();
    // Read the user height (fast local read), then dispatch the heavy
    // computation to a worker isolate.  The future is stored so Flutter does
    // not re-submit it on rebuilds.
    _summaryFuture = _buildInput().then(
      (input) => compute(_computeSummaryData, input),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_SummaryData>(
      future: _summaryFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorScaffold(error: snapshot.error!);
        }
        if (!snapshot.hasData) {
          return const _LoadingScaffold();
        }
        return _SummaryScaffold(
          session: widget.session,
          data: snapshot.data!,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Loading / error placeholders
// ---------------------------------------------------------------------------

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sažetak sesije')),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorScaffold extends StatelessWidget {
  const _ErrorScaffold({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sažetak sesije')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Nije moguće izračunati sažetak sesije.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Natrag'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Main content scaffold
// ---------------------------------------------------------------------------

class _SummaryScaffold extends StatelessWidget {
  const _SummaryScaffold({
    required this.session,
    required this.data,
  });

  final SessionLog session;
  final _SummaryData data;

  @override
  Widget build(BuildContext context) {
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
                _QualitySection(summary: data.quality),
                if (!hasData) ...[
                  const SizedBox(height: 24),
                  const Text('Nema predikcija u ovoj sesiji.'),
                ] else ...[
                  const SizedBox(height: 24),
                  _Section(
                    title: 'Udio po aktivnosti',
                    children: [
                      for (final total in data.totals)
                        _ClassTotalRow(total: total),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _Section(
                    title: 'Vremenski slijed',
                    children: [
                      for (final segment in data.timeline)
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

// ---------------------------------------------------------------------------
// Reusable section widgets (unchanged from before)
// ---------------------------------------------------------------------------

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
        const SizedBox(height: 8),
        _QualityRow(
          label: 'Kadenca (eksperimentalno)',
          value: _formatCadence(summary.gaitCadence),
        ),
        _QualityRow(
          label: 'Detektirani koraci (eksperimentalno)',
          value: _formatStepCount(summary.gaitCadence),
        ),
        if (summary.gaitCadence.hasComputedCadence)
          _QualityRow(
            label: 'Pouzdanost procjene',
            value: _formatCadenceConfidence(summary.gaitCadence.confidence),
          ),
        if (summary.gaitCadence.hasComputedCadence &&
            summary.gaitCadence.confidenceReason != null)
          _QualityRow(
            label: 'Napomena',
            value: _formatCadenceConfidenceReason(
              summary.gaitCadence.confidenceReason,
            ),
          ),
        if (summary.gaitCadence.temporalParameters case final temporal?) ...[
          _QualityRow(
            label: 'Prosječno vrijeme koraka (eksperimentalno)',
            value: _formatDurationSeconds(temporal.meanStepTime),
          ),
          _QualityRow(
            label: 'Varijabilnost vremena koraka (eksperimentalno)',
            value: _formatPercent(
              temporal.stepTimeCoefficientOfVariation,
            ),
          ),
          if (temporal.meanStrideTime case final strideTime?)
            _QualityRow(
              label: 'Prosječno vrijeme iskoraka (eksperimentalno)',
              value: _formatDurationSeconds(strideTime),
            ),
          if (temporal.strideTimeCoefficientOfVariation case final strideCv?)
            _QualityRow(
              label: 'Varijabilnost vremena iskoraka (eksperimentalno)',
              value: _formatPercent(strideCv),
            ),
          _QualityRow(
            label: 'Varijabilnost kadence (eksperimentalno)',
            value: _formatCadenceSpread(
              temporal.instantCadenceStandardDeviationStepsPerMinute,
            ),
          ),
          _QualityRow(
            label: 'Regularnost signala (indikator kvalitete)',
            value: _formatGaitRegularity(temporal.gaitRegularity),
          ),
        ],
        if (!summary.gaitCadence.hasComputedCadence)
          _QualityRow(
            label: 'Razlog',
            value: _formatCadenceUnavailableReason(summary.gaitCadence.reason),
          ),
        const SizedBox(height: 8),
        _QualityRow(
          label: 'Brzina hoda (gruba procjena)',
          value: _formatWalkingSpeed(summary.gaitWalkingSpeed),
        ),
        _QualityRow(
          label: 'Duljina koraka (gruba procjena)',
          value: _formatStepLength(summary.gaitWalkingSpeed),
        ),
        if (!summary.gaitWalkingSpeed.hasComputedSpeed)
          _QualityRow(
            label: 'Razlog brzine hoda',
            value: _formatWalkingSpeedUnavailableReason(
              summary.gaitWalkingSpeed,
            ),
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
                  '${_formatClock(segment.analysisStartOffset)} - '
                  '${_formatClock(segment.analysisEndOffset)}',
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

// ---------------------------------------------------------------------------
// Formatting helpers (unchanged)
// ---------------------------------------------------------------------------

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

String _formatCadence(GaitCadenceSummary cadence) {
  final value = cadence.averageCadenceStepsPerMinute;
  if (!cadence.hasComputedCadence || value == null) return 'Nije dostupna';
  return '${value.round()} koraka/min';
}

String _formatStepCount(GaitCadenceSummary cadence) {
  if (!cadence.hasComputedCadence) return 'Nije dostupno';
  return cadence.totalStepCount.toString();
}

String _formatCadenceSpread(double stepsPerMinute) {
  return '${stepsPerMinute.round()} koraka/min';
}

String _formatGaitRegularity(double? regularity) {
  if (regularity == null) return 'Nije dostupna';
  return _formatPercent(regularity);
}

String _formatCadenceConfidence(GaitCadenceConfidence confidence) {
  return switch (confidence) {
    GaitCadenceConfidence.low => 'Niska',
    GaitCadenceConfidence.moderate => 'Srednja',
    GaitCadenceConfidence.high => 'Visoka',
  };
}

String _formatCadenceConfidenceReason(String? reason) {
  return switch (reason) {
    cadenceEstimatesDisagreeReason =>
      'Procjene iz vrhova i dominantnog perioda odstupaju.',
    lowCadencePeriodicityReason => 'Periodičnost signala je niska.',
    limitedCadenceEvidenceReason => 'Dostupno je malo ponovljenih koraka.',
    _ => 'Procjenu treba tumačiti oprezno.',
  };
}

String _formatCadenceUnavailableReason(String? reason) {
  switch (reason) {
    case noSuitableCadenceSignalReason:
      return 'Nema dovoljno stabilnog hodanja po ravnom.';
    case missingRawSamplesReason:
      return 'Nema spremljenog signala senzora.';
    case invalidSampleIndexRangeReason:
    case sampleIndexOutOfRangeReason:
    case invalidTimeOffsetRangeReason:
    case noSamplesInTimeRangeReason:
      return 'Signal hodanja nije dostupan za ovaj zapis.';
    case emptyCadenceSignalReason:
      return 'Nema dostupnog signala hodanja.';
    case cadenceSignalTooShortReason:
      return 'Signal hodanja je prekratak.';
    case tooFewCadencePeaksReason:
      return 'Nije detektirano dovoljno koraka.';
    case lowCadencePeriodicityReason:
      return 'Signal hodanja nema dovoljno jasnu periodičnost.';
    case invalidCadenceTimestampsReason:
      return 'Vremenske oznake signala nisu valjane.';
    default:
      return 'Kadenca nije dostupna.';
  }
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

String _formatWalkingSpeed(GaitWalkingSpeedSummary speed) {
  final value = speed.averageWalkingSpeedMs;
  if (!speed.hasComputedSpeed || value == null) return 'Nije dostupna';
  return '${value.toStringAsFixed(2).replaceAll('.', ',')} m/s';
}

String _formatStepLength(GaitWalkingSpeedSummary speed) {
  final value = speed.averageStepLengthM;
  if (!speed.hasComputedSpeed || value == null) return 'Nije dostupna';
  return '${(value * 100).round()} cm';
}

String _formatWalkingSpeedUnavailableReason(GaitWalkingSpeedSummary speed) {
  return switch (speed.reason) {
    missingUserHeightReason =>
      'Visina nije postavljena — dodajte je u postavkama.',
    noSuitableCadenceSignalReason =>
      'Nema dovoljno stabilnog hodanja po ravnom.',
    cadenceNotComputedReason => 'Kadenca nije izračunata.',
    lowConfidenceCadenceReason =>
      'Kadenca je preniske pouzdanosti za procjenu brzine.',
    insufficientVerticalAmplitudeReason => 'Vertikalni signal je prenizak.',
    invalidPendulumGeometryReason =>
      'Geometrija modela nije valjana za ovaj signal.',
    implausibleStepLengthReason =>
      'Procijenjena duljina koraka je izvan očekivanog raspona.',
    _ => 'Brzina hoda nije dostupna.',
  };
}
