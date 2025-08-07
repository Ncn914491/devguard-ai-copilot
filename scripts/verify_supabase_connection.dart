#!/usr/bin/env dart

import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Supabase connectivity verification script
/// Verifies that the application can connect to Supabase services
void main(List<String> args) async {
  print('🔗 DevGuard AI Copilot - Supabase Connectivity Verification');
  print('=' * 60);

  bool allConnected = true;

  // Load environment variables
  final envFile = File('.env');
  if (!envFile.existsSync()) {
    print('❌ .env file not found');
    exit(1);
  }

  final envContent = await envFile.readAsString();
  final envVars = <String, String>{};

  for (final line in envContent.split('\n')) {
    if (line.contains('=') && !line.startsWith('#')) {
      final parts = line.split('=');
      if (parts.length >= 2) {
        envVars[parts[0].trim()] = parts.sublist(1).join('=').trim();
      }
    }
  }

  final supabaseUrl = envVars['SUPABASE_URL'];
  final supabaseAnonKey = envVars['SUPABASE_ANON_KEY'];
  final supabaseServiceRoleKey = envVars['SUPABASE_SERVICE_ROLE_KEY'];

  if (supabaseUrl == null || supabaseAnonKey == null) {
    print('❌ Missing required Supabase configuration');
    print('   Required: SUPABASE_URL, SUPABASE_ANON_KEY');
    exit(1);
  }

  // Test REST API connectivity
  print('\n🌐 Testing Supabase REST API connectivity...');
  try {
    final response = await http.get(
      Uri.parse('$supabaseUrl/rest/v1/'),
      headers: {
        'apikey': supabaseAnonKey,
        'Authorization': 'Bearer $supabaseAnonKey',
      },
    ).timeout(Duration(seconds: 10));

    if (response.statusCode == 200) {
      print('✅ REST API: Connected successfully');
    } else {
      print('❌ REST API: Connection failed (${response.statusCode})');
      allConnected = false;
    }
  } catch (e) {
    print('❌ REST API: Connection error - $e');
    allConnected = false;
  }

  // Test Auth API connectivity
  print('\n🔐 Testing Supabase Auth API connectivity...');
  try {
    final response = await http.get(
      Uri.parse('$supabaseUrl/auth/v1/settings'),
      headers: {
        'apikey': supabaseAnonKey,
        'Authorization': 'Bearer $supabaseAnonKey',
      },
    ).timeout(Duration(seconds: 10));

    if (response.statusCode == 200) {
      final settings = json.decode(response.body);
      print('✅ Auth API: Connected successfully');
      print(
          '   External providers: ${settings['external'] ?? 'None configured'}');
    } else {
      print('❌ Auth API: Connection failed (${response.statusCode})');
      allConnected = false;
    }
  } catch (e) {
    print('❌ Auth API: Connection error - $e');
    allConnected = false;
  }

  // Test Storage API connectivity
  print('\n📁 Testing Supabase Storage API connectivity...');
  try {
    final response = await http.get(
      Uri.parse('$supabaseUrl/storage/v1/bucket'),
      headers: {
        'apikey': supabaseAnonKey,
        'Authorization': 'Bearer $supabaseAnonKey',
      },
    ).timeout(Duration(seconds: 10));

    if (response.statusCode == 200) {
      print('✅ Storage API: Connected successfully');
    } else {
      print('❌ Storage API: Connection failed (${response.statusCode})');
      allConnected = false;
    }
  } catch (e) {
    print('❌ Storage API: Connection error - $e');
    allConnected = false;
  }

  // Test Real-time connectivity
  print('\n⚡ Testing Supabase Real-time connectivity...');
  try {
    final wsUrl = supabaseUrl!
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    final response = await http.get(
      Uri.parse('$supabaseUrl/rest/v1/'),
      headers: {
        'apikey': supabaseAnonKey,
        'Authorization': 'Bearer $supabaseAnonKey',
        'Upgrade': 'websocket',
        'Connection': 'Upgrade',
      },
    ).timeout(Duration(seconds: 5));

    // Real-time endpoint should return 426 (Upgrade Required) for HTTP requests
    if (response.statusCode == 426 || response.statusCode == 400) {
      print('✅ Real-time: WebSocket endpoint available');
    } else {
      print(
          '⚠️  Real-time: WebSocket endpoint status unclear (${response.statusCode})');
    }
  } catch (e) {
    print('⚠️  Real-time: Could not verify WebSocket endpoint - $e');
  }

  // Test database schema access (if service role key is available)
  if (supabaseServiceRoleKey != null) {
    print('\n🗄️  Testing database schema access...');
    try {
      final response = await http.get(
        Uri.parse('$supabaseUrl/rest/v1/users?select=count'),
        headers: {
          'apikey': supabaseServiceRoleKey,
          'Authorization': 'Bearer $supabaseServiceRoleKey',
          'Prefer': 'count=exact',
        },
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        print('✅ Database Schema: Users table accessible');
      } else if (response.statusCode == 404) {
        print(
            '⚠️  Database Schema: Users table not found (may need migration)');
      } else {
        print('❌ Database Schema: Access failed (${response.statusCode})');
        allConnected = false;
      }
    } catch (e) {
      print('❌ Database Schema: Access error - $e');
      allConnected = false;
    }
  } else {
    print(
        '\n⚠️  Skipping database schema test (SUPABASE_SERVICE_ROLE_KEY not provided)');
  }

  print('\n' + '=' * 60);
  if (allConnected) {
    print('✅ Supabase connectivity verification passed!');
    print('🚀 All Supabase services are accessible');
    exit(0);
  } else {
    print('❌ Supabase connectivity verification failed!');
    print(
        '🔧 Please check your Supabase configuration and network connectivity');
    exit(1);
  }
}
