import 'package:flutter/material.dart';

enum AppSection {
  home,
  security,
  deployments,
  settings,
}

class AppStateProvider extends ChangeNotifier {
  AppSection _currentSection = AppSection.home;
  bool _isCopilotExpanded = false;
  bool _isLeftSidebarCollapsed = false;
  
  AppSection get currentSection => _currentSection;
  bool get isCopilotExpanded => _isCopilotExpanded;
  bool get isLeftSidebarCollapsed => _isLeftSidebarCollapsed;
  
  void setCurrentSection(AppSection section) {
    _currentSection = section;
    notifyListeners();
  }
  
  void toggleCopilot() {
    _isCopilotExpanded = !_isCopilotExpanded;
    notifyListeners();
  }
  
  void setCopilotExpanded(bool expanded) {
    _isCopilotExpanded = expanded;
    notifyListeners();
  }
  
  void toggleLeftSidebar() {
    _isLeftSidebarCollapsed = !_isLeftSidebarCollapsed;
    notifyListeners();
  }
  
  void setLeftSidebarCollapsed(bool collapsed) {
    _isLeftSidebarCollapsed = collapsed;
    notifyListeners();
  }
}