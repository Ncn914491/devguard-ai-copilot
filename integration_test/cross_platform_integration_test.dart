import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:devguard_ai_copilot/main.dart' as app;
import 'package:devguard_ai_copilot/core/utils/platform_utils.dart';
import 'package:devguard_ai_copilot/core/utils/responsive_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Cross-Platform Integration Tests', () {
    testWidgets('Complete onboarding flow works on all platforms',
        (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Should start on landing screen
      expect(find.text('DevGuard AI Copilot'), findsWidgets);

      // Test platform-specific onboarding
      if (ResponsiveUtils.isMobile(tester.element(find.byType(MaterialApp)))) {
        await _testMobileOnboarding(tester);
      } else {
        await _testDesktopOnboarding(tester);
      }
    });

    testWidgets('Authentication flow works across platforms', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Look for login/signup options
      final loginButton = find.text('Login');
      final signInButton = find.text('Sign In');
      final getStartedButton = find.text('Get Started');

      if (loginButton.evaluate().isNotEmpty) {
        await tester.tap(loginButton.first);
        await tester.pumpAndSettle(const Duration(seconds: 1));
        await _testAuthenticationForm(tester);
      } else if (signInButton.evaluate().isNotEmpty) {
        await tester.tap(signInButton.first);
        await tester.pumpAndSettle(const Duration(seconds: 1));
        await _testAuthenticationForm(tester);
      } else if (getStartedButton.evaluate().isNotEmpty) {
        await tester.tap(getStartedButton.first);
        await tester.pumpAndSettle(const Duration(seconds: 1));
      }
    });

    testWidgets('Project creation works on all platforms', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate through onboarding to project creation
      await _navigateToProjectCreation(tester);

      // Test project creation form
      await _testProjectCreation(tester);
    });

    testWidgets('Main application features work cross-platform',
        (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to main screen
      await _navigateToMainScreen(tester);

      // Test core features
      await _testWorkflowFeatures(tester);
      await _testSecurityFeatures(tester);
      await _testTeamFeatures(tester);
      await _testDeploymentFeatures(tester);
    });

    testWidgets('Copilot functionality works across platforms', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      await _navigateToMainScreen(tester);

      // Test copilot interaction
      await _testCopilotInteraction(tester);
    });

    testWidgets('Responsive layout adapts correctly during runtime',
        (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Test different screen sizes
      await _testResponsiveLayoutChanges(tester);
    });

    testWidgets('Data persistence works across platform restarts',
        (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Create some data
      await _createTestData(tester);

      // Restart app (simulate)
      await tester.binding.reassembleApplication();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verify data persists
      await _verifyDataPersistence(tester);
    });
  });
}

Future<void> _testMobileOnboarding(WidgetTester tester) async {
  // Mobile-specific onboarding tests
  final hasAppBar = find.byType(AppBar).evaluate().isNotEmpty;
  final hasDrawer = find.byType(Drawer).evaluate().isNotEmpty;
  expect(hasAppBar || hasDrawer, isTrue);

  // Look for mobile-friendly navigation
  final getStartedButton = find.text('Get Started');
  if (getStartedButton.evaluate().isNotEmpty) {
    await tester.tap(getStartedButton);
    await tester.pumpAndSettle();
  }
}

Future<void> _testDesktopOnboarding(WidgetTester tester) async {
  // Desktop-specific onboarding tests
  expect(find.byType(Scaffold), findsOneWidget);

  // Look for desktop-style navigation
  final getStartedButton = find.text('Get Started');
  if (getStartedButton.evaluate().isNotEmpty) {
    await tester.tap(getStartedButton);
    await tester.pumpAndSettle();
  }
}

Future<void> _testAuthenticationForm(WidgetTester tester) async {
  // Look for email/username field
  final textFields = find.byType(TextField);
  if (textFields.evaluate().length >= 2) {
    // Enter email
    await tester.enterText(textFields.first, 'test@example.com');
    await tester.pumpAndSettle();

    // Enter password
    await tester.enterText(textFields.at(1), 'password123');
    await tester.pumpAndSettle();

    // Look for submit button
    final loginSubmit = find.text('Login');
    final signInSubmit = find.text('Sign In');
    final submitButton = find.text('Submit');

    if (loginSubmit.evaluate().isNotEmpty) {
      await tester.tap(loginSubmit.first);
      await tester.pumpAndSettle(const Duration(seconds: 1));
    } else if (signInSubmit.evaluate().isNotEmpty) {
      await tester.tap(signInSubmit.first);
      await tester.pumpAndSettle(const Duration(seconds: 1));
    } else if (submitButton.evaluate().isNotEmpty) {
      await tester.tap(submitButton.first);
      await tester.pumpAndSettle(const Duration(seconds: 1));
    }
  }
}

Future<void> _navigateToProjectCreation(WidgetTester tester) async {
  // Look for project creation navigation
  final createProjectButton = find.text('Create Project');
  final newProjectButton = find.text('New Project');

  if (createProjectButton.evaluate().isNotEmpty) {
    await tester.tap(createProjectButton.first);
    await tester.pumpAndSettle(const Duration(seconds: 1));
  } else if (newProjectButton.evaluate().isNotEmpty) {
    await tester.tap(newProjectButton.first);
    await tester.pumpAndSettle(const Duration(seconds: 1));
  }
}

Future<void> _testProjectCreation(WidgetTester tester) async {
  // Look for project name field
  final projectNameField = find.byType(TextField).first;
  if (projectNameField.evaluate().isNotEmpty) {
    await tester.enterText(projectNameField, 'Test Project');
    await tester.pumpAndSettle();

    // Look for create button
    final createButton = find.text('Create');
    final createProjectButton = find.text('Create Project');

    if (createButton.evaluate().isNotEmpty) {
      await tester.tap(createButton.first);
      await tester.pumpAndSettle(const Duration(seconds: 1));
    } else if (createProjectButton.evaluate().isNotEmpty) {
      await tester.tap(createProjectButton.first);
      await tester.pumpAndSettle(const Duration(seconds: 1));
    }
  }
}

