import 'dart:convert';
import 'dart:io';

import 'package:gait_sense/models/session_log.dart';
import 'package:gait_sense/screens/session_summary/session_summary_computation.dart';
import 'package:gait_sense/utils/activity_labels.dart';
import 'package:gait_sense/utils/gait_cadence.dart';
import 'package:gait_sense/utils/gait_quality_format.dart';
import 'package:gait_sense/utils/gait_segments.dart';
import 'package:gait_sense/utils/gait_signal_segments.dart';
import 'package:gait_sense/utils/gait_temporal_parameters.dart';
import 'package:gait_sense/utils/gait_walking_speed.dart';
import 'package:gait_sense/utils/session_summary.dart';
import 'package:gait_sense/utils/session_summary_format.dart';

/// Replays one or more exported session JSON files through the exact same
/// aggregation code the app runs (`computeSessionSummaryData`, the isolate
/// entry point behind the "Sažetak sesije" screen), so a recorded session can
/// be reused to check a code change instead of re-recording a walk every time.
///
/// Usage:
///   dart run tool/diagnose_gait_sessions.dart [--height=CM] [--json] JSON...
///
/// `--height` supplies the body height (cm) the walking-speed estimate needs;
/// omit it to see the "no height" behaviour the app shows before a user sets
/// one in Settings. `--json` prints one machine-readable line per file
/// instead of the human-readable report, for diffing two runs (e.g. before
/// and after a code change) with a normal text diff tool.
Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/diagnose_gait_sessions.dart '
      '[--height=<cm>] [--json] <json>...',
    );
    exitCode = 64;
    return;
  }

  double? heightCm;
  var jsonOutput = false;
  final paths = <String>[];
  for (final arg in args) {
    if (arg.startsWith('--height=')) {
      heightCm = double.tryParse(arg.substring('--height='.length));
      if (heightCm == null) {
        stderr.writeln('Could not parse --height value in "$arg".');
        exitCode = 64;
        return;
      }
    } else if (arg == '--json') {
      jsonOutput = true;
    } else {
      paths.add(arg);
    }
  }
  if (paths.isEmpty) {
    stderr.writeln('No session JSON file given.');
    exitCode = 64;
    return;
  }

  for (final path in paths) {
    final file = File(path);
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final session = SessionLog.fromJson(json);
    // Same call the summary screen makes (session_summary_screen.dart),
    // minus the `compute()` isolate hop — computeSessionSummaryData itself
    // has no Flutter dependency, so this is the identical production code
    // path, not a reimplementation.
    final data = computeSessionSummaryData(
      SessionSummaryInput(session: session, userHeightCm: heightCm),
    );

    if (jsonOutput) {
      stdout.writeln(
        jsonEncode(_summaryToJson(file, session, data, heightCm)),
      );
      continue;
    }

    stdout
      ..writeln()
      ..writeln('== ${file.uri.pathSegments.last} ==');
    _printAppSummary(session, data, heightCm);
    stdout.writeln('-- debug detail --');
    _printSession(session);
    _printRuns(session, heightCm);
    _printGait(session, heightCm);
  }
}

