import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/sessions_list/sessions_list_state.dart';
import 'package:gait_sense/utils/sessions_filter.dart';

/// Drives the Sessions tab's active period/activity filters and reveal
/// depth.
///
/// The filtered/paginated sessions themselves are derived by the widget
/// layer from the shared `SessionsCubit`'s list — this cubit only owns UI
/// state, not data, so it stays screen-scoped and disposable per visit.
class SessionsListCubit extends Cubit<SessionsListState> {
  /// Creates a sessions-list cubit at the default filters and page size.
  SessionsListCubit() : super(const SessionsListState());

  /// Switches the period facet to [period], leaving the activity facet
  /// untouched, and resets the reveal depth back to one page — otherwise a
  /// "show more" depth built up under one filter would leak into an
  /// unrelated one.
  void setPeriodFilter(SessionsPeriodFilter period) {
    if (period == state.period) return;
    emit(SessionsListState(period: period, activity: state.activity));
  }

  /// Switches the activity facet to [activity], leaving the period facet
  /// untouched, and resets the reveal depth back to one page.
  void setActivityFilter(SessionsActivityFilter activity) {
    if (activity == state.activity) return;
    emit(SessionsListState(period: state.period, activity: activity));
  }

  /// Reveals one more page of sessions under the active filters.
  void showMore() {
    emit(
      state.copyWith(visibleCount: state.visibleCount + sessionsListPageSize),
    );
  }

  /// Collapses back to the first page.
  void showLess() {
    emit(state.copyWith(visibleCount: sessionsListPageSize));
  }
}
