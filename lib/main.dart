import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/app_state_provider.dart';
import 'core/database/database_service.dart';
import 'core/ai/gemini_service.dart';
import 'core/security/security_monitor.dart';
import 'core/services/onboarding_service.dart';
import 'core/services/project_service.dart';
import 'presentation/screens/main_screen.dart';
import 'presentation/screens/landing_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize core services
  await _initializeServices();
  
  runApp(const DevGuardApp());
}

Future<void> _initializeServices() async {
  try {
    // Initialize database first
    await DatabaseService.instance.initialize();
    print('✓ Database initialized');
    
    // Initialize AI service with API key from environment
    const apiKey = String.fromEnvironment('GEMINI_API_KEY');
    await GeminiService.instance.initialize(apiKey: apiKey.isNotEmpty ? apiKey : null);
    print('✓ AI service initialized');
    
    // Initialize security monitoring
    await SecurityMonitor.instance.initialize();
    print('✓ Security monitoring initialized');
    
    // Initialize onboarding service
    await OnboardingService.instance.initialize();
    print('✓ Onboarding service initialized');
    
    // Initialize project service
    await ProjectService.instance.initialize();
    print('✓ Project service initialized');
    
    print('✓ All services initialized successfully');
  } catch (e) {
    print('❌ Service initialization failed: $e');
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
      ),
    );
  }
}