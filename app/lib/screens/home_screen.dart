import 'package:flutter/material.dart';
import 'package:gait_sense/navigation/app_routes.dart';
import 'package:gait_sense/theme/theme_context.dart';
import 'package:gait_sense/widgets/widgets.dart';
import 'package:go_router/go_router.dart';

/// Dashboard tab shown when the app starts.
class HomeScreen extends StatelessWidget {
  /// Creates the dashboard screen.
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return ScreenBody(
      children: [
        const ScreenHeader(
          title: 'Gait Sense',
          subtitle: 'Pregled stanja i zadnjih mjerenja',
        ),
        SizedBox(height: spacing.lg),
        ActionCard(
          icon: Icons.directions_walk,
          title: 'Nova sesija',
          subtitle: 'Pokreni snimanje prije nego mobitel spremiš u džep.',
          actionLabel: 'Započni',
          onPressed: () => context.go(AppRoutes.record),
        ),
        SizedBox(height: spacing.md),
        const MetricGrid(
          tiles: [
            MetricTile(label: 'Sesije', value: '0'),
            MetricTile(label: 'Hodanje', value: '-'),
            MetricTile(label: 'Kadenca', value: '-'),
            MetricTile(label: 'Brzina', value: '-'),
          ],
        ),
        SizedBox(height: spacing.md),
        const InfoCard(
          title: 'Zadnja sesija',
          rows: [
            LabeledRow(label: 'Status', value: 'Nema spremljenih sesija'),
            LabeledRow(label: 'Trajanje', value: '-'),
            LabeledRow(label: 'Predikcije', value: '-'),
          ],
        ),
      ],
    );
  }
}
