import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/sessions/sessions_cubit.dart';
import 'package:gait_sense/blocs/sessions/sessions_state.dart';
import 'package:gait_sense/navigation/app_routes.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/widgets/widgets.dart';
import 'package:go_router/go_router.dart';

/// Session history and insights tab: a list of saved sessions plus
/// cross-session trend charts.
class SessionsScreen extends StatelessWidget {
  /// Creates the sessions screen.
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return BlocBuilder<SessionsCubit, SessionsState>(
      builder: (context, state) {
        final sessions = state.sessions;
        return ScreenBody(
          children: [
            const ScreenHeader(
              title: 'Sesije',
              subtitle: 'Povijest, trendovi i usporedba mjerenja',
            ),
            SizedBox(height: spacing.lg),
            if (state.status == SessionsStatus.error && sessions.isEmpty)
              EmptyStateCard(
                icon: Icons.cloud_off,
                iconColor: context.colors.error,
                title: 'Sesije nije moguće učitati',
                message: 'Provjerite internetsku vezu i pokušajte ponovno.',
                actionLabel: 'Pokušaj ponovno',
                actionIcon: Icons.refresh,
                onAction: () => context.read<SessionsCubit>().bind(),
              )
            else if (sessions.isEmpty)
              EmptyStateCard(
                icon: Icons.insights,
                title: 'Nema spremljenih sesija',
                message:
                    'Nakon snimanja ovdje će biti dostupni sažeci, '
                    'trendovi i usporedba mjerenja.',
                actionLabel: 'Snimi sesiju',
                actionIcon: Icons.fiber_manual_record,
                onAction: () => context.go(AppRoutes.record),
              )
            else ...[
              for (final record in sessions) ...[
                SessionListCard(
                  record: record,
                  onTap: () => context.push(AppRoutes.sessionDetail(record.id)),
                ),
                SizedBox(height: spacing.sm),
              ],
              SizedBox(height: spacing.md),
              SessionsTrends(sessions: sessions),
            ],
          ],
        );
      },
    );
  }
}
