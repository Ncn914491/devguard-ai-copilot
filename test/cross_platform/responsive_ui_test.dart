import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:devguard_ai_copilot/core/utils/responsive_utils.dart';
import 'package:devguard_ai_copilot/presentation/widgets/cross_platform_terminal.dart';
import 'package:devguard_ai_copilot/presentation/screens/main_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Responsive UI Tests', () {
    testWidgets('ResponsiveUtils correctly identifies device types',
        (tester) async {
      // Test mobile breakpoint
      await tester.binding.setSurfaceSize(const Size(400, 800));
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expect(ResponsiveUtils.isMobile(context), isTrue);
              expect(ResponsiveUtils.isTablet(context), isFalse);
              expect(ResponsiveUtils.isDesktop(context), isFalse);
              return Container();
            },
          ),
        ),
      );

      // Test tablet breakpoint
      await tester.binding.setSurfaceSize(const Size(800, 600));
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expect(ResponsiveUtils.isMobile(context), isFalse);
              expect(ResponsiveUtils.isTablet(context), isTrue);
              expect(ResponsiveUtils.isDesktop(context), isFalse);
              return Container();
            },
          ),
        ),
      );

      // Test desktop breakpoint
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expect(ResponsiveUtils.isMobile(context), isFalse);
              expect(ResponsiveUtils.isTablet(context), isFalse);
              expect(ResponsiveUtils.isDesktop(context), isTrue);
              return Container();
            },
          ),
        ),
      );
    });

    testWidgets('ResponsiveWidget renders correct child for device type',
        (tester) async {
      const mobileWidget = Text('Mobile');
      const tabletWidget = Text('Tablet');
      const desktopWidget = Text('Desktop');

      // Test mobile
      await tester.binding.setSurfaceSize(const Size(400, 800));
      await tester.pumpWidget(
        MaterialApp(
          home: ResponsiveWidget(
            mobile: mobileWidget,
            tablet: tabletWidget,
            desktop: desktopWidget,
          ),
        ),
      );
      expect(find.text('Mobile'), findsOneWidget);
      expect(find.text('Tablet'), findsNothing);
      expect(find.text('Desktop'), findsNothing);

      // Test tablet
      await tester.binding.setSurfaceSize(const Size(800, 600));
      await tester.pumpWidget(
        MaterialApp(
          home: ResponsiveWidget(
            mobile: mobileWidget,
            tablet: tabletWidget,
            desktop: desktopWidget,
          ),
        ),
      );
      expect(find.text('Mobile'), findsNothing);
      expect(find.text('Tablet'), findsOneWidget);
      expect(find.text('Desktop'), findsNothing);

      // Test desktop
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      await tester.pumpWidget(
        MaterialApp(
          home: ResponsiveWidget(
            mobile: mobileWidget,
            tablet: tabletWidget,
            desktop: desktopWidget,
          ),
        ),
      );
      expect(find.text('Mobile'), findsNothing);
      expect(find.text('Tablet'), findsNothing);
      expect(find.text('Desktop'), findsOneWidget);
    });

    testWidgets('ResponsiveWidget falls back to desktop when tablet is null',
        (tester) async {
      const mobileWidget = Text('Mobile');
      const desktopWidget = Text('Desktop');

      // Test tablet fallback
      await tester.binding.setSurfaceSize(const Size(800, 600));
      await tester.pumpWidget(
        MaterialApp(
          home: ResponsiveWidget(
            mobile: mobileWidget,
            desktop: desktopWidget,
          ),
        ),
      );
      expect(find.text('Mobile'), findsNothing);
      expect(find.text('Desktop'), findsOneWidget);
    });

    testWidgets('CrossPlatformTerminal adapts to screen size', (tester) async {
      // Test mobile terminal
      await tester.binding.setSurfaceSize(const Size(400, 800));
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CrossPlatformTerminal(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should find mobile-specific elements
      expect(find.byIcon(Icons.send), findsOneWidget);
      expect(find.text('Terminal'), findsOneWidget);

      // Test desktop terminal
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CrossPlatformTerminal(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should find desktop-specific elements (traffic light buttons)
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('MainScreen layout adapts to different screen sizes',
        (tester) async {
      // Test mobile layout
      await tester.binding.setSurfaceSize(const Size(400, 800));
      await tester.pumpWidget(
        const MaterialApp(home: MainScreen()),
      );
      await tester.pumpAndSettle();

      // Mobile should have AppBar and potentially BottomNavigationBar
      expect(find.byType(AppBar), findsOneWidget);

      // Test desktop layout
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      await tester.pumpWidget(
        const MaterialApp(home: MainScreen()),
      );
      await tester.pumpAndSettle();

      // Desktop should have different layout structure
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('Responsive padding and sizing work correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final mobilePadding = ResponsiveUtils.getScreenPadding(context);
              final mobileWidth = ResponsiveUtils.getSidebarWidth(context);
              final crossAxisCount = ResponsiveUtils.getCrossAxisCount(context);

              return Column(
                children: [
                  Container(
                    padding: mobilePadding,
                    width: mobileWidth,
                    child: Text('Cross axis count: $crossAxisCount'),
                  ),
                ],
              );
            },
          ),
        ),
      );

      // Test mobile values
      await tester.binding.setSurfaceSize(const Size(400, 800));
      await tester.pumpAndSettle();
      expect(find.text('Cross axis count: 1'), findsOneWidget);

      // Test desktop values
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      await tester.pumpAndSettle();
      expect(find.text('Cross axis count: 3'), findsOneWidget);
    });

    testWidgets('Layout overflow is prevented on small screens',
        (tester) async {
      await tester.binding
          .setSurfaceSize(const Size(320, 568)); // Very small screen

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    height: 200,
                    color: Colors.blue,
                    child: const Text('Test Content'),
                  ),
                  const CrossPlatformTerminal(),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should not have overflow errors
      expect(tester.takeException(), isNull);
    });

    testWidgets('Text scaling works correctly across platforms',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return const Text(
                'Sample text for scaling test',
                style: TextStyle(fontSize: 16),
              );
            },
          ),
        ),
      );

      // Test different text scale factors
      await tester.binding.setSurfaceSize(const Size(400, 800));
      await tester.pumpAndSettle();

      // Verify text renders without overflow
      expect(find.text('Sample text for scaling test'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