/// Prints the same rows the "Sažetak sesije" screen shows, using the app's own
/// formatter functions (`gait_quality_format.dart`,
/// `session_summary_format.dart`) so the text — not just the underlying
/// numbers — matches what a user would actually see.
void _printAppSummary(
  SessionLog session,
  SessionSummaryData data,
  double? heightCm,
) {
  final quality = data.quality;
  final cadence = quality.gaitCadence;
  final speed = quality.gaitWalkingSpeed;
  final suitableSegments = quality.suitableGaitSegments;
  final gaitCandidatesLabel = suitableSegments.isEmpty
      ? 'Nema kandidata'
      : formatSegmentCountHr(suitableSegments.length);

  stdout
    ..writeln('-- app summary (Sažetak sesije) --')
    ..writeln(
      'started=${formatStartTimestamp(session.startedAt)} '
      'duration=${formatElapsedClock(sessionDuration(session))} '
      'predictions=${session.predictions.length} '
      'heightCm=${heightCm ?? "not set"}',
    )
    ..writeln('Udio po aktivnosti:');
  for (final total in data.totals) {
    stdout.writeln(
      '  ${activityLabelHr(total.label)}: ${formatClassTotalValue(total)}',
    );
  }

  stdout.writeln('Vremenski slijed:');
  for (final segment in data.timeline) {
    stdout.writeln(
      '  ${activityLabelHr(segment.label)} '
      '${formatTimelineSegmentTimeRange(segment)} '
      '(${windowCountLabelHr(segment.windows)})',
    );
  }

  stdout
    ..writeln('Kvaliteta klasifikacije:')
    ..writeln(
      '  Raw HAR rezultat: ${formatLabelCounts(quality.rawLabelWindowCounts)}',
    )
    ..writeln(
      '  Smoothed HAR rezultat: '
      '${formatLabelCounts(quality.effectiveLabelWindowCounts)}',
    )
    ..writeln(
      '  Raw/smoothed promjene: '
      '${windowCountLabelHr(quality.rawSmoothedChangeCount)} od '
      '${windowCountLabelHr(quality.predictionCount)}',
    )
    ..writeln(
      '  Promijenjeni prozori: '
      '${formatPercentHr(quality.rawSmoothedChangeFraction)}',
    )
    ..writeln(
      '  Stabilna lokomocija: '
      '${quality.hasEnoughStableLocomotion ? "Da" : "Ne"}',
    )
    ..writeln(
      '  Trajanje stabilne lokomocije: '
      '${formatDurationSecondsHr(quality.stableLocomotionDuration)}',
    )
    ..writeln('Parametri hoda:')
    ..writeln('  Kandidati za analizu hoda: $gaitCandidatesLabel')
    ..writeln(
      '  Trajanje stabilnog hodanja po ravnom: '
      '${formatDurationSecondsHr(quality.levelWalkingGaitDuration)}',
    )
    ..writeln('  Kadenca (eksperimentalno): ${formatCadenceHr(cadence)}')
    ..writeln(
      '  Detektirani koraci (eksperimentalno): ${formatStepCountHr(cadence)}',
    );

  if (cadence.hasComputedCadence) {
    stdout.writeln(
      '  Pouzdanost procjene: '
      '${formatCadenceConfidenceHr(cadence.confidence)}',
    );
    if (cadence.confidenceReason != null) {
      stdout.writeln(
        '  Napomena: '
        '${formatCadenceConfidenceReasonHr(cadence.confidenceReason)}',
      );
    }
  } else {
    stdout.writeln(
      '  Razlog: ${formatCadenceUnavailableReasonHr(cadence.reason)}',
    );
  }

  if (cadence.temporalParameters case final temporal?) {
    stdout
      ..writeln(
        '  Prosječno vrijeme koraka (eksperimentalno): '
        '${formatDurationSecondsHr(temporal.meanStepTime)}',
      )
      ..writeln(
        '  Varijabilnost vremena koraka (eksperimentalno): '
        '${formatPercentHr(temporal.stepTimeCoefficientOfVariation)}',
      );
    if (temporal.meanStrideTime case final strideTime?) {
      stdout.writeln(
        '  Prosječno vrijeme iskoraka (eksperimentalno): '
        '${formatDurationSecondsHr(strideTime)}',
      );
    }
    if (temporal.strideTimeCoefficientOfVariation case final strideCv?) {
      stdout.writeln(
        '  Varijabilnost vremena iskoraka (eksperimentalno): '
        '${formatPercentHr(strideCv)}',
      );
    }
    stdout
      ..writeln(
        '  Varijabilnost kadence (eksperimentalno): '
        '${formatCadenceSpreadHr(
          temporal.instantCadenceStandardDeviationStepsPerMinute,
        )}',
      )
      ..writeln(
        '  Regularnost signala (indikator kvalitete): '
        '${formatGaitRegularityHr(temporal.gaitRegularity)}',
      );
  }

  stdout
    ..writeln('  Brzina hoda (gruba procjena): ${formatWalkingSpeedHr(speed)}')
    ..writeln(
      '  Duljina koraka (gruba procjena): ${formatStepLengthHr(speed)}',
    );
  if (!speed.hasComputedSpeed) {
    stdout.writeln(
      '  Razlog brzine hoda: '
      '${formatWalkingSpeedUnavailableReasonHr(speed)}',
    );
  }

  for (final segment in suitableSegments) {
    stdout.writeln(
      '  segment ${formatGaitSegmentTimeRange(segment)} '
      'windows=${windowCountLabelHr(segment.windows)} '
      'labels=${formatLabelCounts(segment.labelCounts)}',
    );
  }
  stdout.writeln();
}

