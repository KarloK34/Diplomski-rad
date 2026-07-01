import 'dart:convert';
import 'dart:io';

import 'package:gait_sense/models/session_log.dart';
import 'package:gait_sense/utils/gait_cadence.dart';
import 'package:gait_sense/utils/gait_segments.dart';
import 'package:gait_sense/utils/gait_signal_segments.dart';
import 'package:gait_sense/utils/gait_walking_speed.dart';
import 'package:gait_sense/utils/session_summary.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/diagnose_gait_sessions.dart <json>...',
    );
    exitCode = 64;
    return;
  }

  for (final path in args) {
    final file = File(path);
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final session = SessionLog.fromJson(json);

    stdout
      ..writeln()
      ..writeln('== ${file.uri.pathSegments.last} ==');
    _printSession(session);
    _printRuns(session);
    _printGait(session);
  }
}

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

void _printRuns(SessionLog session) {
  final summary = computeSessionQualitySummary(
    session,
    userHeightCm: 180,
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

void _printGait(SessionLog session) {
  final gaitSegments = extractGaitSegments(session);
  final signals = extractGaitSignalSegments(
    session,
    gaitSegments: gaitSegments,
  );
  final summary = computeSessionQualitySummary(
    session,
    userHeightCm: 180,
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
    final speed = analyzeGaitWalkingSpeed(
      signal,
      cadenceResult: cadence,
      userHeightCm: 180,
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
        '    speed status=${speed.status.name} reason=${speed.reason} '
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
