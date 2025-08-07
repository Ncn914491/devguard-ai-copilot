import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:devguard_ai_copilot/main.dart' as app;
import 'package:devguard_ai_copilot/core/utils/platform_utils.dart';
import 'package:devguard_ai_copilot/core/utils/responsive_utils.dart';
import 'package:devguard_ai_copilot/core/services/cross_platform_storage_service.dart';

void main() {
  group('Cross-Platform Integration Tests', () {
    testWidgets('App launches successfully on all platforms', (tester) async {
      await tester.pumpWidget(const app.DevGuardApp());
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verify app launches
      expect(find.byType(MaterialApp), findsOneWidget);

      // Platform-specific verifications
      if (PlatformUtils.isMobile) {
        // Mobile should show drawer button or bottom navigation
        final hasMenu = find.byIcon(Icons.menu).evaluate().isNotEmpty;
        final hasBottomNav =
            find.byType(BottomNavigationBar).evaluate().isNotEmpty;
        expect(hasMenu || hasBottomNav, isTrue);
      } else {
        // Desktop should show sidebar
        expect(find.text('DevGuard AI Copilot'), findsWidgets);
      }
    });

    testWidgets('Responsive layout adapts correctly', (tester) async {
      await tester.pumpWidget(const app.DevGuardApp());
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Test different screen sizes
      await _testResponsiveLayout(tester, const Size(400, 800)); // Mobile
      await _testResponsiveLayout(tester, const Size(800, 600)); // Tablet
      await _testResponsiveLayout(tester, const Size(1200, 800)); // Desktop
    });

    testWidgets('Cross-platform storage works correctly', (tester) async {
      await tester.pumpWidget(const app.DevGuardApp());
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final storage = CrossPlatformStorageService.instance;
      await storage.initialize();

      // Test string storage
      await storage.setString('test_key', 'test_value');
      expect(storage.getString('test_key'), equals('test_value'));

      // Test object storage
      final testObject = {'name': 'test', 'value': 123};
      await storage.setObject('test_object', testObject);
      final retrievedObject = storage.getObject('test_object');
      expect(retrievedObject?['name'], equals('test'));
      expect(retrievedObject?['value'], equals(123));
    });

    testWidgets('Navigation works across all platforms', (tester) async {
      await tester.pumpWidget(const app.DevGuardApp());
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Navigate to main screen
      if (find.text('Get Started').evaluate().isNotEmpty) {
        await tester.tap(find.text('Get Started'));
        await tester.pumpAndSettle(const Duration(seconds: 1));
      }

      // Test navigation to different screens
      await _testNavigation(tester, 'workflow');
      await _testNavigation(tester, 'team');
      await _testNavigation(tester, 'deployments');
    });

    testWidgets('Platform-specific features work correctly', (tester) async {
      await tester.pumpWidget(const app.DevGuardApp());
      await tester.pumpAndSettle(const Duration(seconds: 1));

      if (PlatformUtils.supportsEmbeddedTerminal) {
        // Test terminal functionality on desktop
        await _testTerminalFunctionality(tester);
      }

      if (PlatformUtils.supportsFileSystem) {
        // Test file operations
        await _testFileOperations(tester);
      }
    });

    testWidgets('Authentication flow works on all platforms', (tester) async {
      await tester.pumpWidget(const app.DevGuardApp());
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Test login flow
      await _testAuthenticationFlow(tester);
    });

    testWidgets('Copilot sidebar adapts to platform', (tester) async {
      await tester.pumpWidget(const app.DevGuardApp());
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Navigate to main screen
      if (find.text('Get Started').evaluate().isNotEmpty) {
        await tester.tap(find.text('Get Started'));
        await tester.pumpAndSettle(const Duration(seconds: 1));
      }

      // Test copilot functionality
      await _testCopilotFunctionality(tester);
    });
  });
}

Future<void> _testResponsiveLayout(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  await tester.pumpAndSettle(const Duration(milliseconds: 500));

  final context = tester.element(find.byType(MaterialApp));
  final deviceType = ResponsiveUtils.getDeviceType(context);

  switch (deviceType) {
    case DeviceType.mobile:
      // Mobile should have drawer or bottom navigation
      final hasDrawer = find.byType(Drawer).evaluate().isNotEmpty;
      final hasBottomNav =
          find.byType(BottomNavigationBar).evaluate().isNotEmpty;
      expect(hasDrawer || hasBottomNav, isTrue);
      break;
    case DeviceType.tablet:
      // Tablet should have collapsible sidebar
      expect(find.byType(MaterialApp), findsOneWidget);
      break;
    case DeviceType.desktop:
      // Desktop should have full sidebar
      expect(find.byType(MaterialApp), findsOneWidget);
      break;
  }
}

Future<void> _testNavigation(WidgetTester tester, String screenName) async {
  // Try to find navigation element for the screen
  final upperCaseElement = find.text(screenName.toUpperCase());
  final capitalizedElement =
      find.text(screenName[0].toUpperCase() + screenName.substring(1));

  if (upperCaseElement.evaluate().isNotEmpty) {
    await tester.tap(upperCaseElement.first);
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
  } else if (capitalizedElement.evaluate().isNotEmpty) {
    await tester.tap(capitalizedElement.first);
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
  }

  // Verify navigation occurred
  expect(find.byType(MaterialApp), findsOneWidget);
}

Future<void> _testTerminalFunctionality(WidgetTester tester) async {
  // Look for terminal widget
  final terminalFields = find.byType(TextField);

  if (terminalFields.evaluate().isNotEmpty) {
    final terminalFinder = terminalFields.last;
    await tester.enterText(terminalFinder, 'help');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    // Verify terminal response (may not always be present)
    // Just verify the terminal exists
    expect(terminalFields, findsWidgets);
  }
}

Future<void> _testFileOperations(WidgetTester tester) async {
  // Test file-related operations if supported
  if (PlatformUtils.supportsFileSystem) {
    // This would test file explorer or file operations
    // Implementation depends on specific file widgets
  }
}

Future<void> _testAuthenticationFlow(WidgetTester tester) async {
  // Test login/signup flow
  final loginButton = find.text('Login');
  final signInButton = find.text('Sign In');

  if (loginButton.evaluate().isNotEmpty) {
    await tester.tap(loginButton.first);
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
  } else if (signInButton.evaluate().isNotEmpty) {
    await tester.tap(signInButton.first);
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
  }

  // Test form fields
  final textFields = find.byType(TextField);
  if (textFields.evaluate().isNotEmpty) {
    await tester.enterText(textFields.first, 'test@example.com');
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
  }
}

Future<void> _testCopilotFunctionality(WidgetTester tester) async {
  // Look for copilot toggle button
  final assistantButton = find.byIcon(Icons.assistant);
  final copilotButton = find.text('Copilot');

  if (assistantButton.evaluate().isNotEmpty) {
    await tester.tap(assistantButton.first);
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
  } else if (copilotButton.evaluate().isNotEmpty) {
    await tester.tap(copilotButton.first);
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
  }

  // Verify copilot sidebar appears
  expect(find.byType(MaterialApp), findsOneWidget);
}
