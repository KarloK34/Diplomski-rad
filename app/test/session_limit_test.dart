import 'package:flutter_test/flutter_test.dart';
import 'package:gait_sense/services/session_limit.dart';

void main() {
  group('hasReachedSessionLimit', () {
    final startedAt = DateTime.utc(2026);

    test('is false before the configured deadline', () {
      expect(
        hasReachedSessionLimit(
          startedAt: startedAt,
          now: startedAt
              .add(defaultMaxSessionDuration)
              .subtract(
                const Duration(milliseconds: 1),
              ),
        ),
        isFalse,
      );
    });

    test('is true exactly at the configured deadline', () {
      expect(
        hasReachedSessionLimit(
          startedAt: startedAt,
          now: startedAt.add(defaultMaxSessionDuration),
        ),
        isTrue,
      );
    });

    test('is true after the configured deadline', () {
      expect(
        hasReachedSessionLimit(
          startedAt: startedAt,
          now: startedAt
              .add(defaultMaxSessionDuration)
              .add(
                const Duration(milliseconds: 1),
              ),
        ),
        isTrue,
      );
    });

    test('honors a custom maximum duration', () {
      expect(
        hasReachedSessionLimit(
          startedAt: startedAt,
          now: startedAt.add(const Duration(minutes: 5)),
          maxDuration: const Duration(minutes: 5),
        ),
        isTrue,
      );
    });

    test('rejects non-positive maximum durations', () {
      expect(
        () => hasReachedSessionLimit(
          startedAt: startedAt,
          now: startedAt,
          maxDuration: Duration.zero,
        ),
        throwsArgumentError,
      );
    });
  });
}
