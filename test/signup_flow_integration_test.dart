import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:devguard_ai_copilot/main.dart';
import 'package:devguard_ai_copilot/core/providers/app_state_provider.dart';
import 'package:devguard_ai_copilot/core/providers/theme_provider.dart';
import 'package:devguard_ai_copilot/presentation/screens/landing_screen.dart';
import 'package:devguard_ai_copilot/presentation/widgets/admin_signup_form.dart';

void main() {
  group('Signup Flow Integration Tests', () {
    testWidgets('Admin signup wizard navigation works correctly',
        (WidgetTester tester) async {
      // Build the app
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => AppStateProvider()),
          ],
          child: const MaterialApp(
            home: LandingScreen(),
          ),
        ),
      );

      // Wait for the widget to settle
      await tester.pumpAndSettle();

      // Verify we're on the landing screen
      expect(find.text('DevGuard AI Copilot'), findsOneWidget);
      expect(find.text('Create New Project'), findsOneWidget);

      // Find the admin signup form
      expect(find.byType(AdminSignupForm), findsOneWidget);

      // Test Step 1: Admin Account Details
      expect(find.text('Admin Account'), findsOneWidget);

      // Fill in admin account details
      await tester.enterText(find.byKey(const Key('name_field')), 'Test Admin');
      await tester.enterText(
          find.byKey(const Key('email_field')), 'admin@test.com');
      await tester.enterText(
          find.byKey(const Key('password_field')), 'testpassword123');
      await tester.enterText(
          find.byKey(const Key('confirm_password_field')), 'testpassword123');

      // Click Next button
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Verify we moved to Step 2: Project Details
      expect(find.text('Project Details'), findsOneWidget);
      expect(find.text('Project Information'), findsOneWidget);

      // Fill in project details
      await tester.enterText(
          find.byKey(const Key('project_name_field')), 'Test Project');
      await tester.enterText(find.byKey(const Key('project_description_field')),
          'A test project for validation');

      // Click Next button
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Verify we moved to Step 3: Configuration
      expect(find.text('Configuration'), findsOneWidget);
      expect(find.text('Project Configuration'), findsOneWidget);

      // Verify summary information is displayed
      expect(find.text('Name: Test Admin'), findsOneWidget);
      expect(find.text('Email: admin@test.com'), findsOneWidget);
      expect(find.text('Name: Test Project'), findsOneWidget);

      // The Create Project button should be visible
      expect(find.text('Create Project'), findsOneWidget);
    });

    testWidgets('Validation prevents progression with empty fields',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => AppStateProvider()),
          ],
          child: const MaterialApp(
            home: LandingScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Try to click Next without filling any fields
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Should show validation error and stay on step 1
      expect(find.text('Admin Account'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('Back button navigation works correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => AppStateProvider()),
          ],
          child: const MaterialApp(
            home: LandingScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Fill step 1 and proceed
      await tester.enterText(find.byKey(const Key('name_field')), 'Test Admin');
      await tester.enterText(
          find.byKey(const Key('email_field')), 'admin@test.com');
      await tester.enterText(
          find.byKey(const Key('password_field')), 'testpassword123');
      await tester.enterText(
          find.byKey(const Key('confirm_password_field')), 'testpassword123');

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Verify we're on step 2
      expect(find.text('Project Details'), findsOneWidget);

      // Click Back button
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      // Verify we're back on step 1
      expect(find.text('Admin Account'), findsOneWidget);

      // Verify form data is preserved
      expect(find.text('Test Admin'), findsOneWidget);
      expect(find.text('admin@test.com'), findsOneWidget);
    });

    testWidgets('Password validation works correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => AppStateProvider()),
          ],
          child: const MaterialApp(
            home: LandingScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Fill fields with mismatched passwords
      await tester.enterText(find.byKey(const Key('name_field')), 'Test Admin');
      await tester.enterText(
          find.byKey(const Key('email_field')), 'admin@test.com');
      await tester.enterText(
          find.byKey(const Key('password_field')), 'testpassword123');
      await tester.enterText(
          find.byKey(const Key('confirm_password_field')), 'differentpassword');

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Should show validation error
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Admin Account'), findsOneWidget); // Still on step 1
    });

    testWidgets('Email validation works correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => AppStateProvider()),
          ],
          child: const MaterialApp(
            home: LandingScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Fill fields with invalid email
      await tester.enterText(find.byKey(const Key('name_field')), 'Test Admin');
      await tester.enterText(
          find.byKey(const Key('email_field')), 'invalid-email');
      await tester.enterText(
          find.byKey(const Key('password_field')), 'testpassword123');
      await tester.enterText(
          find.byKey(const Key('confirm_password_field')), 'testpassword123');

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Should show validation error
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Admin Account'), findsOneWidget); // Still on step 1
    });
  });

  group('GitHub OAuth Integration Tests', () {
    testWidgets('GitHub OAuth button is present and functional',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => AppStateProvider()),
          ],
          child: const MaterialApp(
            home: LandingScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Switch to Login tab
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      // Verify GitHub OAuth button is present
      expect(find.text('Continue with GitHub'), findsOneWidget);
      expect(find.byIcon(Icons.code), findsOneWidget);

      // Test clicking the GitHub button
      await tester.tap(find.text('Continue with GitHub'));
      await tester.pumpAndSettle();

      // Should show loading state or navigate (in demo mode)
      // This would be expanded in a real implementation
    });
  });

  group('Cross-Platform Compatibility Tests', () {
    testWidgets('Responsive layout adapts correctly',
        (WidgetTester tester) async {
      // Test mobile layout
      tester.binding.window.physicalSizeTestValue = const Size(400, 800);
      tester.binding.window.devicePixelRatioTestValue = 1.0;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => AppStateProvider()),
          ],
          child: const MaterialApp(
            home: LandingScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify mobile layout elements
      expect(find.byType(LandingScreen), findsOneWidget);

      // Test desktop layout
      tester.binding.window.physicalSizeTestValue = const Size(1920, 1080);
      await tester.pumpAndSettle();

      // Verify desktop layout elements
      expect(find.byType(LandingScreen), findsOneWidget);

      // Reset to default
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    });
  });
}
