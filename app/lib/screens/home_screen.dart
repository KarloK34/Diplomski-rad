import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/pending_sessions/pending_sessions_cubit.dart';
import 'package:gait_sense/blocs/pending_sessions/pending_sessions_state.dart';
import 'package:gait_sense/blocs/sessions/sessions_cubit.dart';
import 'package:gait_sense/blocs/sessions/sessions_state.dart';
import 'package:gait_sense/navigation/app_routes.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/utils/gait_metric_info.dart';
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
            BlocBuilder<PendingSessionsCubit, PendingSessionsState>(
              builder: (context, pendingState) {
                final pending = pendingState.sessions;
                if (pending.isEmpty) return const SizedBox.shrink();

                // Only the most recent is offered at a time; resolving it
                // refreshes the cubit, which surfaces the next one if more
                // than one session was recovered.
                final latest = pending.reduce(
                  (a, b) => a.startedAt.isAfter(b.startedAt) ? a : b,
                );
                return Padding(
                  padding: EdgeInsets.only(bottom: spacing.md),
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
            ),
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
              MetricGrid(
                tiles: [
                  MetricTile(label: 'Sesije', value: '${sessions.length}'),
                  MetricTile(
                    label: 'Hodanje',
                    value: walking == Duration.zero
                        ? _dash
                        : formatWalkingDurationHr(walking),
                  ),
                  MetricTile(
                    label: 'Kadenca',
                    value: cadence == null
                        ? _dash
                        : formatCadenceValueHr(cadence),
                    info: cadenceMetricInfo,
                  ),
                  MetricTile(
                    label: 'Brzina',
                    value: speed == null
                        ? _dash
                        : formatWalkingSpeedValueHr(speed),
                    info: walkingSpeedMetricInfo,
                  ),
                ],
              ),
              SizedBox(height: spacing.md),
              InfoCard(
                title: 'Zadnja sesija',
                rows: [
                  LabeledRow(
                    label: 'Datum',
                    value: formatStartTimestamp(sessions.first.startedAt),
                  ),
                  LabeledRow(
                    label: 'Trajanje',
                    value: formatElapsedClock(sessions.first.duration),
                  ),
                  LabeledRow(
                    label: 'Predikcije',
                    value: '${sessions.first.predictionCount}',
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
