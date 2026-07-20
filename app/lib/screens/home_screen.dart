import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/sessions/sessions_cubit.dart';
import 'package:gait_sense/blocs/sessions/sessions_state.dart';
import 'package:gait_sense/navigation/app_routes.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/utils/session_summary_format.dart';
import 'package:gait_sense/widgets/widgets.dart';
import 'package:go_router/go_router.dart';

/// Dashboard tab: quick stats and a snapshot of the most recent session,
/// driven by the account's saved sessions.
class HomeScreen extends StatelessWidget {
  /// Creates the dashboard screen.
  const HomeScreen({super.key});

  static const String _dash = '–';

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return BlocBuilder<SessionsCubit, SessionsState>(
      builder: (context, state) {
        final sessions = state.sessions;
        final walking = state.aggregates.totalWalkingTime;
        final cadence = state.aggregates.averageCadenceStepsPerMinute;
        final speed = state.aggregates.averageWalkingSpeedMs;

        return ScreenBody(
          children: [
            const ScreenHeader(
              title: 'Gait Sense',
              subtitle: 'Pregled stanja i zadnjih mjerenja',
            ),
            SizedBox(height: spacing.lg),
            const PendingSessionCard(),
            ActionCard(
              icon: Icons.directions_walk,
              title: 'Nova sesija',
              subtitle:
                  'Snimi novu sesiju za analizu aktivnosti i '
                  'parametara hoda.',
              actionLabel: 'Započni',
              onPressed: () => context.go(AppRoutes.record),
            ),
            SizedBox(height: spacing.md),
            if (state.status == SessionsStatus.error && sessions.isEmpty)
              EmptyStateCard(
                icon: Icons.cloud_off,
                iconColor: context.colors.error,
                title: 'Podatke nije moguće učitati',
                message: 'Provjerite internetsku vezu i pokušajte ponovno.',
                actionLabel: 'Pokušaj ponovno',
                actionIcon: Icons.refresh,
                onAction: () => context.read<SessionsCubit>().bind(),
              )
            else if (sessions.isEmpty)
              const EmptyStateCard(
                icon: Icons.insights,
                title: 'Nema spremljenih sesija',
                message:
                    'Nakon prve snimljene sesije ovdje će biti dostupni '
                    'pregled i statistika.',
              )
            else ...[
              LastSessionCard(
                session: sessions.first,
                onTap: () => context.push(
                  AppRoutes.sessionDetail(sessions.first.id),
                ),
              ),
              SizedBox(height: spacing.md),
              Text('Ukupna statistika', style: context.textStyles.titleLarge),
              SizedBox(height: spacing.md),
              MetricGrid(
                tiles: [
                  MetricTile(
                    label: 'Ukupan broj sesija',
                    value: '${sessions.length}',
                  ),
                  MetricTile(
                    label: 'Ukupno vrijeme hoda',
                    value: walking == Duration.zero
                        ? _dash
                        : formatWalkingDurationHr(walking),
                  ),
                  MetricTile(
                    label: 'Prosj. kadenca',
                    value: cadence == null
                        ? _dash
                        : formatCadenceValueHr(cadence),
                  ),
                  MetricTile(
                    label: 'Prosj. brzina',
                    value: speed == null
                        ? _dash
                        : formatWalkingSpeedValueHr(speed),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
