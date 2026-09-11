import 'package:flutter/material.dart';
import '../../app/constants/theme.dart';

class ThemeController extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  Color _primaryColor = AppColors.primary;
  Color _secondaryColor = AppColors.secondary;
  int _selectedPaletteIndex = 0;

  ThemeMode get themeMode => _themeMode;
  Color get primaryColor => _primaryColor;
  Color get secondaryColor => _secondaryColor;
  int get selectedPaletteIndex => _selectedPaletteIndex;

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
  }

  void setPalette({
    required int index,
    required Color primary,
    required Color secondary,
  }) {
    _selectedPaletteIndex = index;
    _primaryColor = primary;
    _secondaryColor = secondary;
    notifyListeners();
  }
}

final themeController = ThemeController();
