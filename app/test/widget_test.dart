import 'package:flutter_test/flutter_test.dart';
import 'package:gait_sense/app.dart';

void main() {
  testWidgets('Gait Sense app renders', (tester) async {
    await tester.pumpWidget(const GaitSenseApp());
    expect(find.text('Gait Sense'), findsOneWidget);
  });
}
