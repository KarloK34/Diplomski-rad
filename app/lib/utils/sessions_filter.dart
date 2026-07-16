import 'package:gait_sense/models/session_summary_record.dart';
import 'package:gait_sense/utils/activity_labels.dart';

/// How the Sessions tab's history list is narrowed by recording date.
///
/// Independent of [SessionsActivityFilter] — the two combine with an
/// implicit AND, each single-select within its own facet, so the user never
/// needs to reason about cross-facet AND/OR rules.
enum SessionsPeriodFilter {
  /// No date narrowing.
  all,

  /// Sessions started since the current week began (Monday 00:00, local
  /// time).
  thisWeek,

  /// Sessions started since the first day of the current month.
  thisMonth,

  /// Sessions started since the first day of the current year.
  thisYear,
}

/// Croatian labels for [SessionsPeriodFilter], in the order they should be
/// offered to the user.
const Map<SessionsPeriodFilter, String> sessionsPeriodFilterLabelsHr = {
  SessionsPeriodFilter.all: 'Sve',
  SessionsPeriodFilter.thisWeek: 'Ovaj tjedan',
  SessionsPeriodFilter.thisMonth: 'Ovaj mjesec',
  SessionsPeriodFilter.thisYear: 'Ova godina',
};

/// How the Sessions tab's history list is narrowed by dominant activity (the
/// first, largest-share entry in [SessionSummaryRecord.classTotals]).
enum SessionsActivityFilter {
  /// No activity narrowing.
  all,

  /// Dominant activity is walking (`wlk`).
  walking,

  /// Dominant activity is jogging (`jog`).
  jogging,

  /// Dominant activity is walking upstairs (`ups`).
  stairsUp,

  /// Dominant activity is walking downstairs (`dws`).
  stairsDown,

  /// Dominant activity is standing or sitting, merged via
  /// [displayActivityCode] the same way the rest of the app collapses them.
  resting,
}

/// Croatian labels for [SessionsActivityFilter], in the order they should be
/// offered to the user.
const Map<SessionsActivityFilter, String> sessionsActivityFilterLabelsHr = {
  SessionsActivityFilter.all: 'Sve',
  SessionsActivityFilter.walking: 'Hodanje',
  SessionsActivityFilter.jogging: 'Trčanje',
  SessionsActivityFilter.stairsUp: 'Uz stepenice',
  SessionsActivityFilter.stairsDown: 'Niz stepenice',
  SessionsActivityFilter.resting: 'Mirovanje',
};

/// The [displayActivityCode] each non-[SessionsActivityFilter.all] value
/// matches a session's dominant activity against.
const Map<SessionsActivityFilter, String> _activityFilterCodes = {
  SessionsActivityFilter.walking: 'wlk',
  SessionsActivityFilter.jogging: 'jog',
  SessionsActivityFilter.stairsUp: 'ups',
  SessionsActivityFilter.stairsDown: 'dws',
  SessionsActivityFilter.resting: restingActivityCode,
};

/// Returns [sessions] narrowed to [period] and [activity] (combined with an
/// implicit AND), preserving input order (the cubit that owns [sessions]
/// already emits newest-first).
///
/// [now] pins the reference instant for the date-range filters; pass it
/// explicitly in tests for a deterministic result. Defaults to the current
/// local time.
List<SessionSummaryRecord> filterSessions(
  List<SessionSummaryRecord> sessions, {
  SessionsPeriodFilter period = SessionsPeriodFilter.all,
  SessionsActivityFilter activity = SessionsActivityFilter.all,
  DateTime? now,
}) {
  final byPeriod = _filterByPeriod(sessions, period, now ?? DateTime.now());
  return _filterByActivity(byPeriod, activity);
}

List<SessionSummaryRecord> _filterByPeriod(
  List<SessionSummaryRecord> sessions,
  SessionsPeriodFilter period,
  DateTime now,
) {
  switch (period) {
    case SessionsPeriodFilter.all:
      return sessions;
    case SessionsPeriodFilter.thisWeek:
      return _startedOnOrAfter(sessions, _startOfWeek(now));
    case SessionsPeriodFilter.thisMonth:
      return _startedOnOrAfter(sessions, DateTime(now.year, now.month));
    case SessionsPeriodFilter.thisYear:
      return _startedOnOrAfter(sessions, DateTime(now.year));
  }
}

List<SessionSummaryRecord> _filterByActivity(
  List<SessionSummaryRecord> sessions,
  SessionsActivityFilter activity,
) {
  if (activity == SessionsActivityFilter.all) return sessions;
  final code = _activityFilterCodes[activity]!;
  return [
    for (final session in sessions)
      if (session.classTotals.isNotEmpty &&
          displayActivityCode(session.classTotals.first.label) == code)
        session,
  ];
}

List<SessionSummaryRecord> _startedOnOrAfter(
  List<SessionSummaryRecord> sessions,
  DateTime start,
) {
  return [
    for (final session in sessions)
      if (!session.startedAt.isBefore(start)) session,
  ];
}

/// Midnight on the Monday of the week containing [today].
DateTime _startOfWeek(DateTime today) {
  final midnight = DateTime(today.year, today.month, today.day);
  return midnight.subtract(Duration(days: midnight.weekday - 1));
}
