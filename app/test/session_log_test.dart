import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gait_sense/models/activity_prediction.dart';
import 'package:gait_sense/models/sensor_sample.dart';
import 'package:gait_sense/models/session_log.dart';
import 'package:gait_sense/repositories/session_log_repository.dart';

/// Serialization round-trips and the file-writing path of the session log.
/// All host-runnable: the repository's documents directory is injected with a
/// temp dir so `path_provider`'s platform channel is never touched.
void main() {
  ActivityPrediction prediction(
    String label,
    int second, {
    int? endSampleIndex,
  }) {
    return ActivityPrediction(
      label: label,
      probabilities: const [0.05, 0.05, 0.6, 0.1, 0.1, 0.1],
      timestamp: DateTime.utc(2026, 1, 1, 0, 0, second),
      endSampleIndex: endSampleIndex,
      inferenceLatencyMs: 3,
    );
  }

  SensorSample sample(int millisecond) {
    return SensorSample(
      timestamp: DateTime.utc(2026).add(Duration(milliseconds: millisecond)),
      gravityX: 0,
      gravityY: 0,
      gravityZ: 1,
      userAccelerationX: 0.01,
      userAccelerationY: 0.02,
      userAccelerationZ: 0.03,
      rotationRateX: 0.1,
      rotationRateY: 0.2,
      rotationRateZ: 0.3,
    );
  }

  group('ActivityPrediction JSON', () {
    test('round-trips losslessly', () {
      final original = prediction('wlk', 5, endSampleIndex: 127);
      final decoded = ActivityPrediction.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );
      expect(decoded, original);
      expect(decoded.endSampleIndex, 127);
    });

    test(
      'decodes older prediction JSON without rawLabel or endSampleIndex',
      () {
        final decoded = ActivityPrediction.fromJson({
          'label': 'wlk',
          'probabilities': const [0.05, 0.05, 0.6, 0.1, 0.1, 0.1],
          'timestamp': DateTime.utc(2026, 1, 1, 0, 0, 5).toIso8601String(),
          'inferenceLatencyMs': 3,
        });

        expect(decoded.label, 'wlk');
        expect(decoded.rawLabel, 'wlk');
        expect(decoded.endSampleIndex, isNull);
        expect(decoded.wasSmoothed, isFalse);
      },
    );
  });

  group('SensorSample JSON', () {
    test('round-trips losslessly', () {
      final original = sample(20);
      final decoded = SensorSample.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );
      expect(decoded, original);
    });
  });

  group('SessionLog JSON', () {
    test('round-trips losslessly, including a null stoppedAt', () {
      final log = SessionLog(
        startedAt: DateTime.utc(2026),
        stoppedAt: null,
        modelInfo: const {
          'channel_order': ['acc_mag', 'gyro_mag'],
          'class_labels': ['wlk', 'sit'],
        },
        rawSamples: [sample(20), sample(40)],
        predictions: [prediction('wlk', 1), prediction('sit', 2)],
      );
      final decoded = SessionLog.fromJson(
        jsonDecode(jsonEncode(log.toJson())) as Map<String, dynamic>,
      );
      expect(decoded, log);
    });

    test('decodes older logs without raw samples', () {
      final decoded = SessionLog.fromJson({
        'startedAt': DateTime.utc(2026).toIso8601String(),
        'stoppedAt': null,
        'deviceId': null,
        'modelInfo': const <String, dynamic>{},
        'predictions': const <Map<String, dynamic>>[],
      });

      expect(decoded.rawSamples, isEmpty);
    });
  });

  group('SessionLogRepository', () {
    test('writes a parseable session file to the injected directory', () async {
      final tempDir = Directory.systemTemp.createTempSync('gait_sense_test');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final repo =
          SessionLogRepository(
              documentsDirectory: () async => tempDir,
            )
            ..startSession(
              startedAt: DateTime.utc(2026, 1, 1, 12, 30, 45),
              modelInfo: const {
                'class_labels': ['wlk', 'sit'],
              },
            )
            ..append(prediction('wlk', 1))
            ..append(prediction('sit', 2))
            ..appendSample(sample(20))
            ..appendSample(sample(40));
      expect(repo.count, 2);
      expect(repo.sampleCount, 2);

      final session = repo.finish(
        stoppedAt: DateTime.utc(2026, 1, 1, 12, 35),
      );
      final file = await repo.saveToDisk(session);

      expect(file.existsSync(), isTrue);
      // Colons sanitized to `-` in the filename.
      expect(file.path, contains('session_2026-01-01T12-30-45'));

      final reloaded = SessionLog.fromJson(
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
      );
      expect(reloaded.predictions, hasLength(2));
      expect(reloaded.rawSamples, hasLength(2));
      expect(reloaded.rawSamples.first, sample(20));
      expect(reloaded.predictions.first.label, 'wlk');
      expect(reloaded.stoppedAt, DateTime.utc(2026, 1, 1, 12, 35));
    });

    test('finish before startSession throws StateError', () {
      final repo = SessionLogRepository(
        documentsDirectory: () async => Directory.systemTemp,
      );
      expect(
        () => repo.finish(stoppedAt: DateTime.utc(2026)),
        throwsStateError,
      );
    });
  });

  group('SessionLogRepository pending drafts', () {
    late Directory tempDir;
    late SessionLogRepository repo;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('gait_sense_pending_test');
      repo = SessionLogRepository(documentsDirectory: () async => tempDir);
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    SessionLog session(DateTime startedAt) {
      return SessionLog(
        startedAt: startedAt,
        stoppedAt: startedAt.add(const Duration(seconds: 10)),
        modelInfo: const {
          'class_labels': ['wlk', 'sit'],
        },
        rawSamples: [sample(20)],
        predictions: [prediction('wlk', 1)],
      );
    }

    test(
      'savePendingDraft writes a parseable file with no leftover .tmp',
      () async {
        final log = session(DateTime.utc(2026, 1, 1, 12, 30, 45));
        final file = await repo.savePendingDraft(log);

        expect(file.existsSync(), isTrue);
        expect(file.path, isNot(endsWith('.tmp')));
        expect(File('${file.path}.tmp').existsSync(), isFalse);

        final reloaded = SessionLog.fromJson(
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
        );
        expect(reloaded, log);
      },
    );

    test(
      'listPendingDrafts recovers every draft written by savePendingDraft',
      () async {
        final first = session(DateTime.utc(2026));
        final second = session(DateTime.utc(2026, 1, 2));
        await repo.savePendingDraft(first);
        await repo.savePendingDraft(second);

        final drafts = await repo.listPendingDrafts();

        expect(drafts, unorderedEquals([first, second]));
      },
    );

    test(
      'listPendingDrafts deletes a draft that fails to parse instead of '
      'surfacing it',
      () async {
        final pendingDir = Directory('${tempDir.path}/sessions/pending')
          ..createSync(recursive: true);
        final corrupt = File('${pendingDir.path}/session_corrupt.json')
          ..writeAsStringSync('{"startedAt": "not valid json'); // truncated

        final drafts = await repo.listPendingDrafts();

        expect(drafts, isEmpty);
        expect(corrupt.existsSync(), isFalse);
      },
    );

    test('deletePendingDraft removes the matching draft', () async {
      final log = session(DateTime.utc(2026));
      final file = await repo.savePendingDraft(log);

      await repo.deletePendingDraft(log);

      expect(file.existsSync(), isFalse);
    });

    test('deletePendingDraft is a no-op when no draft exists', () async {
      final log = session(DateTime.utc(2026));
      await expectLater(repo.deletePendingDraft(log), completes);
    });

    test(
      'listPendingDrafts returns an empty list before any draft exists',
      () async {
        expect(await repo.listPendingDrafts(), isEmpty);
      },
    );
  });
}
