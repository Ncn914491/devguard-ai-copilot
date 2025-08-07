#!/usr/bin/env dart

import 'dart:io';
import 'dart:convert';

/// Environment validation script for DevGuard AI Copilot
/// Checks for required environment variables and configuration
void main(List<String> args) async {
  print('🔍 DevGuard AI Copilot - Environment Validation');
  print('=' * 50);

  bool allValid = true;

  // Check for .env file
  final envFile = File('.env');
  if (!envFile.existsSync()) {
    print('❌ .env file not found');
    print('   Create .env file from .env.example template');
    allValid = false;
  } else {
    print('✅ .env file found');
    await _validateEnvFile(envFile);
  }

  // Check Flutter dependencies
  await _checkFlutterDependencies();

  // Check platform-specific requirements
  await _checkPlatformRequirements();

  // Check database setup
  await _checkDatabaseSetup();

  print('\n' + '=' * 50);
  if (allValid) {
    print('✅ Environment validation passed!');
    print('🚀 Ready to run: flutter run');
  } else {
    print('❌ Environment validation failed!');
    print('📋 Please fix the issues above before running the app');
    exit(1);
  }
}

Future<void> _validateEnvFile(File envFile) async {
  final content = await envFile.readAsString();
  final lines = content.split('\n');

  final requiredVars = [
    'SUPABASE_URL',
    'SUPABASE_ANON_KEY',
    'GITHUB_CLIENT_ID',
    'GITHUB_CLIENT_SECRET',
    'GEMINI_API_KEY',
  ];

  final optionalVars = [
    'SUPABASE_SERVICE_ROLE_KEY',
    'EMAIL_SMTP_HOST',
    'EMAIL_USERNAME',
    'ENABLE_OAUTH',
    'ENABLE_DEMO_MODE',
  ];

  print('\n📋 Environment Variables:');

  for (final varName in requiredVars) {
    final found = lines.any((line) => line.startsWith('$varName='));
    if (found) {
      final value = lines
          .firstWhere((line) => line.startsWith('$varName='))
          .split('=')[1];
      if (value.isEmpty ||
          value.startsWith('your_') ||
          value.startsWith('demo_')) {
        print('⚠️  $varName: Set to demo/placeholder value');
      } else {
        print('✅ $varName: Configured');
      }
    } else {
      print('❌ $varName: Missing (required)');
    }
  }

  for (final varName in optionalVars) {
    final found = lines.any((line) => line.startsWith('$varName='));
    if (found) {
      print('✅ $varName: Configured (optional)');
    } else {
      print('ℹ️  $varName: Not set (optional)');
    }
  }
}

Future<void> _checkFlutterDependencies() async {
  print('\n📦 Flutter Dependencies:');

  try {
    final result = await Process.run('flutter', ['pub', 'deps', '--json']);
    if (result.exitCode == 0) {
      print('✅ Flutter dependencies resolved');
    } else {
      print('❌ Flutter dependencies have issues');
      print('   Run: flutter pub get');
    }
  } catch (e) {
    print('❌ Flutter not found in PATH');
    print('   Install Flutter: https://flutter.dev/docs/get-started/install');
  }
}

Future<void> _checkPlatformRequirements() async {
  print('\n🖥️  Platform Requirements:');

  // Check for web support
  try {
    final result = await Process.run('flutter', ['config', '--list']);
    if (result.stdout.toString().contains('enable-web: true')) {
      print('✅ Flutter web support enabled');
    } else {
      print('⚠️  Flutter web support disabled');
      print('   Enable with: flutter config --enable-web');
    }
  } catch (e) {
    print('❌ Could not check Flutter web support');
  }

  // Check for Windows support (if on Windows)
  if (Platform.isWindows) {
    try {
      final result = await Process.run('flutter', ['config', '--list']);
      if (result.stdout.toString().contains('enable-windows-desktop: true')) {
        print('✅ Flutter Windows desktop support enabled');
      } else {
        print('⚠️  Flutter Windows desktop support disabled');
        print('   Enable with: flutter config --enable-windows-desktop');
      }
    } catch (e) {
      print('❌ Could not check Flutter Windows support');
    }
  }
}

Future<void> _checkDatabaseSetup() async {
  print('\n🗄️  Database Setup:');

  // Check for Supabase migration files
  final supabaseMigrationsDir = Directory('lib/core/supabase/migrations');
  if (supabaseMigrationsDir.existsSync()) {
    final migrations = supabaseMigrationsDir
        .listSync()
        .where((file) => file.path.endsWith('.sql'))
        .length;
    print('✅ Found $migrations Supabase migration files');
  } else {
    print('⚠️  No Supabase migrations directory found');
  }

  // Check for legacy SQLite database (should be migrated)
  final dbFile = File('./devguard.db');
  if (dbFile.existsSync()) {
    print('⚠️  Legacy SQLite database found - consider migrating to Supabase');
  } else {
    print('✅ No legacy SQLite database found');
  }
}