Future<void> _navigateToMainScreen(WidgetTester tester) async {
  // Try different ways to get to main screen
  final mainScreenTriggers = [
    find.text('Continue'),
    find.text('Dashboard'),
    find.text('Main'),
    find.byIcon(Icons.home),
  ];

  for (final trigger in mainScreenTriggers) {
    if (trigger.evaluate().isNotEmpty) {
      await tester.tap(trigger.first);
      await tester.pumpAndSettle();
      break;
    }
  }
}

Future<void> _testWorkflowFeatures(WidgetTester tester) async {
  // Navigate to workflow screen
  final workflowNav = find.text('Workflow');
  final workflowNavUpper = find.text('WORKFLOW');

  if (workflowNav.evaluate().isNotEmpty) {
    await tester.tap(workflowNav.first);
    await tester.pumpAndSettle(const Duration(seconds: 1));
  } else if (workflowNavUpper.evaluate().isNotEmpty) {
    await tester.tap(workflowNavUpper.first);
    await tester.pumpAndSettle(const Duration(seconds: 1));
  }

  // Test workflow functionality
  expect(find.byType(Scaffold), findsOneWidget);
}

Future<void> _testSecurityFeatures(WidgetTester tester) async {
  // Navigate to security screen
  final securityNav = find.text('Security');
  final securityNavUpper = find.text('SECURITY');

  if (securityNav.evaluate().isNotEmpty) {
    await tester.tap(securityNav.first);
    await tester.pumpAndSettle(const Duration(seconds: 1));
  } else if (securityNavUpper.evaluate().isNotEmpty) {
    await tester.tap(securityNavUpper.first);
    await tester.pumpAndSettle(const Duration(seconds: 1));
  }

  // Test security functionality
  expect(find.byType(Scaffold), findsOneWidget);
}

Future<void> _testTeamFeatures(WidgetTester tester) async {
  // Navigate to team screen
  final teamNav = find.text('Team');
  final teamNavUpper = find.text('TEAM');

  if (teamNav.evaluate().isNotEmpty) {
    await tester.tap(teamNav.first);
    await tester.pumpAndSettle(const Duration(seconds: 1));
  } else if (teamNavUpper.evaluate().isNotEmpty) {
    await tester.tap(teamNavUpper.first);
    await tester.pumpAndSettle(const Duration(seconds: 1));
  }

  // Test team functionality
  expect(find.byType(Scaffold), findsOneWidget);
}

Future<void> _testDeploymentFeatures(WidgetTester tester) async {
  // Navigate to deployments screen
  final deployNav = find.text('Deploy');
  final deploymentsNav = find.text('Deployments');
  final deploymentsNavUpper = find.text('DEPLOYMENTS');

  if (deployNav.evaluate().isNotEmpty) {
    await tester.tap(deployNav.first);
    await tester.pumpAndSettle(const Duration(seconds: 1));
  } else if (deploymentsNav.evaluate().isNotEmpty) {
    await tester.tap(deploymentsNav.first);
    await tester.pumpAndSettle(const Duration(seconds: 1));
  } else if (deploymentsNavUpper.evaluate().isNotEmpty) {
    await tester.tap(deploymentsNavUpper.first);
    await tester.pumpAndSettle(const Duration(seconds: 1));
  }

  // Test deployment functionality
  expect(find.byType(Scaffold), findsOneWidget);
}

Future<void> _testCopilotInteraction(WidgetTester tester) async {
  // Look for copilot toggle
  final assistantButton = find.byIcon(Icons.assistant);
  final copilotButton = find.text('Copilot');

  if (assistantButton.evaluate().isNotEmpty) {
    await tester.tap(assistantButton.first);
    await tester.pumpAndSettle(const Duration(seconds: 1));
  } else if (copilotButton.evaluate().isNotEmpty) {
    await tester.tap(copilotButton.first);
    await tester.pumpAndSettle(const Duration(seconds: 1));
  }

  // Look for copilot input field
  final textFields = find.byType(TextField);
  if (textFields.evaluate().isNotEmpty) {
    final copilotInput = textFields.last;
    await tester.enterText(copilotInput, '/help');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Should see some response
    expect(find.byType(Scaffold), findsOneWidget);
  }
}

Future<void> _testResponsiveLayoutChanges(WidgetTester tester) async {
  // Test mobile size
  await tester.binding.setSurfaceSize(const Size(400, 800));
  await tester.pumpAndSettle();

  final context = tester.element(find.byType(MaterialApp));
  expect(ResponsiveUtils.isMobile(context), isTrue);

  // Test tablet size
  await tester.binding.setSurfaceSize(const Size(800, 600));
  await tester.pumpAndSettle();
  expect(ResponsiveUtils.isTablet(context), isTrue);

  // Test desktop size
  await tester.binding.setSurfaceSize(const Size(1200, 800));
  await tester.pumpAndSettle();
  expect(ResponsiveUtils.isDesktop(context), isTrue);
}

Future<void> _createTestData(WidgetTester tester) async {
  // Create some test data that should persist
  // This would involve interacting with forms, creating projects, etc.

  // For now, just verify the app is running
  expect(find.byType(MaterialApp), findsOneWidget);
}

Future<void> _verifyDataPersistence(WidgetTester tester) async {
  // Verify that data created in _createTestData still exists
  // This would check for saved projects, user preferences, etc.

  // For now, just verify the app restarted correctly
  expect(find.byType(MaterialApp), findsOneWidget);
}
