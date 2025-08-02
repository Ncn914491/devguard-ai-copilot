import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/presentation/widgets/copilot_sidebar.dart';
import '../lib/core/theme/app_theme.dart';

void main() {
  group('CopilotSidebar Widget Tests', () {
    testWidgets('should display collapsed view when not expanded', (WidgetTester tester) async {
      bool isExpanded = false;
      
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: CopilotSidebar(
              isExpanded: isExpanded,
              onToggle: () => isExpanded = !isExpanded,
            ),
          ),
        ),
      );

      // Should show collapsed view
      expect(find.byIcon(Icons.smart_toy), findsOneWidget);
      expect(find.byIcon(Icons.help_outline), findsOneWidget);
      expect(find.byIcon(Icons.summarize), findsOneWidget);
      expect(find.byIcon(Icons.security), findsOneWidget);
      
      // Should not show expanded elements
      expect(find.text('AI Copilot'), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('should display expanded view when expanded', (WidgetTester tester) async {
      bool isExpanded = true;
      
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: CopilotSidebar(
              isExpanded: isExpanded,
              onToggle: () => isExpanded = !isExpanded,
            ),
          ),
        ),
      );

      // Should show expanded elements
      expect(find.text('AI Copilot'), findsOneWidget);
      expect(find.text('Online'), findsOneWidget);
      expect(find.text('Quick Commands'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.send), findsOneWidget);
      
      // Should show welcome message
      expect(find.textContaining('Hello! I\'m your DevGuard AI Copilot'), findsOneWidget);
    });

    testWidgets('should show quick command chips in expanded view', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: CopilotSidebar(
              isExpanded: true,
              onToggle: () {},
            ),
          ),
        ),
      );

      // Should show command chips
      expect(find.text('/rollback'), findsOneWidget);
      expect(find.text('/assign'), findsOneWidget);
      expect(find.text('/summarize'), findsOneWidget);
      expect(find.text('/security'), findsOneWidget);
    });

    testWidgets('should send message when text is entered and send button pressed', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: CopilotSidebar(
              isExpanded: true,
              onToggle: () {},
            ),
          ),
        ),
      );

      // Enter text in the input field
      await tester.enterText(find.byType(TextField), 'Hello AI');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      // Should show user message
      expect(find.text('Hello AI'), findsOneWidget);
      
      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('AI is thinking...'), findsOneWidget);
    });

    testWidgets('should execute quick command when chip is tapped', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: CopilotSidebar(
              isExpanded: true,
              onToggle: () {},
            ),
          ),
        ),
      );

      // Tap the /summarize command chip
      await tester.tap(find.text('/summarize'));
      await tester.pump();

      // Should show the command as a user message
      expect(find.text('/summarize'), findsWidgets);
      
      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should toggle between collapsed and expanded views', (WidgetTester tester) async {
      bool isExpanded = false;
      
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: CopilotSidebar(
                  isExpanded: isExpanded,
                  onToggle: () => setState(() => isExpanded = !isExpanded),
                ),
              );
            },
          ),
        ),
      );

      // Initially collapsed
      expect(find.text('AI Copilot'), findsNothing);
      
      // Tap to expand
      await tester.tap(find.byIcon(Icons.smart_toy));
      await tester.pumpAndSettle();
      
      // Should be expanded
      expect(find.text('AI Copilot'), findsOneWidget);
      
      // Tap to collapse
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      
      // Should be collapsed again
      expect(find.text('AI Copilot'), findsNothing);
    });

    testWidgets('should show approval buttons for messages requiring approval', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: CopilotSidebar(
              isExpanded: true,
              onToggle: () {},
            ),
          ),
        ),
      );

      // Send a rollback command that requires approval
      await tester.enterText(find.byType(TextField), '/rollback production');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      
      // Wait for response (this would normally come from the service)
      await tester.pump(const Duration(seconds: 1));
      
      // Note: In a real test, we would mock the CopilotService to return
      // a response that requires approval, then verify the approval buttons appear
    });

    testWidgets('should handle quick action buttons in collapsed view', (WidgetTester tester) async {
      bool wasToggled = false;
      
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: CopilotSidebar(
              isExpanded: false,
              onToggle: () => wasToggled = true,
            ),
          ),
        ),
      );

      // Tap help button
      await tester.tap(find.byIcon(Icons.help_outline));
      await tester.pump();
      
      // Should have triggered toggle
      expect(wasToggled, isTrue);
    });

    testWidgets('should format timestamps correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: CopilotSidebar(
              isExpanded: true,
              onToggle: () {},
            ),
          ),
        ),
      );

      // The welcome message should show a timestamp
      expect(find.textContaining('Just now'), findsOneWidget);
    });

    testWidgets('should clear input field after sending message', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: CopilotSidebar(
              isExpanded: true,
              onToggle: () {},
            ),
          ),
        ),
      );

      final textField = find.byType(TextField);
      
      // Enter text
      await tester.enterText(textField, 'Test message');
      expect(find.text('Test message'), findsOneWidget);
      
      // Send message
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      
      // Input field should be cleared
      final textFieldWidget = tester.widget<TextField>(textField);
      expect(textFieldWidget.controller?.text, isEmpty);
    });
  });

  group('CopilotSidebar Responsiveness Tests', () {
    testWidgets('should adapt to different screen sizes', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: CopilotSidebar(
              isExpanded: true,
              onToggle: () {},
            ),
          ),
        ),
      );

      // Test with different screen sizes
      await tester.binding.setSurfaceSize(const Size(800, 600));
      await tester.pump();
      
      // Should still show all elements
      expect(find.text('AI Copilot'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      
      await tester.binding.setSurfaceSize(const Size(400, 800));
      await tester.pump();
      
      // Should still be functional on narrow screens
      expect(find.text('AI Copilot'), findsOneWidget);
    });
  });
}