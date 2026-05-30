import 'package:flutter_test/flutter_test.dart';
import 'package:gait_sense/app.dart';

void main() {
  testWidgets('app renders the live HAR screen with a Start control', (
    tester,
  ) async {
    await tester.pumpWidget(const GaitSenseApp());
    expect(find.text('Live HAR'), findsOneWidget);
    expect(find.text('Zaustavljeno'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
  });
}
