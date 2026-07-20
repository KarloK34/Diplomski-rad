import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/sessions/sessions_cubit.dart';
import 'package:gait_sense/blocs/sessions/sessions_state.dart';
import 'package:gait_sense/models/session_summary_record.dart';
import 'package:gait_sense/screens/session_detail/session_detail_content.dart';
import 'package:gait_sense/screens/session_summary/session_summary_loading_view.dart';

/// Resolves a saved session by id from the shared [SessionsCubit] and shows its
/// detail view. Reading from the already-loaded list means no extra fetch.
class SessionDetailScreen extends StatelessWidget {
  /// Creates the detail screen for the session started at [sessionId]
  /// (its ISO-8601 start time, which is the Firestore document id).
  const SessionDetailScreen({required this.sessionId, super.key});

  /// The `startedAt` ISO-8601 string identifying the session.
  final String sessionId;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      SessionsCubit,
      SessionsState,
      (SessionsStatus, SessionSummaryRecord?)
    >(
      selector: (state) {
        final matches = state.sessions.where(
          (session) => session.id == sessionId,
        );
        return (state.status, matches.isEmpty ? null : matches.first);
      },
      builder: (context, selected) {
        final (status, record) = selected;
        if (record != null) return SessionDetailContent(record: record);
        // Not found yet: still loading, or the session was deleted/never synced
        // to this account.
        final isLoading =
            status == SessionsStatus.loading ||
            status == SessionsStatus.initial;
        if (isLoading) return const SessionSummaryLoadingView();
        return Scaffold(
          appBar: AppBar(title: const Text('Sesija')),
          body: const Center(child: Text('Sesija nije pronađena.')),
        );
      },
    );
  }
}
