import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gait_sense/app.dart';
import 'package:gait_sense/models/activity_prediction.dart';
import 'package:gait_sense/models/sensor_sample.dart';
import 'package:gait_sense/models/session_log.dart';
import 'package:gait_sense/screens/session_summary_screen.dart';

void main() {
  testWidgets('app renders the live HAR screen with a Start control', (
    tester,
  ) async {
    await tester.pumpWidget(const GaitSenseApp());
    expect(find.text('Live HAR'), findsOneWidget);
    expect(find.text('Zaustavljeno'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
  });

  testWidgets('session summary shows experimental cadence when computed', (
    tester,
  ) async {
    final start = DateTime.utc(2026, 1, 1, 12);

    SensorSample sampleAt(int index) {
      return SensorSample(
        timestamp: start.add(Duration(milliseconds: index * 20)),
        gravityX: 0,
        gravityY: 0,
        gravityZ: 1,
        userAccelerationX: 0,
        userAccelerationY: 0,
        userAccelerationZ:
            0.06 + 0.08 * (1 + math.sin(2 * math.pi * 2 * index * 0.02)) / 2,
        rotationRateX: 0,
        rotationRateY: 0,
        rotationRateZ: 0,
      );
    }

    ActivityPrediction predictionAt(int secondsAfterStart, int endIndex) {
      return ActivityPrediction(
        label: 'wlk',
        probabilities: const [0.1, 0.1, 0.5, 0.1, 0.1, 0.1],
        timestamp: start.add(Duration(seconds: secondsAfterStart)),
        endSampleIndex: endIndex,
        inferenceLatencyMs: 10,
      );
    }

    final session = SessionLog(
      startedAt: start,
      stoppedAt: start.add(const Duration(seconds: 10)),
      modelInfo: const {},
      rawSamples: [for (var i = 0; i < 500; i++) sampleAt(i)],
      predictions: [
        predictionAt(3, 177),
        predictionAt(4, 241),
        predictionAt(5, 305),
        predictionAt(6, 369),
        predictionAt(8, 433),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: SessionSummaryScreen(session: session)),
    );

    expect(find.text('Kadenca (eksperimentalno)'), findsOneWidget);
    expect(find.textContaining('koraka/min'), findsOneWidget);
    expect(
      find.text('Detektirani koraci (eksperimentalno)'),
      findsOneWidget,
    );
    expect(find.text('Pouzdanost procjene'), findsOneWidget);
    expect(find.text('Visoka'), findsOneWidget);
    expect(find.text('Razlog'), findsNothing);
  });

  testWidgets(
    'session summary marks step count unavailable when not computed',
    (
      tester,
    ) async {
      final start = DateTime.utc(2026, 1, 1, 12);

      ActivityPrediction predictionAt(int secondsAfterStart) {
        return ActivityPrediction(
          label: 'wlk',
          probabilities: const [0.1, 0.1, 0.5, 0.1, 0.1, 0.1],
          timestamp: start.add(Duration(seconds: secondsAfterStart)),
          inferenceLatencyMs: 10,
        );
      }

      final session = SessionLog(
        startedAt: start,
        stoppedAt: start.add(const Duration(seconds: 8)),
        modelInfo: const {},
        predictions: [
          for (var second = 3; second <= 7; second++) predictionAt(second),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(home: SessionSummaryScreen(session: session)),
      );

      expect(
        find.text('Detektirani koraci (eksperimentalno)'),
        findsOneWidget,
      );
      expect(find.text('Nije dostupno'), findsOneWidget);
      expect(find.text('Razlog'), findsOneWidget);
    },
  );
}
