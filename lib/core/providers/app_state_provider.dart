import 'package:flutter/foundation.dart';

class AppStateProvider extends ChangeNotifier {
  String _currentScreen = 'home';
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic> _appData = {};

  // Getters
  String get currentScreen => _currentScreen;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic> get appData => _appData;

  // Navigation
  void setCurrentScreen(String screen) {
    if (_currentScreen != screen) {
      _currentScreen = screen;
      notifyListeners();
    }
  }

  // Loading state
  void setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  // Error handling
  void setError(String? error) {
    if (_error != error) {
      _error = error;
      notifyListeners();
    }
  }

  void clearError() {
    setError(null);
  }

  // App data management
  void updateAppData(String key, dynamic value) {
    _appData[key] = value;
    notifyListeners();
  }

  T? getAppData<T>(String key) {
    return _appData[key] as T?;
  }

  void clearAppData() {
    _appData.clear();
    notifyListeners();
  }

  // Utility methods
  void showError(String message) {
    setError(message);
    // Auto-clear error after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (_error == message) {
        clearError();
      }
    });
  }

  Future<T> executeWithLoading<T>(Future<T> Function() operation) async {
    setLoading(true);
    clearError();
    
    try {
      final result = await operation();
      return result;
    } catch (e) {
      setError(e.toString());
      rethrow;
    } finally {
      setLoading(false);
    }
  }
}