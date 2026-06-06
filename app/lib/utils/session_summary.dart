import 'package:equatable/equatable.dart';
import 'package:gait_sense/models/session_log.dart';

/// Pure aggregation helpers for the session summary screen.
///
/// All functions here are platform-free so they can be unit-tested on the host
/// VM; the screen widget consumes their output and adds the display layer.

/// Aggregated time a single activity class occupied during a session.
class ClassTotal extends Equatable {
  /// Creates a class total.
  const ClassTotal({
    required this.label,
    required this.windows,
    required this.time,
    required this.fraction,
  });

  /// Model class code (e.g. `wlk`); map to a display name via the labels util.
  final String label;

  /// Number of prediction windows assigned to this class.
  final int windows;

  /// Estimated wall-clock time spent in this class.
  final Duration time;

  /// Share of the session's windows assigned to this class, in `[0, 1]`.
  final double fraction;

  @override
  List<Object?> get props => [label, windows, time, fraction];
}

/// One run of consecutive same-label prediction windows.
class TimelineSegment extends Equatable {
  /// Creates a timeline segment.
  const TimelineSegment({
    required this.label,
    required this.start,
    required this.end,
    required this.windows,
  });

  /// Model class code for the segment.
  final String label;

  /// Offset from session start at which this segment begins.
  final Duration start;

  /// Offset from session start at which this segment ends.
  final Duration end;

  /// Number of prediction windows collapsed into this segment.
  final int windows;

  @override
  List<Object?> get props => [label, start, end, windows];
}

/// Wall-clock duration of [session]: the stop time minus the start time, or —
/// while the session has no recorded stop time — the span up to the last
/// prediction. Returns [Duration.zero] for an empty session that never stopped,
/// and clamps any negative result to zero.
Duration sessionDuration(SessionLog session) {
  final predictions = session.predictions;
  final end =
      session.stoppedAt ??
      (predictions.isEmpty ? session.startedAt : predictions.last.timestamp);
  final span = end.difference(session.startedAt);
  return span.isNegative ? Duration.zero : span;
}

/// Per-class totals, sorted by occupied time descending (ties broken by class
/// code so the order is stable for a given input).
List<ClassTotal> computeClassTotals(SessionLog session) {
  final predictions = session.predictions;
  if (predictions.isEmpty) return const [];

  final counts = <String, int>{};
  for (final prediction in predictions) {
    counts[prediction.label] = (counts[prediction.label] ?? 0) + 1;
  }

  final total = predictions.length;
  final durationUs = sessionDuration(session).inMicroseconds;

  final totals =
      <ClassTotal>[
        for (final entry in counts.entries)
          ClassTotal(
            label: entry.key,
            windows: entry.value,
            fraction: entry.value / total,
            time: Duration(
              microseconds: (durationUs * entry.value / total).round(),
            ),
          ),
      ]..sort((a, b) {
        final byWindows = b.windows.compareTo(a.windows);
        return byWindows != 0 ? byWindows : a.label.compareTo(b.label);
      });
  return totals;
}

/// Collapses consecutive same-label predictions into [TimelineSegment]s.
List<TimelineSegment> computeTimeline(SessionLog session) {
  final predictions = session.predictions;
  if (predictions.isEmpty) return const [];

  final startedAt = session.startedAt;
  final duration = sessionDuration(session);

  Duration offsetAt(int index) {
    final span = predictions[index].timestamp.difference(startedAt);
    return span.isNegative ? Duration.zero : span;
  }

  final segments = <TimelineSegment>[];
  var runStart = 0;
  for (var i = 1; i <= predictions.length; i++) {
    final atEnd = i == predictions.length;
    if (!atEnd && predictions[i].label == predictions[runStart].label) {
      continue;
    }

    final start = runStart == 0 ? Duration.zero : offsetAt(runStart);
    var end = atEnd ? duration : offsetAt(i);
    if (end < start) end = start;

    segments.add(
      TimelineSegment(
        label: predictions[runStart].label,
        start: start,
        end: end,
        windows: i - runStart,
      ),
    );
    runStart = i;
  }
  return segments;
}

/// Croatian count agreement for the noun "prozor" (window).
String windowCountLabelHr(int count) {
  final ones = count % 10;
  final teens = count % 100;
  final noun = ones == 1 && teens != 11 ? 'prozor' : 'prozora';
  return '$count $noun';
}
