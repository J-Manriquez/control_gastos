import 'package:control_gastos/models/colors_model.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ColorProvider extends ChangeNotifier {
  AppColorsModel colors = AppColorsModel();
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  // Constructor que carga los colores al iniciar
  ColorProvider() {
    loadColors();
  }

  // Cargar colores de SharedPreferences o utilizar valores por defecto
  Future<void> loadColors() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Cargar preferencia de modo oscuro
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    
    // Aplicar tema según la preferencia guardada
    if (_isDarkMode) {
      colors = AppColorsModel.dark();
    } else {
      colors = AppColorsModel();
    }
    
    // Cargar colores personalizados si existen (mantener compatibilidad)
    colors.backgroundColor = Color(prefs.getInt('backgroundColor') ?? colors.backgroundColor.value);
    colors.appBarColor = Color(prefs.getInt('appBarColor') ?? colors.appBarColor.value);
    colors.primaryTextColor = Color(prefs.getInt('primaryTextColor') ?? colors.primaryTextColor.value);
    colors.secondaryTextColor = Color(prefs.getInt('secondaryTextColor') ?? colors.secondaryTextColor.value);
    colors.positiveColor = Color(prefs.getInt('positiveColor') ?? colors.positiveColor.value);
    colors.negativeColor = Color(prefs.getInt('negativeColor') ?? colors.negativeColor.value);

    notifyListeners(); // Notifica a todos los widgets para actualizar los colores
  }

  // Guardar color en SharedPreferences y actualizar el modelo
  Future<void> setColor(String key, Color color) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt(key, color.value);

    // Actualizamos el color en el modelo
    switch (key) {
      case 'backgroundColor':
        colors.backgroundColor = color;
        break;
      case 'appBarColor':
        colors.appBarColor = color;
        break;
      case 'primaryTextColor':
        colors.primaryTextColor = color;
        break;
      case 'secondaryTextColor':
        colors.secondaryTextColor = color;
        break;
      case 'positiveColor':
        colors.positiveColor = color;
        break;
      case 'negativeColor':
        colors.negativeColor = color;
        break;
    }

    notifyListeners(); // Notifica a todos los widgets para aplicar el cambio
  }

  // Alternar entre modo claro y oscuro
  Future<void> toggleDarkMode() async {
    _isDarkMode = !_isDarkMode;
    await _saveDarkModePreference();
    await _applyTheme();
    notifyListeners();
  }

  // Establecer modo oscuro específicamente
  Future<void> setDarkMode(bool isDark) async {
    if (_isDarkMode != isDark) {
      _isDarkMode = isDark;
      await _saveDarkModePreference();
      await _applyTheme();
      notifyListeners();
    }
  }

  // Guardar preferencia de modo oscuro
  Future<void> _saveDarkModePreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
  }

  // Aplicar tema según el modo actual
  Future<void> _applyTheme() async {
    if (_isDarkMode) {
      colors = AppColorsModel.dark();
    } else {
      colors = AppColorsModel();
    }
  }
}
