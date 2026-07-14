/// Rolling inference-latency percentiles for a recording session.
///
/// Bounded to [windowSize] samples so a recent regression isn't hidden by a
/// session-cumulative average.
class LatencyTracker {
  /// Creates a tracker over the most recent [windowSize] samples.
  LatencyTracker({this.windowSize = 60})
    : assert(windowSize > 0, 'windowSize must be positive');

  /// Number of recent samples kept in the rolling window.
  final int windowSize;

  final List<int> _samples = [];

  /// Clears the rolling window for a fresh recording session.
  void reset() => _samples.clear();

  /// Adds one inference-latency sample, in milliseconds, and returns the
  /// recomputed rolling median (p50) and 95th-percentile (p95).
  ({int p50, int p95}) add(int latencyMs) {
    _samples.add(latencyMs);
    if (_samples.length > windowSize) {
      _samples.removeRange(0, _samples.length - windowSize);
    }

    final sorted = List<int>.of(_samples)..sort();
    return (p50: _percentile(sorted, 50), p95: _percentile(sorted, 95));
  }

  /// Nearest-rank percentile (Hyndman & Fan, 1996, Definition 1,
  /// https://doi.org/10.2307/2684934) — no interpolation, since latency is
  /// reported in integer milliseconds.
  static int _percentile(List<int> sortedAscending, double p) {
    if (sortedAscending.isEmpty) return 0;
    final rank = (p / 100 * sortedAscending.length).ceil();
    var index = rank - 1;
    if (index < 0) index = 0;
    if (index > sortedAscending.length - 1) index = sortedAscending.length - 1;
    return sortedAscending[index];
  }
}
