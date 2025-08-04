// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:devguard_ai_copilot/main.dart';

void main() {
  testWidgets('DevGuard app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const DevGuardApp());

    // Verify that the app loads with the home screen
    expect(find.text('DevGuard AI Copilot'), findsOneWidget);
  });
}
