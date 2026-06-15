import 'package:flutter_test/flutter_test.dart';
import 'package:gait_sense/models/activity_prediction.dart';
import 'package:gait_sense/services/activity_smoother.dart';

void main() {
  ActivityPrediction prediction(String label, int second) {
    return ActivityPrediction(
      label: label,
      rawLabel: label,
      probabilities: const [0.05, 0.05, 0.7, 0.05, 0.1, 0.05],
      timestamp: DateTime.utc(2026, 1, 1, 0, 0, second),
      inferenceLatencyMs: 4,
    );
  }

  test('smooths an isolated raw-label spike inside a walking run', () {
    final smoother = ActivitySmoother();
    final inputs = [
      prediction('wlk', 1),
      prediction('wlk', 2),
      prediction('ups', 3),
      prediction('wlk', 4),
      prediction('wlk', 5),
    ];

    final outputs = [for (final input in inputs) smoother.add(input)];

    expect(outputs.map((p) => p.label).toList(), [
      'wlk',
      'wlk',
      'wlk',
      'wlk',
      'wlk',
    ]);
    expect(outputs[2].rawLabel, 'ups');
    expect(outputs[2].wasSmoothed, isTrue);
  });

  test('keeps fallback raw label when the rolling context is tied', () {
    final smoother = ActivitySmoother();

    final first = smoother.add(prediction('wlk', 1));
    final second = smoother.add(prediction('ups', 2));

    expect(first.label, 'wlk');
    expect(second.label, 'ups');
    expect(second.wasSmoothed, isFalse);
  });

  test('reset clears history between sessions', () {
    final smoother = ActivitySmoother()
      ..add(prediction('wlk', 1))
      ..add(prediction('wlk', 2))
      ..reset();
    final afterReset = smoother.add(prediction('ups', 3));

    expect(afterReset.label, 'ups');
    expect(afterReset.rawLabel, 'ups');
  });
}
