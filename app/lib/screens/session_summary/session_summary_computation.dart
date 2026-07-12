import 'package:gait_sense/models/session_log.dart';
import 'package:gait_sense/utils/session_summary.dart';

/// Input bundle passed to the worker isolate via `compute`.
///
/// `compute` accepts a single SendPort-serialisable argument, so the session
/// and optional user height are bundled here.
class SessionSummaryInput {
  /// Creates the isolate input for [session].
  const SessionSummaryInput({required this.session, this.userHeightCm});

  /// The finished session to summarize.
  final SessionLog session;

  /// User body height, if set, for the walking-speed estimate.
  final double? userHeightCm;
}

/// Aggregated summary data computed off the UI isolate.
class SessionSummaryData {
  /// Creates the isolate output bundle.
  const SessionSummaryData({
    required this.totals,
    required this.timeline,
    required this.quality,
  });

  /// Per-class time totals.
  final List<ClassTotal> totals;

  /// Collapsed activity timeline.
  final List<TimelineSegment> timeline;

  /// Session quality and gait-analysis metrics.
  final SessionQualitySummary quality;
}

/// Entry point for `compute`. Must be a top-level function.
SessionSummaryData computeSessionSummaryData(SessionSummaryInput input) {
  return SessionSummaryData(
    totals: computeClassTotals(input.session),
    timeline: computeTimeline(input.session),
    quality: computeSessionQualitySummary(
      input.session,
      userHeightCm: input.userHeightCm,
    ),
  );
}
