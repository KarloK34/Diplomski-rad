import 'dart:math' as math;

/// Arithmetic mean of [values], or 0 for an empty list.
double mean(List<double> values) {
  if (values.isEmpty) return 0;
  return values.reduce((a, b) => a + b) / values.length;
}

/// Population standard deviation of [values] around the given [mean].
double standardDeviation(List<double> values, double mean) {
  if (values.isEmpty) return 0;
  final variance =
      values
          .map((value) => math.pow(value - mean, 2).toDouble())
          .reduce((a, b) => a + b) /
      values.length;
  return math.sqrt(variance);
}

/// Median of [values].
///
/// Callers must pass a non-empty list; an empty list indexes out of range.
double median(List<double> values) {
  final sorted = List<double>.of(values)..sort();
  final middle = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[middle]
      : (sorted[middle - 1] + sorted[middle]) / 2;
}
