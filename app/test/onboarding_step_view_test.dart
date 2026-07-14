import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gait_sense/theme/gait_sense_theme.dart';
import 'package:gait_sense/widgets/widgets.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: GaitSenseTheme.light(),
      home: Scaffold(body: child),
    );
  }

  testWidgets('renders the icon badge when given an icon', (tester) async {
    await tester.pumpWidget(
      wrap(
        const OnboardingStepView(
          icon: Icons.notifications_active_outlined,
          title: 'Naslov',
          description: 'Opis',
        ),
      ),
    );

    expect(find.byIcon(Icons.notifications_active_outlined), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('renders the illustration asset when given imageAsset', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const OnboardingStepView(
          imageAsset: 'assets/illustrations/phone_pocket_placement.png',
          title: 'Naslov',
          description: 'Opis',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
