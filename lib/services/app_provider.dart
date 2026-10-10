import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_service.dart';

class AppProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  Map<String, dynamic> _organization = FirebaseService.organization;

  ThemeMode get themeMode => _themeMode;
  Map<String, dynamic> get organization => _organization;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  AppProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDark');
    if (isDark != null) {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
      notifyListeners();
    }
  }

  Future<void> toggleTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDark', isDark);
    notifyListeners();
  }

  Future<void> reloadOrganization() async {
    await FirebaseService.instance.fetchOrganization();
    _organization = FirebaseService.organization;
    notifyListeners();
  }
}
