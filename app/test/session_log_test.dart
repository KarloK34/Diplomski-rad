import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gait_sense/models/activity_prediction.dart';
import 'package:gait_sense/models/session_log.dart';
import 'package:gait_sense/services/session_log_repository.dart';

/// Serialization round-trips and the file-writing path of the session log.
/// All host-runnable: the repository's documents directory is injected with a
/// temp dir so `path_provider`'s platform channel is never touched.
void main() {
  ActivityPrediction prediction(String label, int second) {
    return ActivityPrediction(
      label: label,
      probabilities: const [0.05, 0.05, 0.6, 0.1, 0.1, 0.1],
      timestamp: DateTime.utc(2026, 1, 1, 0, 0, second),
      inferenceLatencyMs: 3,
    );
  }

  group('ActivityPrediction JSON', () {
    test('round-trips losslessly', () {
      final original = prediction('wlk', 5);
      final decoded = ActivityPrediction.fromJson(
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
        predictions: [prediction('wlk', 1), prediction('sit', 2)],
      );
      final decoded = SessionLog.fromJson(
        jsonDecode(jsonEncode(log.toJson())) as Map<String, dynamic>,
      );
      expect(decoded, log);
    });
  });

  group('SessionLogRepository', () {
    test('writes a parseable session file to the injected directory', () async {
      final tempDir = Directory.systemTemp.createTempSync('gait_sense_test');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final repo = SessionLogRepository(
        documentsDirectory: () async => tempDir,
      )
        ..startSession(
          startedAt: DateTime.utc(2026, 1, 1, 12, 30, 45),
          modelInfo: const {
            'class_labels': ['wlk', 'sit'],
          },
        )
        ..append(prediction('wlk', 1))
        ..append(prediction('sit', 2));
      expect(repo.count, 2);

      final file = await repo.finishAndSave(
        stoppedAt: DateTime.utc(2026, 1, 1, 12, 35),
      );

      expect(file.existsSync(), isTrue);
      // Colons sanitized to `-` in the filename.
      expect(file.path, contains('session_2026-01-01T12-30-45'));

      final reloaded = SessionLog.fromJson(
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
      );
      expect(reloaded.predictions, hasLength(2));
      expect(reloaded.predictions.first.label, 'wlk');
      expect(reloaded.stoppedAt, DateTime.utc(2026, 1, 1, 12, 35));
      expect(repo.lastSession, isNotNull);
    });

    test('finishAndSave before startSession throws StateError', () {
      final repo = SessionLogRepository(
        documentsDirectory: () async => Directory.systemTemp,
      );
      expect(
        () => repo.finishAndSave(stoppedAt: DateTime.utc(2026)),
        throwsStateError,
      );
    });
  });
}
