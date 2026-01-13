import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';
  static const String _primaryColorKey = 'primary_color';
  static const String _customBgKey = 'custom_bg';

  static const String _lectureColorKey = 'color_lecture';
  static const String _exerciseColorKey = 'color_exercise';
  static const String _labColorKey = 'color_lab';
  static const String _remoteColorKey = 'color_remote';
  static const String _examColorKey = 'color_exam';
  static const String _colloquiumColorKey = 'color_colloquium';

  // Default values
  ThemeMode _themeMode = ThemeMode.light;
  Color _primaryColor = const Color(0xFF6200EE); // Deep Purple
  Color? _customBackgroundColor; // If null, use default for mode

  // Class Colors
  Color _lectureColor = const Color(0xFF03DAC6);
  Color _exerciseColor = Colors.orangeAccent;
  Color _labColor = Colors.blueAccent;
  Color _remoteColor = Colors.blueAccent;
  Color _examColor = Colors.redAccent;
  Color _colloquiumColor = Colors.amberAccent;

  ThemeMode get themeMode => _themeMode;
  Color get primaryColor => _primaryColor;
  Color? get customBackgroundColor => _customBackgroundColor;

  Color get lectureColor => _lectureColor;
  Color get exerciseColor => _exerciseColor;
  Color get labColor => _labColor;
  Color get remoteColor => _remoteColor;
  Color get examColor => _examColor;
  Color get colloquiumColor => _colloquiumColor;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ThemeProvider() {
    _loadPreferences();
  }

  void _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    // Load Mode
    String? modeStr = prefs.getString(_themeModeKey);
    if (modeStr != null) {
      if (modeStr == 'ThemeMode.dark') _themeMode = ThemeMode.dark;
      else if (modeStr == 'ThemeMode.light') _themeMode = ThemeMode.light;
      else _themeMode = ThemeMode.system;
    }

    // Load Primary Color
    int? colorVal = prefs.getInt(_primaryColorKey);
    if (colorVal != null) {
      _primaryColor = Color(colorVal);
    }

    // Load Custom BG
    int? bgVal = prefs.getInt(_customBgKey);
    if (bgVal != null) {
      _customBackgroundColor = Color(bgVal);
    } else {
      _customBackgroundColor = null;
    }

    // Load Class Colors
    _lectureColor = Color(prefs.getInt(_lectureColorKey) ?? 0xFF03DAC6);
    _exerciseColor = Color(prefs.getInt(_exerciseColorKey) ?? Colors.orangeAccent.value);
    _labColor = Color(prefs.getInt(_labColorKey) ?? Colors.blueAccent.value);
    _remoteColor = Color(prefs.getInt(_remoteColorKey) ?? Colors.blueAccent.value);
    _examColor = Color(prefs.getInt(_examColorKey) ?? Colors.redAccent.value);
    _colloquiumColor = Color(prefs.getInt(_colloquiumColorKey) ?? Colors.amberAccent.value);

    notifyListeners();
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, _themeMode.toString());
    await prefs.setInt(_primaryColorKey, _primaryColor.value);

    if (_customBackgroundColor != null) {
      await prefs.setInt(_customBgKey, _customBackgroundColor!.value);
    } else {
      await prefs.remove(_customBgKey);
    }

    await prefs.setInt(_lectureColorKey, _lectureColor.value);
    await prefs.setInt(_exerciseColorKey, _exerciseColor.value);
    await prefs.setInt(_labColorKey, _labColor.value);
    await prefs.setInt(_remoteColorKey, _remoteColor.value);
    await prefs.setInt(_examColorKey, _examColor.value);
    await prefs.setInt(_colloquiumColorKey, _colloquiumColor.value);
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    // Reset custom background when changing mode manually to avoid "Black on Black" issues with presets
    _customBackgroundColor = null;
    _savePreferences();
    notifyListeners();
  }

  void setLectureColor(Color color) { _lectureColor = color; _savePreferences(); notifyListeners(); }
  void setExerciseColor(Color color) { _exerciseColor = color; _savePreferences(); notifyListeners(); }
  void setLabColor(Color color) { _labColor = color; _savePreferences(); notifyListeners(); }
  void setRemoteColor(Color color) { _remoteColor = color; _savePreferences(); notifyListeners(); }
  void setExamColor(Color color) { _examColor = color; _savePreferences(); notifyListeners(); }
  void setColloquiumColor(Color color) { _colloquiumColor = color; _savePreferences(); notifyListeners(); }

  void setPrimaryColor(Color color) {
    _primaryColor = color;
    _savePreferences();
    notifyListeners();
  }

  // --- PRESETS LOGIC ---

  void applyPreset(AppPreset preset) {
    _themeMode = preset.mode;
    _primaryColor = preset.primaryColor;
    _customBackgroundColor = preset.backgroundColor; // Might be null

    _savePreferences();
    notifyListeners();
  }

  ThemeData get currentThemeData {
    bool isDark;
    if (_themeMode == ThemeMode.system) {
      isDark = SchedulerBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    } else {
      isDark = _themeMode == ThemeMode.dark;
    }

    // Base colors
    Color surface = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    Color scaffoldBg = _customBackgroundColor ?? (isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5));
    Color onSurface = isDark ? Colors.white : Colors.black;

    // Create ColorScheme
    ColorScheme scheme = isDark
      ? ColorScheme.dark(primary: _primaryColor, surface: surface, onSurface: onSurface)
      : ColorScheme.light(primary: _primaryColor, surface: surface, onSurface: onSurface);

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      primaryColor: _primaryColor,
      scaffoldBackgroundColor: scaffoldBg,
      cardColor: surface,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
      ),
      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: isDark ? Colors.black : Colors.white,
        ),
      ),
    );
  }
}

class AppPreset {
  final String name;
  final ThemeMode mode;
  final Color primaryColor;
  final Color? backgroundColor; // Optional override
  final IconData icon;

  const AppPreset({
    required this.name,
    required this.mode,
    required this.primaryColor,
    this.backgroundColor,
    required this.icon,
  });
}

// --- DEFINED PRESETS ---
final List<AppPreset> appPresets = [
  const AppPreset(
    name: "Domyślny (Jasny)",
    mode: ThemeMode.light,
    primaryColor: Color(0xFF6200EE),
    icon: Icons.wb_sunny,
  ),
  const AppPreset(
    name: "Ciemny (Oryginał)",
    mode: ThemeMode.dark,
    primaryColor: Color(0xFFBB86FC),
    backgroundColor: Color(0xFF121212),
    icon: Icons.nightlight_round,
  ),
  const AppPreset(
    name: "Morski",
    mode: ThemeMode.light,
    primaryColor: Colors.teal,
    backgroundColor: Color(0xFFE0F7FA),
    icon: Icons.water,
  ),
  const AppPreset(
    name: "Leśny",
    mode: ThemeMode.dark,
    primaryColor: Colors.lightGreenAccent,
    backgroundColor: Color(0xFF1B2E1B),
    icon: Icons.forest,
  ),
  const AppPreset(
    name: "Cyberpunk",
    mode: ThemeMode.dark,
    primaryColor: Colors.pinkAccent,
    backgroundColor: Color(0xFF0D0221),
    icon: Icons.electrical_services,
  ),
  const AppPreset(
    name: "Minimalist",
    mode: ThemeMode.light,
    primaryColor: Colors.black,
    backgroundColor: Colors.white,
    icon: Icons.check_box_outline_blank,
  ),
];
