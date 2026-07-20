import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/pending_sessions/pending_sessions_cubit.dart';
import 'package:gait_sense/blocs/pending_sessions/pending_sessions_state.dart';
import 'package:gait_sense/navigation/app_routes.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/utils/session_summary_format.dart';
import 'package:gait_sense/widgets/cards/action_card.dart';
import 'package:go_router/go_router.dart';

/// Banner offering to review the most recently recovered unsaved session.
///
/// Reads [PendingSessionsCubit] directly and renders nothing when there is
/// no pending session. Only the most recent is offered at a time; resolving
/// it refreshes the cubit, which surfaces the next one if more than one
/// session was recovered.
class PendingSessionCard extends StatelessWidget {
  /// Creates the pending-session recovery banner.
  const PendingSessionCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PendingSessionsCubit, PendingSessionsState>(
      builder: (context, state) {
        final pending = state.sessions;
        if (pending.isEmpty) return const SizedBox.shrink();

        final latest = pending.reduce(
          (a, b) => a.startedAt.isAfter(b.startedAt) ? a : b,
        );
        return Padding(
          padding: EdgeInsets.only(bottom: context.spacing.md),
          child: ActionCard(
            icon: Icons.history_toggle_off,
            iconColor: context.colors.error,
            title: 'Nespremljena sesija',
            subtitle: pending.length > 1
                ? '${pending.length} sesije nisu spremljene prije '
                      'zatvaranja aplikacije.'
                : 'Sesija od ${formatStartTimestamp(latest.startedAt)} '
                      'nije spremljena prije zatvaranja aplikacije.',
            actionLabel: 'Pregledaj',
            onPressed: () => context.push(
              AppRoutes.recordRecoveredSummary,
              extra: latest,
            ),
          ),
        );
      },
    );
  }
}
