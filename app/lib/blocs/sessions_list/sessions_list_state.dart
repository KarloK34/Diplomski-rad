import 'package:equatable/equatable.dart';
import 'package:gait_sense/utils/sessions_filter.dart';

/// How many additional sessions each "Prikaži još" tap reveals.
const int sessionsListPageSize = 5;

/// UI-only state for the Sessions tab's filterable, paginated history list.
///
/// Screen-scoped (unlike the shared `SessionsCubit` singleton) since the
/// active filters and reveal depth only matter for this one list.
class SessionsListState extends Equatable {
  /// Creates a sessions-list state.
  const SessionsListState({
    this.period = SessionsPeriodFilter.all,
    this.activity = SessionsActivityFilter.all,
    this.visibleCount = sessionsListPageSize,
  });

  /// The active period filter.
  final SessionsPeriodFilter period;

  /// The active activity filter.
  final SessionsActivityFilter activity;

  /// How many of the filtered sessions are currently revealed.
  final int visibleCount;

  /// Copies with selected fields replaced.
  SessionsListState copyWith({
    SessionsPeriodFilter? period,
    SessionsActivityFilter? activity,
    int? visibleCount,
  }) {
    return SessionsListState(
      period: period ?? this.period,
      activity: activity ?? this.activity,
      visibleCount: visibleCount ?? this.visibleCount,
    );
  }

  @override
  List<Object?> get props => [period, activity, visibleCount];
}
