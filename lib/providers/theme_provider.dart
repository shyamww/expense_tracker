import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const _themeModeKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.light;
  bool _isReady = false;

  ThemeMode get themeMode => _themeMode;
  bool get isReady => _isReady;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_themeModeKey);
    _themeMode = switch (savedMode) {
      'dark' => ThemeMode.dark,
      _ => ThemeMode.light,
    };
    _isReady = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.name);
    _themeMode = mode;
    notifyListeners();
  }
}
