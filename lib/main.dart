import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logging/logging.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/theme/app_theme.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/app_state_provider.dart';
import 'core/database/database_service.dart';
import 'core/ai/gemini_service.dart';
import 'core/security/security_monitor.dart';
import 'core/services/onboarding_service.dart';
import 'core/services/project_service_fast.dart';
import 'core/services/performance_integration_service.dart';
import 'core/services/cross_platform_storage_service.dart';
import 'core/utils/platform_utils.dart';
import 'presentation/screens/main_screen.dart';
import 'presentation/screens/landing_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Warning: Could not load .env file: $e');
    // Continue without .env file - use environment variables or defaults
  }

  // Setup logging
  _setupLogging();

  // Initialize core services
  await _initializeServices();

  runApp(const DevGuardApp());
}

void _setupLogging() {
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
    if (record.error != null) {
      debugPrint('Error: ${record.error}');
    }
    if (record.stackTrace != null) {
      debugPrint('Stack trace: ${record.stackTrace}');
    }
  });
}

Future<void> _initializeServices() async {
  final logger = Logger('ServiceInitialization');

  try {
    logger.info('Initializing services for ${PlatformUtils.platformName}...');

    // Initialize cross-platform storage first
    await CrossPlatformStorageService.instance.initialize();
    logger.info('✓ Cross-platform storage initialized');

    // Initialize database with platform-specific configuration
    await DatabaseService.instance.initialize();
    logger.info('✓ Database initialized');

    // Initialize AI service with API key from environment
    final apiKey = dotenv.env['GEMINI_API_KEY'] ??
        const String.fromEnvironment('GEMINI_API_KEY');
    await GeminiService.instance
        .initialize(apiKey: apiKey.isNotEmpty ? apiKey : null);
    logger.info('✓ AI service initialized');

    // Initialize security monitoring
    await SecurityMonitor.instance.initialize();
    logger.info('✓ Security monitoring initialized');

    // Initialize onboarding service
    await OnboardingService.instance.initialize();
    logger.info('✓ Onboarding service initialized');

    // Initialize project service
    await ProjectService.instance.initialize();
    logger.info('✓ Project service initialized');

    // Initialize performance optimization services
    await PerformanceIntegrationService.instance.initializeAllServices();
    logger.info('✓ Performance optimization services initialized');

    logger.info(
        '✓ All services initialized successfully for ${PlatformUtils.platformName}');
  } catch (e, stackTrace) {
    logger.severe('❌ Service initialization failed: $e', e, stackTrace);
    // Continue with limited functionality
  }
}

class DevGuardApp extends StatelessWidget {
  const DevGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AppStateProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return ScreenUtilInit(
            designSize: const Size(1920, 1080), // Design reference size
            minTextAdapt: true,
            splitScreenMode: true,
            builder: (context, child) {
              return MaterialApp(
                title: 'DevGuard AI Copilot',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: themeProvider.themeMode,
                home: const LandingScreen(),
                routes: {
                  '/main': (context) => const MainScreen(),
                  '/landing': (context) => const LandingScreen(),
                },
              );
            },
          );
        },
      ),
    );
  }
}