/// Builds a flat, diffable JSON record for one file — run once before a code
/// change and once after, then diff the two outputs directly.
Map<String, dynamic> _summaryToJson(
  File file,
  SessionLog session,
  SessionSummaryData data,
  double? heightCm,
) {
  final quality = data.quality;
  final cadence = quality.gaitCadence;
  final speed = quality.gaitWalkingSpeed;
  final temporal = cadence.temporalParameters;

  return {
    'file': file.uri.pathSegments.last,
    'startedAt': session.startedAt.toIso8601String(),
    'durationSeconds': sessionDuration(session).inMilliseconds / 1000,
    'predictionCount': session.predictions.length,
    'heightCm': heightCm,
    'classTotals': [
      for (final total in data.totals)
        {
          'label': total.label,
          'windows': total.windows,
          'seconds': total.time.inMilliseconds / 1000,
          'fraction': total.fraction,
        },
    ],
    'stableLocomotion': {
      'hasEnough': quality.hasEnoughStableLocomotion,
      'durationSeconds':
          quality.stableLocomotionDuration.inMilliseconds / 1000,
      'windowCount': quality.stableLocomotionWindowCount,
    },
    'gaitSegments': {
      'suitableCount': quality.suitableGaitSegments.length,
      'levelWalkingDurationSeconds':
          quality.levelWalkingGaitDuration.inMilliseconds / 1000,
    },
    'cadence': {
      'status': cadence.status.name,
      'reason': cadence.reason,
      'confidence': cadence.confidence.name,
      'confidenceReason': cadence.confidenceReason,
      'totalStepCount': cadence.totalStepCount,
      'averageCadenceStepsPerMinute': cadence.averageCadenceStepsPerMinute,
      'computedResultCount': cadence.computedResultCount,
      'signalSegmentCount': cadence.signalSegmentCount,
    },
    'temporal': temporal == null
        ? null
        : {
            'stepIntervalCount': temporal.stepIntervalCount,
            'meanStepTimeSeconds': temporal.meanStepTime.inMilliseconds / 1000,
            'stepTimeCoefficientOfVariation':
                temporal.stepTimeCoefficientOfVariation,
            'strideIntervalCount': temporal.strideIntervalCount,
            'meanStrideTimeSeconds': temporal.meanStrideTime == null
                ? null
                : temporal.meanStrideTime!.inMilliseconds / 1000,
            'strideTimeCoefficientOfVariation':
                temporal.strideTimeCoefficientOfVariation,
            'instantCadenceStdStepsPerMinute':
                temporal.instantCadenceStandardDeviationStepsPerMinute,
            'gaitRegularity': temporal.gaitRegularity,
          },
    'walkingSpeed': {
      'status': speed.status.name,
      'reason': speed.reason,
      'averageWalkingSpeedMs': speed.averageWalkingSpeedMs,
      'averageStepLengthM': speed.averageStepLengthM,
      'computedResultCount': speed.computedResultCount,
      'signalSegmentCount': speed.signalSegmentCount,
    },
  };
}

// ---------------------------------------------------------------------------
// Low-level debug detail: per-segment thresholds, offsets, and periodicity —
// useful when the app-summary numbers above look wrong and the cadence/speed
// internals need inspecting directly.
// ---------------------------------------------------------------------------

void _printSession(SessionLog session) {
  final smoothedChanges = session.predictions.where((p) => p.wasSmoothed);
  final out = stdout
    ..writeln('duration=${_duration(sessionDuration(session))}')
    ..writeln('rawSamples=${session.rawSamples.length}')
    ..writeln('predictions=${session.predictions.length}')
    ..writeln(
      'effectiveCounts=${_counts(session.predictions.map((p) => p.label))}',
    )
    ..writeln(
      'rawCounts=${_counts(session.predictions.map((p) => p.rawLabel))}',
    )
    ..writeln('smoothedChanges=${smoothedChanges.length}');

  if (session.rawSamples.length > 1) {
    final intervals = <int>[
      for (var i = 1; i < session.rawSamples.length; i++)
        session.rawSamples[i].timestamp
            .difference(session.rawSamples[i - 1].timestamp)
            .inMicroseconds,
    ]..sort();
    out.writeln(
      'sampleIntervalUs min=${intervals.first} '
      'median=${intervals[intervals.length ~/ 2]} max=${intervals.last}',
    );
  }

  final endIndices = [
    for (final p in session.predictions)
      if (p.endSampleIndex != null) p.endSampleIndex!,
  ];
  if (endIndices.isNotEmpty) {
    out.writeln(
      'predictionEndSampleIndex first=${endIndices.first} '
      'last=${endIndices.last}',
    );
  }
}

void _printRuns(SessionLog session, double? heightCm) {
  final summary = computeSessionQualitySummary(
    session,
    userHeightCm: heightCm,
  );
  stdout.writeln(
    'stableLocomotion segments=${summary.stableLocomotionSegments.length} '
    'duration=${_duration(summary.stableLocomotionDuration)}',
  );
  for (final s in summary.stableLocomotionSegments) {
    stdout.writeln(
      '  stable ${s.startIndex}-${s.endIndexExclusive} '
      'windows=${s.windows} labels=${s.effectiveLabelWindowCounts} '
      'time=${_duration(s.duration)}',
    );
  }
}

