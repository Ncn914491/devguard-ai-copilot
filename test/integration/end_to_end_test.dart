import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:devguard_ai_copilot/main.dart' as app;
import 'package:devguard_ai_copilot/core/database/services/services.dart';
import 'package:devguard_ai_copilot/core/security/security_monitor.dart';
import 'package:devguard_ai_copilot/core/ai/copilot_service.dart';
import 'package:devguard_ai_copilot/core/gitops/git_integration.dart';
import 'package:devguard_ai_copilot/core/deployment/deployment_pipeline.dart';
import 'package:devguard_ai_copilot/core/error/error_handler.dart';

/// Comprehensive end-to-end integration tests
/// Satisfies Requirements: 14.1, 14.2, 14.3 (End-to-end testing and demo scenarios)
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('DevGuard AI Copilot - End-to-End Tests', () {
    late SecurityMonitor securityMonitor;
    late CopilotService copilotService;
    late GitIntegration gitIntegration;
    late DeploymentPipeline deploymentPipeline;
    late ErrorHandler errorHandler;

    setUpAll(() async {
      // Initialize core services
      securityMonitor = SecurityMonitor.instance;
      copilotService = CopilotService.instance;
      gitIntegration = GitIntegration.instance;
      deploymentPipeline = DeploymentPipeline.instance;
      errorHandler = ErrorHandler.instance;

      // Initialize services
      await securityMonitor.initialize();
      await errorHandler.initialize();
    });

    tearDownAll(() async {
      // Cleanup services
      securityMonitor.dispose();
      errorHandler.dispose();
    });

    testWidgets('Complete Application Workflow', (WidgetTester tester) async {
      // Start the application
      app.main();
      await tester.pumpAndSettle();

      // Verify main screen loads
      expect(find.text('DevGuard AI Copilot'), findsOneWidget);
      
      // Test navigation to different screens
      await _testNavigationFlow(tester);
      
      // Test core functionality
      await _testSecurityMonitoring(tester);
      await _testAICopilotInteraction(tester);
      await _testSpecificationWorkflow(tester);
      await _testDeploymentManagement(tester);
      await _testAuditLogging(tester);
    });

    testWidgets('Security Monitoring Integration', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to security screen
      await tester.tap(find.text('Security'));
      await tester.pumpAndSettle();

      // Verify security monitoring is active
      expect(find.text('Security Status'), findsOneWidget);
      
      // Test honeytoken deployment
      final status = await securityMonitor.getSecurityStatus();
      expect(status.honeytokensDeployed, greaterThan(0));
      expect(status.isMonitoring, isTrue);

      // Simulate security alert
      await securityMonitor.simulateHoneytokenAccess(
        '4111-1111-1111-1111',
        'test_access_context',
      );
      
      await tester.pumpAndSettle();
      
      // Verify alert appears in UI
      expect(find.textContaining('Security Alert'), findsAtLeastOneWidget);
    });

    testWidgets('AI Copilot Functionality', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Open copilot sidebar
      await tester.tap(find.byIcon(Icons.assistant));
      await tester.pumpAndSettle();

      // Test chat interaction
      await tester.enterText(find.byType(TextField), 'What is the current system status?');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // Verify response appears
      expect(find.textContaining('System Summary'), findsOneWidget);

      // Test quick commands
      await tester.enterText(find.byType(TextField), '/summarize');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // Verify command response
      expect(find.textContaining('Specifications:'), findsOneWidget);

      // Test help command
      await tester.enterText(find.byType(TextField), '/help');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // Verify help response
      expect(find.textContaining('Available Commands:'), findsOneWidget);
    });

    testWidgets('Specification Workflow', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to workflow screen
      await tester.tap(find.text('AI Workflow'));
      await tester.pumpAndSettle();

      // Create new specification
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Enter specification details
      await tester.enterText(
        find.byKey(const Key('spec_input')),
        'Create a user authentication system with JWT tokens and role-based access control',
      );
      
      await tester.tap(find.text('Process Specification'));
      await tester.pumpAndSettle();

      // Verify specification is processed
      expect(find.textContaining('feature/user-authentication'), findsOneWidget);
      expect(find.textContaining('JWT'), findsOneWidget);

      // Test specification approval
      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      // Verify specification status changes
      expect(find.text('Approved'), findsOneWidget);
    });

    testWidgets('Deployment Management', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to deployments screen
      await tester.tap(find.text('Deployments'));
      await tester.pumpAndSettle();

      // Verify deployment dashboard loads
      expect(find.text('Deployment Status'), findsOneWidget);
      
      // Test deployment creation
      await tester.tap(find.text('New Deployment'));
      await tester.pumpAndSettle();

      // Configure deployment
      await tester.enterText(find.byKey(const Key('deployment_version')), '1.0.1');
      await tester.tap(find.text('Development'));
      await tester.tap(find.text('Create Deployment'));
      await tester.pumpAndSettle();

      // Verify deployment appears in list
      expect(find.textContaining('1.0.1'), findsOneWidget);
      expect(find.textContaining('Development'), findsOneWidget);
    });

    testWidgets('Team Management', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to team screen
      await tester.tap(find.text('Team'));
      await tester.pumpAndSettle();

      // Verify team dashboard loads
      expect(find.text('Team Members'), findsOneWidget);

      // Test adding team member
      await tester.tap(find.byIcon(Icons.person_add));
      await tester.pumpAndSettle();

      // Fill member details
      await tester.enterText(find.byKey(const Key('member_name')), 'John Doe');
      await tester.enterText(find.byKey(const Key('member_email')), 'john@example.com');
      await tester.tap(find.text('Developer'));
      await tester.tap(find.text('Add Member'));
      await tester.pumpAndSettle();

      // Verify member appears in list
      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('john@example.com'), findsOneWidget);
    });

    testWidgets('Audit Logging', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to audit screen
      await tester.tap(find.text('Audit'));
      await tester.pumpAndSettle();

      // Verify audit logs are displayed
      expect(find.text('Audit Logs'), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);

      // Test log filtering
      await tester.tap(find.byIcon(Icons.filter_list));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Security'));
      await tester.tap(find.text('Apply Filter'));
      await tester.pumpAndSettle();

      // Verify filtered results
      expect(find.textContaining('security'), findsAtLeastOneWidget);
    });

    testWidgets('Error Handling and Recovery', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Simulate network error
      await tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter/platform'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'SystemChrome.setApplicationSwitcherDescription') {
            throw PlatformException(code: 'NETWORK_ERROR', message: 'Connection failed');
          }
          return null;
        },
      );

      // Trigger action that would cause error
      await tester.tap(find.text('Refresh'));
      await tester.pumpAndSettle();

      // Verify error handling
      expect(find.textContaining('Network connection issue'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);

      // Test error recovery
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();

      // Clean up mock
      await tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter/platform'),
        null,
      );
    });

    testWidgets('Cross-Platform Compatibility', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Test responsive design
      await tester.binding.window.physicalSizeTestValue = const Size(800, 600);
      await tester.pumpAndSettle();

      // Verify layout adapts to smaller screen
      expect(find.byType(Drawer), findsOneWidget);

      // Test larger screen
      await tester.binding.window.physicalSizeTestValue = const Size(1920, 1080);
      await tester.pumpAndSettle();

      // Verify layout adapts to larger screen
      expect(find.byType(NavigationRail), findsOneWidget);

      // Reset to default size
      await tester.binding.window.clearPhysicalSizeTestValue();
    });

    testWidgets('Performance Under Load', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      final stopwatch = Stopwatch()..start();

      // Simulate heavy operations
      for (int i = 0; i < 10; i++) {
        // Navigate between screens rapidly
        await tester.tap(find.text('Security'));
        await tester.pumpAndSettle();
        
        await tester.tap(find.text('Team'));
        await tester.pumpAndSettle();
        
        await tester.tap(find.text('Deployments'));
        await tester.pumpAndSettle();
        
        await tester.tap(find.text('Home'));
        await tester.pumpAndSettle();
      }

      stopwatch.stop();

      // Verify performance is acceptable (less than 10 seconds for 40 navigations)
      expect(stopwatch.elapsedMilliseconds, lessThan(10000));

      // Verify app is still responsive
      expect(find.text('DevGuard AI Copilot'), findsOneWidget);
    });
  });

  group('Demo Scenarios', () {
    testWidgets('Demo Scenario 1: Security Threat Detection', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to security dashboard
      await tester.tap(find.text('Security'));
      await tester.pumpAndSettle();

      // Simulate security threat
      await SecurityMonitor.instance.simulateHoneytokenAccess(
        'sk-fake-api-key-12345',
        'unauthorized_api_access',
      );

      await tester.pumpAndSettle();

      // Verify threat detection
      expect(find.textContaining('Security Alert'), findsOneWidget);
      expect(find.textContaining('Honeytoken Access Detected'), findsOneWidget);

      // Test AI copilot explanation
      await tester.tap(find.byIcon(Icons.assistant));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Explain the latest security alert');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(find.textContaining('Security Alert Analysis'), findsOneWidget);
    });

    testWidgets('Demo Scenario 2: Automated Deployment Pipeline', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Create specification for deployment
      await tester.tap(find.text('AI Workflow'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('spec_input')),
        'Deploy the user authentication service to staging environment with automated testing',
      );

      await tester.tap(find.text('Process Specification'));
      await tester.pumpAndSettle();

      // Approve specification
      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      // Navigate to deployments
      await tester.tap(find.text('Deployments'));
      await tester.pumpAndSettle();

      // Verify deployment pipeline is created
      expect(find.textContaining('user-authentication'), findsOneWidget);
      expect(find.textContaining('Staging'), findsOneWidget);
    });

    testWidgets('Demo Scenario 3: Team Collaboration Workflow', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Add team members
      await tester.tap(find.text('Team'));
      await tester.pumpAndSettle();

      // Add developer
      await tester.tap(find.byIcon(Icons.person_add));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('member_name')), 'Alice Developer');
      await tester.enterText(find.byKey(const Key('member_email')), 'alice@example.com');
      await tester.tap(find.text('Developer'));
      await tester.tap(find.text('Add Member'));
      await tester.pumpAndSettle();

      // Add security reviewer
      await tester.tap(find.byIcon(Icons.person_add));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('member_name')), 'Bob Security');
      await tester.enterText(find.byKey(const Key('member_email')), 'bob@example.com');
      await tester.tap(find.text('Security Reviewer'));
      await tester.tap(find.text('Add Member'));
      await tester.pumpAndSettle();

      // Test AI-suggested assignment
      await tester.tap(find.byIcon(Icons.assistant));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '/assign spec-123 alice-id');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(find.textContaining('Assigning specification'), findsOneWidget);
    });

    testWidgets('Demo Scenario 4: Rollback and Recovery', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to deployments
      await tester.tap(find.text('Deployments'));
      await tester.pumpAndSettle();

      // Simulate failed deployment
      await tester.tap(find.text('New Deployment'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('deployment_version')), '1.0.2-broken');
      await tester.tap(find.text('Production'));
      await tester.tap(find.text('Create Deployment'));
      await tester.pumpAndSettle();

      // Simulate deployment failure
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Test rollback via AI copilot
      await tester.tap(find.byIcon(Icons.assistant));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '/rollback production');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(find.textContaining('Rollback Recommendation'), findsOneWidget);
      expect(find.text('Approve Rollback'), findsOneWidget);

      // Approve rollback
      await tester.tap(find.text('Approve Rollback'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Rollback completed'), findsOneWidget);
    });

    testWidgets('Demo Scenario 5: Comprehensive System Overview', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Test system summary via AI copilot
      await tester.tap(find.byIcon(Icons.assistant));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '/summarize');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // Verify comprehensive summary
      expect(find.textContaining('System Summary'), findsOneWidget);
      expect(find.textContaining('Specifications:'), findsOneWidget);
      expect(find.textContaining('Security:'), findsOneWidget);
      expect(find.textContaining('Deployments:'), findsOneWidget);

      // Navigate through all screens to show complete functionality
      final screens = ['Home', 'AI Workflow', 'Security', 'Team', 'Deployments', 'Audit'];
      
      for (final screen in screens) {
        await tester.tap(find.text(screen));
        await tester.pumpAndSettle();
        
        // Verify screen loads successfully
        expect(find.text(screen), findsOneWidget);
        
        // Take a brief pause for demo purposes
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Return to home
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      // Final verification
      expect(find.text('DevGuard AI Copilot'), findsOneWidget);
      expect(find.textContaining('Welcome'), findsOneWidget);
    });
  });
}

