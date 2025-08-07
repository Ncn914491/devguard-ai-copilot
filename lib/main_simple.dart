import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logging/logging.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/theme/app_theme.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/app_state_provider.dart';
import 'core/supabase/supabase_service.dart';
import 'presentation/screens/main_screen.dart';
import 'presentation/screens/landing_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Warning: Could not load .env file: $e');
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
    logger.info('Initializing services...');

    // Initialize Supabase backend
    try {
      await SupabaseService.instance.initialize();
      logger.info('✓ Supabase initialized');
    } catch (e) {
      logger.warning('⚠️  Supabase initialization failed: $e');
      // Continue without Supabase for now
    }

    logger.info('✓ All services initialized successfully');
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
