import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/app_state_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../widgets/top_bar.dart';
import '../widgets/left_sidebar.dart';
import '../widgets/copilot_sidebar.dart';

class MainScreen extends StatelessWidget {
  final Widget child;
  
  const MainScreen({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<AppStateProvider>(
        builder: (context, appState, _) {
          return Column(
            children: [
              // Top Bar
              const TopBar(),
              
              // Main Content Area
              Expanded(
                child: Row(
                  children: [
                    // Left Sidebar
                    if (!appState.isLeftSidebarCollapsed) const LeftSidebar(),
                    
                    // Main Canvas
                    Expanded(
                      child: Container(
                        color: Theme.of(context).colorScheme.background,
                        child: child,
                      ),
                    ),
                    
                    // Right Sidebar (Copilot)
                    const CopilotSidebar(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}