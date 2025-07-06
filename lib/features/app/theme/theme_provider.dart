import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  late SharedPreferences _prefs;
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final savedTheme = _prefs.getString(_themeKey);
      print('Loading theme: savedTheme = $savedTheme');
      if (savedTheme != null) {
        _themeMode = savedTheme == 'dark' ? ThemeMode.dark : ThemeMode.light;
        print('Theme loaded: $_themeMode');
        notifyListeners();
      } else {
        print('No saved theme found, using default: $_themeMode');
      }
    } catch (e) {
      print('Error loading theme: $e');
    }
  }

  Future<void> toggleTheme() async {
    try {
      _themeMode =
          _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
      print('Toggling theme to: $_themeMode');
      await _prefs.setString(
          _themeKey, _themeMode == ThemeMode.dark ? 'dark' : 'light');
      print('Theme saved successfully');
      notifyListeners();
    } catch (e) {
      print('Error saving theme: $e');
    }
  }
}
