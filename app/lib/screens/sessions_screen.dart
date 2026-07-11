import 'package:flutter/material.dart';
import 'package:gait_sense/navigation/app_routes.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/widgets/widgets.dart';
import 'package:go_router/go_router.dart';

/// Session history and insights tab.
class SessionsScreen extends StatelessWidget {
  /// Creates the sessions screen.
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return ScreenBody(
      children: [
        const ScreenHeader(
          title: 'Sesije',
          subtitle: 'Povijest, trendovi i usporedba mjerenja',
        ),
        SizedBox(height: spacing.lg),
        EmptyStateCard(
          icon: Icons.insights,
          title: 'Nema spremljenih sesija',
          message:
              'Nakon snimanja ovdje će biti dostupni sažeci, '
              'trendovi i izvoz podataka.',
          actionLabel: 'Snimi sesiju',
          actionIcon: Icons.fiber_manual_record,
          onAction: () => context.go(AppRoutes.record),
        ),
        SizedBox(height: spacing.md),
        const InfoCard(
          title: 'Uvidi',
          rows: [
            NavigationListTile(
              icon: Icons.timeline,
              title: 'Trend kadence',
              showChevron: false,
            ),
            NavigationListTile(
              icon: Icons.speed,
              title: 'Trend brzine hoda',
              showChevron: false,
            ),
            NavigationListTile(
              icon: Icons.compare_arrows,
              title: 'Usporedba aktivnosti',
              showChevron: false,
            ),
          ],
        ),
      ],
    );
  }
}
