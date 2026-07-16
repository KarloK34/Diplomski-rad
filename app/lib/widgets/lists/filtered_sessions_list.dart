import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/sessions_list/sessions_list_cubit.dart';
import 'package:gait_sense/blocs/sessions_list/sessions_list_state.dart';
import 'package:gait_sense/models/session_summary_record.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/utils/sessions_filter.dart';
import 'package:gait_sense/widgets/cards/empty_state_card.dart';
import 'package:gait_sense/widgets/cards/session_list_card.dart';
import 'package:gait_sense/widgets/lists/sessions_filter_bar.dart';
import 'package:gait_sense/widgets/lists/show_more_footer.dart';

/// Filterable, incrementally paginated list of saved sessions.
///
/// Reads a screen-scoped [SessionsListCubit] (filter + reveal depth) and
/// renders a slice of [sessions] — the shared `SessionsCubit`'s full,
/// already-loaded history — so filtering/paging never re-fetches anything.
class FilteredSessionsList extends StatelessWidget {
  /// Creates the list for the given full, unfiltered [sessions] history and
  /// an [onSessionTap] callback for opening a session's detail view.
  const FilteredSessionsList({
    required this.sessions,
    required this.onSessionTap,
    super.key,
  });

  /// The full, unfiltered session history, newest first.
  final List<SessionSummaryRecord> sessions;

  /// Called with the tapped session's id.
  final ValueChanged<String> onSessionTap;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return BlocBuilder<SessionsListCubit, SessionsListState>(
      builder: (context, listState) {
        final cubit = context.read<SessionsListCubit>();
        final filtered = filterSessions(
          sessions,
          period: listState.period,
          activity: listState.activity,
        );
        final visible = filtered.take(listState.visibleCount).toList();
        final hiddenCount = filtered.length - visible.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SessionsFilterBar(
              period: listState.period,
              activity: listState.activity,
              onPeriodSelected: cubit.setPeriodFilter,
              onActivitySelected: cubit.setActivityFilter,
            ),
            SizedBox(height: spacing.md),
            if (filtered.isEmpty)
              const EmptyStateCard(
                icon: Icons.filter_alt_off,
                title: 'Nema sesija za odabrani filtar',
                message: 'Odaberite drugi filtar ili "Sve" za cijelu povijest.',
              )
            else ...[
              for (final record in visible) ...[
                SessionListCard(
                  record: record,
                  onTap: () => onSessionTap(record.id),
                ),
                SizedBox(height: spacing.sm),
              ],
              ShowMoreFooter(
                hiddenCount: hiddenCount,
                canShowLess: listState.visibleCount > sessionsListPageSize,
                pageSize: sessionsListPageSize,
                onShowMore: cubit.showMore,
                onShowLess: cubit.showLess,
              ),
            ],
          ],
        );
      },
    );
  }
}
