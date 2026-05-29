import 'package:flutter_test/flutter_test.dart';
import 'package:gait_sense/app.dart';

void main() {
  testWidgets('app renders the debug sensors screen', (tester) async {
    await tester.pumpWidget(const GaitSenseApp());
    expect(find.text('Debug senzori'), findsOneWidget);
    expect(find.text('Nema uzoraka.'), findsOneWidget);
  });
}