void _printGait(SessionLog session, double? heightCm) {
  final gaitSegments = extractGaitSegments(session);
  final signals = extractGaitSignalSegments(
    session,
    gaitSegments: gaitSegments,
  );
  final summary = computeSessionQualitySummary(
    session,
    userHeightCm: heightCm,
  );

  final out = stdout
    ..writeln(
      'gaitSegments=${gaitSegments.length} suitable=${signals.length} '
      'cadenceStatus=${summary.gaitCadence.status.name} '
      'cadenceReason=${summary.gaitCadence.reason} '
      'steps=${summary.gaitCadence.totalStepCount} '
      'cadence=${_number(summary.gaitCadence.averageCadenceStepsPerMinute)} '
      'confidence=${summary.gaitCadence.confidence.name} '
      'confidenceReason=${summary.gaitCadence.confidenceReason}',
    )
    ..writeln(
      'speedStatus=${summary.gaitWalkingSpeed.status.name} '
      'speedReason=${summary.gaitWalkingSpeed.reason} '
      'speed=${_number(summary.gaitWalkingSpeed.averageWalkingSpeedMs)} '
      'stepLength=${_number(summary.gaitWalkingSpeed.averageStepLengthM)}',
    );

  for (final segment in gaitSegments) {
    out.writeln(
      '  gait ${segment.startIndex}-${segment.endIndexExclusive} '
      'windows=${segment.windows} suitable=${segment.isSuitable} '
      'reason=${segment.qualityReason} '
      'sampleRange=${segment.analysisStartSampleIndex}-'
      '${segment.analysisEndSampleIndexExclusive}',
    );
  }

  for (final signal in signals) {
    final cadence = analyzeGaitCadence(signal);
    final speed = heightCm == null
        ? null
        : analyzeGaitWalkingSpeed(
            signal,
            cadenceResult: cadence,
            userHeightCm: heightCm,
          );
    final offsets = cadence.detectedStepOffsets.map(_duration).join(',');
    final temporal = computeGaitTemporalParameters(cadence);
    out
      ..writeln(
        '  signal samples=${signal.samples.length} '
        'range=${signal.startSampleIndex}-${signal.endSampleIndexExclusive} '
        'source=${signal.boundarySource?.name} empty=${signal.emptyReason}',
      )
      ..writeln(
        '    cadence status=${cadence.status.name} reason=${cadence.reason} '
        'steps=${cadence.stepCount} '
        'cadence=${_number(cadence.cadenceStepsPerMinute)} '
        'periodCadence=${_number(cadence.periodCadenceStepsPerMinute)} '
        'periodicity=${_number(cadence.periodicity)} '
        'threshold=${_number(cadence.adaptiveThreshold)} '
        'minPeakInterval=${cadence.minimumPeakInterval?.inMilliseconds}ms '
        'confidence=${cadence.confidence.name} '
        'confidenceReason=${cadence.confidenceReason}',
      )
      ..writeln(
        speed == null
            ? '    speed status=unavailable reason=missing_user_height '
                  '(pass --height=<cm>)'
            : '    speed status=${speed.status.name} reason=${speed.reason} '
                  'speed=${_number(speed.walkingSpeedMs)} '
                  'stepLength=${_number(speed.stepLengthM)} '
                  'verticalAmplitude=${_number(speed.verticalAmplitudeG)}',
      )
      ..writeln(_temporalLine(temporal))
      ..writeln('    offsets=$offsets');
  }
}

String _temporalLine(GaitTemporalParameters? temporal) {
  if (temporal == null) return '    temporal unavailable';
  return '    temporal stepMean=${_duration(temporal.meanStepTime)} '
      'stepCv=${_number(temporal.stepTimeCoefficientOfVariation)} '
      'strideCount=${temporal.strideIntervalCount} '
      'strideMean=${_durationOrNull(temporal.meanStrideTime)} '
      'strideCv=${_number(temporal.strideTimeCoefficientOfVariation)}';
}

Map<String, int> _counts(Iterable<String> labels) {
  final counts = <String, int>{};
  for (final label in labels) {
    counts[label] = (counts[label] ?? 0) + 1;
  }
  return counts;
}

String _duration(Duration duration) {
  return '${(duration.inMilliseconds / 1000).toStringAsFixed(3)}s';
}

String _durationOrNull(Duration? duration) {
  if (duration == null) return 'null';
  return _duration(duration);
}

String _number(num? value) {
  if (value == null) return 'null';
  return value.toStringAsFixed(4);
}
