import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gait_sense/blocs/pending_sessions/pending_sessions_cubit.dart';
import 'package:gait_sense/models/activity_prediction.dart';
import 'package:gait_sense/models/session_log.dart';
import 'package:gait_sense/repositories/session_log_repository.dart';

/// `PendingSessionsCubit` is a thin, local-only wrapper around
/// `SessionLogRepository.listPendingDrafts` — these tests cover that
/// `refresh` reflects the current state of `sessions/pending/` rather than
/// re-testing the repository's own file-handling behavior.
void main() {
  late Directory tempDir;
  late SessionLogRepository repository;
  late PendingSessionsCubit cubit;

  SessionLog session(DateTime startedAt) {
    return SessionLog(
      startedAt: startedAt,
      stoppedAt: startedAt.add(const Duration(seconds: 10)),
      modelInfo: const {
        'class_labels': ['wlk', 'sit'],
      },
      predictions: [
        ActivityPrediction(
          label: 'wlk',
          probabilities: const [0.05, 0.05, 0.6, 0.1, 0.1, 0.1],
          timestamp: startedAt,
          inferenceLatencyMs: 3,
        ),
      ],
    );
  }

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync(
      'pending_sessions_cubit_test',
    );
    repository = SessionLogRepository(documentsDirectory: () async => tempDir);
    cubit = PendingSessionsCubit(repository: repository);
    addTearDown(cubit.close);
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  test('starts empty before refresh is called', () {
    expect(cubit.state.sessions, isEmpty);
  });

  test('refresh populates state from drafts already on disk', () async {
    final log = session(DateTime.utc(2026));
    await repository.savePendingDraft(log);

    await cubit.refresh();

    expect(cubit.state.sessions, [log]);
  });

  test('refresh drops a session whose draft was since resolved', () async {
    final log = session(DateTime.utc(2026));
    await repository.savePendingDraft(log);
    await cubit.refresh();
    expect(cubit.state.sessions, [log]);

    await repository.deletePendingDraft(log);
    await cubit.refresh();

    expect(cubit.state.sessions, isEmpty);
  });
}
