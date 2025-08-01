import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import '../../presentation/screens/main_screen.dart';
import '../../presentation/screens/home_screen.dart';
import '../../presentation/screens/workflow_screen.dart';
import '../../presentation/screens/security_screen.dart';
import '../../presentation/screens/deployments_screen.dart';
import '../../presentation/screens/settings_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return MainScreen(child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            name: 'home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/workflow',
            name: 'workflow',
            builder: (context, state) => const WorkflowScreen(),
          ),
          GoRoute(
            path: '/security',
            name: 'security',
            builder: (context, state) => const SecurityScreen(),
          ),
          GoRoute(
            path: '/deployments',
            name: 'deployments',
            builder: (context, state) => const DeploymentsScreen(),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
}