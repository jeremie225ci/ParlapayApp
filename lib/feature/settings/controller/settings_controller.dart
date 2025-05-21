import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Enumeración para los temas disponibles
enum AppTheme {
  dark,
  light,
  system,
}

// Enumeración para los colores de acento disponibles
enum AccentColor {
  blue,
  green,
  purple,
  orange,
  pink,
  teal,
}

// Clase para almacenar la configuración de la aplicación
class AppSettings {
  final AppTheme theme;
  final AccentColor accentColor;
  final double fontSize;
  final bool useDarkChatBubbles;
  final String chatBackground;

  AppSettings({
    this.theme = AppTheme.dark,
    this.accentColor = AccentColor.blue,
    this.fontSize = 1.0,
    this.useDarkChatBubbles = true,
    this.chatBackground = 'default',
  });

  // Método para crear una copia con cambios
  AppSettings copyWith({
    AppTheme? theme,
    AccentColor? accentColor,
    double? fontSize,
    bool? useDarkChatBubbles,
    String? chatBackground,
  }) {
    return AppSettings(
      theme: theme ?? this.theme,
      accentColor: accentColor ?? this.accentColor,
      fontSize: fontSize ?? this.fontSize,
      useDarkChatBubbles: useDarkChatBubbles ?? this.useDarkChatBubbles,
      chatBackground: chatBackground ?? this.chatBackground,
    );
  }

  // Método para convertir a un mapa para almacenamiento
  Map<String, dynamic> toMap() {
    return {
      'theme': theme.index,
      'accentColor': accentColor.index,
      'fontSize': fontSize,
      'useDarkChatBubbles': useDarkChatBubbles,
      'chatBackground': chatBackground,
    };
  }

  // Método para crear desde un mapa
  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      theme: AppTheme.values[map['theme'] ?? 0],
      accentColor: AccentColor.values[map['accentColor'] ?? 0],
      fontSize: map['fontSize'] ?? 1.0,
      useDarkChatBubbles: map['useDarkChatBubbles'] ?? true,
      chatBackground: map['chatBackground'] ?? 'default',
    );
  }
}

// Controlador de configuración
class SettingsController extends StateNotifier<AppSettings> {
  final SharedPreferences _prefs;

  SettingsController(this._prefs) : super(AppSettings()) {
    _loadSettings();
  }

  // Cargar configuración desde SharedPreferences
  Future<void> _loadSettings() async {
    final themeIndex = _prefs.getInt('theme') ?? 0;
    final accentColorIndex = _prefs.getInt('accentColor') ?? 0;
    final fontSize = _prefs.getDouble('fontSize') ?? 1.0;
    final useDarkChatBubbles = _prefs.getBool('useDarkChatBubbles') ?? true;
    final chatBackground = _prefs.getString('chatBackground') ?? 'default';

    state = AppSettings(
      theme: AppTheme.values[themeIndex],
      accentColor: AccentColor.values[accentColorIndex],
      fontSize: fontSize,
      useDarkChatBubbles: useDarkChatBubbles,
      chatBackground: chatBackground,
    );
  }

  // Guardar configuración en SharedPreferences
  Future<void> _saveSettings() async {
    await _prefs.setInt('theme', state.theme.index);
    await _prefs.setInt('accentColor', state.accentColor.index);
    await _prefs.setDouble('fontSize', state.fontSize);
    await _prefs.setBool('useDarkChatBubbles', state.useDarkChatBubbles);
    await _prefs.setString('chatBackground', state.chatBackground);
  }

  // Cambiar tema
  Future<void> setTheme(AppTheme theme) async {
    state = state.copyWith(theme: theme);
    await _saveSettings();
  }

  // Cambiar color de acento
  Future<void> setAccentColor(AccentColor accentColor) async {
    state = state.copyWith(accentColor: accentColor);
    await _saveSettings();
  }

  // Cambiar tamaño de fuente
  Future<void> setFontSize(double fontSize) async {
    state = state.copyWith(fontSize: fontSize);
    await _saveSettings();
  }

  // Cambiar estilo de burbujas de chat
  Future<void> setUseDarkChatBubbles(bool useDarkChatBubbles) async {
    state = state.copyWith(useDarkChatBubbles: useDarkChatBubbles);
    await _saveSettings();
  }

  // Cambiar fondo de chat
  Future<void> setChatBackground(String chatBackground) async {
    state = state.copyWith(chatBackground: chatBackground);
    await _saveSettings();
  }

  // Restablecer configuración predeterminada
  Future<void> resetSettings() async {
    state = AppSettings();
    await _saveSettings();
  }

  // Obtener ThemeData basado en la configuración actual
  ThemeData getThemeData(BuildContext context) {
    final isDark = state.theme == AppTheme.dark ||
        (state.theme == AppTheme.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    final primaryColor = _getAccentColorValue();

    return isDark
        ? ThemeData.dark().copyWith(
            primaryColor: primaryColor,
            colorScheme: ColorScheme.dark(
              primary: primaryColor,
              secondary: primaryColor,
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: const Color(0xFF1A1A1A),
              elevation: 0,
            ),
            scaffoldBackgroundColor: const Color(0xFF121212),
            cardColor: const Color(0xFF1E1E1E),
          )
        : ThemeData.light().copyWith(
            primaryColor: primaryColor,
            colorScheme: ColorScheme.light(
              primary: primaryColor,
              secondary: primaryColor,
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: primaryColor,
              elevation: 0,
            ),
          );
  }

  // Obtener el valor del color de acento
  Color _getAccentColorValue() {
    switch (state.accentColor) {
      case AccentColor.blue:
        return const Color(0xFF3E63A8);
      case AccentColor.green:
        return Colors.green;
      case AccentColor.purple:
        return Colors.purple;
      case AccentColor.orange:
        return Colors.orange;
      case AccentColor.pink:
        return Colors.pink;
      case AccentColor.teal:
        return Colors.teal;
      default:
        return const Color(0xFF3E63A8);
    }
  }
}

// Proveedor para SharedPreferences
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Debe ser inicializado antes de su uso');
});

// Proveedor para el controlador de configuración
final settingsControllerProvider =
    StateNotifierProvider<SettingsController, AppSettings>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsController(prefs);
});
