import 'package:flutter_test/flutter_test.dart';
import 'package:gait_sense/services/latency_tracker.dart';

void main() {
  group('LatencyTracker', () {
    test('nearest-rank percentiles over two samples', () {
      final tracker = LatencyTracker()..add(2);
      final result = tracker.add(10);

      // Nearest-rank over [2, 10]: p50 -> ceil(0.5*2)=1 -> index 0 -> 2;
      // p95 -> ceil(0.95*2)=2 -> index 1 -> 10.
      expect(result.p50, 2);
      expect(result.p95, 10);
    });

    test('drops samples older than the window', () {
      final tracker = LatencyTracker(windowSize: 2)
        ..add(100)
        ..add(2);
      final result = tracker.add(10);

      // 100 fell out of the 2-sample window, so it can't dominate p95.
      expect(result.p95, 10);
    });

    test('reset clears the rolling window', () {
      final tracker = LatencyTracker()
        ..add(100)
        ..add(200)
        ..reset();

      final result = tracker.add(5);

      expect(result.p50, 5);
      expect(result.p95, 5);
    });
  });
}