/// Helper function to test navigation flow
Future<void> _testNavigationFlow(WidgetTester tester) async {
  final screens = ['AI Workflow', 'Security', 'Team', 'Deployments', 'Audit'];
  
  for (final screen in screens) {
    await tester.tap(find.text(screen));
    await tester.pumpAndSettle();
    expect(find.text(screen), findsOneWidget);
  }
  
  // Return to home
  await tester.tap(find.text('Home'));
  await tester.pumpAndSettle();
}

/// Helper function to test security monitoring
Future<void> _testSecurityMonitoring(WidgetTester tester) async {
  await tester.tap(find.text('Security'));
  await tester.pumpAndSettle();
  
  // Verify security status is displayed
  expect(find.textContaining('Security Status'), findsOneWidget);
  expect(find.textContaining('Monitoring'), findsOneWidget);
}

/// Helper function to test AI copilot interaction
Future<void> _testAICopilotInteraction(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.assistant));
  await tester.pumpAndSettle();
  
  await tester.enterText(find.byType(TextField), 'Hello');
  await tester.tap(find.byIcon(Icons.send));
  await tester.pumpAndSettle();
  
  expect(find.textContaining('DevGuard AI Copilot'), findsOneWidget);
}

/// Helper function to test specification workflow
Future<void> _testSpecificationWorkflow(WidgetTester tester) async {
  await tester.tap(find.text('AI Workflow'));
  await tester.pumpAndSettle();
  
  expect(find.text('Specifications'), findsOneWidget);
}

/// Helper function to test deployment management
Future<void> _testDeploymentManagement(WidgetTester tester) async {
  await tester.tap(find.text('Deployments'));
  await tester.pumpAndSettle();
  
  expect(find.text('Deployment Status'), findsOneWidget);
}

/// Helper function to test audit logging
Future<void> _testAuditLogging(WidgetTester tester) async {
  await tester.tap(find.text('Audit'));
  await tester.pumpAndSettle();
  
  expect(find.text('Audit Logs'), findsOneWidget);
}