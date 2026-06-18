import 'package:flutter_test/flutter_test.dart';
import 'package:gait_sense/models/activity_prediction.dart';
import 'package:gait_sense/models/sensor_sample.dart';
import 'package:gait_sense/models/session_log.dart';
import 'package:gait_sense/utils/gait_segments.dart';
import 'package:gait_sense/utils/gait_signal_segments.dart';

void main() {
  final start = DateTime.utc(2026, 1, 1, 12);

  ActivityPrediction predictionAt(
    String label,
    int millisecondsAfterStart, {
    int? endSampleIndex,
  }) {
    return ActivityPrediction(
      label: label,
      probabilities: const [0.1, 0.1, 0.5, 0.1, 0.1, 0.1],
      timestamp: start.add(Duration(milliseconds: millisecondsAfterStart)),
      endSampleIndex: endSampleIndex,
      inferenceLatencyMs: 10,
    );
  }

  SensorSample sample(int index) {
    return SensorSample(
      timestamp: start.add(Duration(milliseconds: index * 20)),
      gravityX: 0,
      gravityY: 0,
      gravityZ: 1,
      userAccelerationX: index.toDouble(),
      userAccelerationY: 0,
      userAccelerationZ: 0,
      rotationRateX: 0,
      rotationRateY: 0,
      rotationRateZ: 0,
    );
  }

  SessionLog session({
    required List<ActivityPrediction> predictions,
    List<SensorSample> rawSamples = const [],
  }) {
    return SessionLog(
      startedAt: start,
      stoppedAt: start.add(const Duration(seconds: 10)),
      modelInfo: const {},
      rawSamples: rawSamples,
      predictions: predictions,
    );
  }

  test('cuts the raw signal with half-open sample-index bounds', () {
    final rawSamples = [for (var i = 0; i < 220; i++) sample(i)];
    final log = session(
      rawSamples: rawSamples,
      predictions: [
        predictionAt('wlk', 2560, endSampleIndex: 127),
        predictionAt('wlk', 3840, endSampleIndex: 191),
      ],
    );
    final gaitSegments = extractGaitSegments(log, minWindows: 2);

    final signal = extractGaitSignalSegments(
      log,
      gaitSegments: gaitSegments,
    ).single;

    expect(signal.boundarySource, GaitSignalSegmentBoundarySource.sampleIndex);
    expect(signal.startSampleIndex, 0);
    expect(signal.endSampleIndexExclusive, 192);
    expect(signal.samples, rawSamples.sublist(0, 192));
    expect(signal.emptyReason, isNull);
  });

  test(
    'falls back to timestamp offsets when prediction indices are missing',
    () {
      final rawSamples = [for (var i = 0; i < 80; i++) sample(i)];
      final log = session(
        rawSamples: rawSamples,
        predictions: [
          predictionAt('wlk', 200),
          predictionAt('wlk', 400),
        ],
      );
      final gaitSegments = extractGaitSegments(log, minWindows: 2);

      final signal = extractGaitSignalSegments(
        log,
        gaitSegments: gaitSegments,
      ).single;

      expect(
        signal.boundarySource,
        GaitSignalSegmentBoundarySource.timestampOffset,
      );
      expect(signal.startSampleIndex, 10);
      expect(signal.endSampleIndexExclusive, 30);
      expect(signal.samples, rawSamples.sublist(10, 30));
    },
  );

  test(
    'does not throw for older logs without raw samples or sample indices',
    () {
      final log = SessionLog.fromJson({
        'startedAt': start.toIso8601String(),
        'stoppedAt': start.add(const Duration(seconds: 1)).toIso8601String(),
        'deviceId': null,
        'modelInfo': const <String, dynamic>{},
        'predictions': [
          {
            'label': 'wlk',
            'probabilities': const [0.1, 0.1, 0.5, 0.1, 0.1, 0.1],
            'timestamp': start
                .add(const Duration(milliseconds: 200))
                .toIso8601String(),
            'inferenceLatencyMs': 10,
          },
          {
            'label': 'wlk',
            'probabilities': const [0.1, 0.1, 0.5, 0.1, 0.1, 0.1],
            'timestamp': start
                .add(const Duration(milliseconds: 400))
                .toIso8601String(),
            'inferenceLatencyMs': 10,
          },
        ],
      });
      final gaitSegments = extractGaitSegments(log, minWindows: 2);

      final signal = extractGaitSignalSegments(
        log,
        gaitSegments: gaitSegments,
      ).single;

      expect(signal.samples, isEmpty);
      expect(signal.emptyReason, missingRawSamplesReason);
    },
  );
}
