import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mk_mesenger/common/utils/colors.dart';
import 'package:mk_mesenger/feature/settings/controller/settings_controller.dart';

class AppThemeScreen extends ConsumerStatefulWidget {
  static const String routeName = '/app-theme';

  const AppThemeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AppThemeScreen> createState() => _AppThemeScreenState();
}

class _AppThemeScreenState extends ConsumerState<AppThemeScreen> {
  late String _selectedTheme;
  late String _selectedAccentColor;
  late double _fontSize;
  late bool _useDarkChatBubbles;

  @override
  void initState() {
    super.initState();
    // Inicializar con valores predeterminados o guardados
    _selectedTheme = 'dark';
    _selectedAccentColor = 'blue';
    _fontSize = 1.0; // Escala normal
    _useDarkChatBubbles = true;
  }

  void _saveThemeSettings() {
    // Implementar guardado de configuración
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Configuración guardada'),
        backgroundColor: accentColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        title: const Text(
          'Personalización',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saveThemeSettings,
            child: Text(
              'Guardar',
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Previsualización
              _buildThemePreview(),
              
              const SizedBox(height: 24),
              
              // Selección de tema
              _buildSettingsSection(
                title: 'Tema',
                children: [
                  _buildThemeSelector(),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Selección de color de acento
              _buildSettingsSection(
                title: 'Color de acento',
                children: [
                  _buildAccentColorSelector(),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Tamaño de fuente
              _buildSettingsSection(
                title: 'Tamaño de texto',
                children: [
                  _buildFontSizeSelector(),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Opciones adicionales
              _buildSettingsSection(
                title: 'Opciones adicionales',
                children: [
                  _buildAdditionalOptions(),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Botón de restablecer
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedTheme = 'dark';
                      _selectedAccentColor = 'blue';
                      _fontSize = 1.0;
                      _useDarkChatBubbles = true;
                    });
                  },
                  icon: Icon(Icons.refresh, color: accentColor),
                  label: Text(
                    'Restablecer valores predeterminados',
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemePreview() {
    final isDark = _selectedTheme == 'dark';
    final previewBackgroundColor = isDark ? Color(0xFF121212) : Colors.white;
    final previewTextColor = isDark ? Colors.white : Colors.black;
    final previewCardColor = isDark ? Color(0xFF1E1E1E) : Colors.grey[100]!;
    final previewAccentColor = _getAccentColor();
    
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: previewBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Vista previa',
            style: TextStyle(
              color: previewTextColor,
              fontSize: 18 * _fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Mensaje recibido
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _useDarkChatBubbles ? Color(0xFF2A2A2A) : Colors.grey[300],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Hola',
                  style: TextStyle(
                    color: previewTextColor,
                    fontSize: 14 * _fontSize,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Mensaje enviado
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: previewAccentColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '¿Cómo estás?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14 * _fontSize,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: previewAccentColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Botón',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14 * _fontSize,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: accentColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildThemeSelector() {
    return Column(
      children: [
        RadioListTile<String>(
          title: const Text(
            'Tema oscuro',
            style: TextStyle(color: Colors.white),
          ),
          value: 'dark',
          groupValue: _selectedTheme,
          activeColor: accentColor,
          onChanged: (value) {
            setState(() {
              _selectedTheme = value!;
            });
          },
        ),
        RadioListTile<String>(
          title: const Text(
            'Tema claro',
            style: TextStyle(color: Colors.white),
          ),
          value: 'light',
          groupValue: _selectedTheme,
          activeColor: accentColor,
          onChanged: (value) {
            setState(() {
              _selectedTheme = value!;
            });
          },
        ),
        RadioListTile<String>(
          title: const Text(
            'Seguir sistema',
            style: TextStyle(color: Colors.white),
          ),
          subtitle: Text(
            'Cambia automáticamente según la configuración del dispositivo',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
          value: 'system',
          groupValue: _selectedTheme,
          activeColor: accentColor,
          onChanged: (value) {
            setState(() {
              _selectedTheme = value!;
            });
          },
        ),
      ],
    );
  }

  Widget _buildAccentColorSelector() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _buildColorOption('blue', Color(0xFF3E63A8)),
          _buildColorOption('green', Colors.green),
          _buildColorOption('purple', Colors.purple),
          _buildColorOption('orange', Colors.orange),
          _buildColorOption('pink', Colors.pink),
          _buildColorOption('teal', Colors.teal),
        ],
      ),
    );
  }

  Widget _buildColorOption(String colorName, Color color) {
    final isSelected = _selectedAccentColor == colorName;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedAccentColor = colorName;
        });
      },
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.5),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: isSelected
            ? const Icon(
                Icons.check,
                color: Colors.white,
                size: 30,
              )
            : null,
      ),
    );
  }

  Widget _buildFontSizeSelector() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'A',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'A',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Slider(
            value: _fontSize,
            min: 0.8,
            max: 1.2,
            divisions: 4,
            activeColor: _getAccentColor(),
            inactiveColor: Colors.grey[700],
            onChanged: (value) {
              setState(() {
                _fontSize = value;
              });
            },
          ),
          Center(
            child: Text(
              _getFontSizeLabel(),
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalOptions() {
    return Column(
      children: [
        SwitchListTile(
          title: const Text(
            'Burbujas de chat oscuras',
            style: TextStyle(color: Colors.white),
          ),
          subtitle: Text(
            'Usar burbujas oscuras para mensajes recibidos',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
          value: _useDarkChatBubbles,
          activeColor: _getAccentColor(),
          onChanged: (value) {
            setState(() {
              _useDarkChatBubbles = value;
            });
          },
        ),
        ListTile(
          title: const Text(
            'Fondo de chat',
            style: TextStyle(color: Colors.white),
          ),
          subtitle: Text(
            'Personalizar el fondo de las conversaciones',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios,
            color: Colors.grey[600],
            size: 16,
          ),
          onTap: () {
            // Implementar selección de fondo
          },
        ),
      ],
    );
  }

  Color _getAccentColor() {
    switch (_selectedAccentColor) {
      case 'blue':
        return Color(0xFF3E63A8);
      case 'green':
        return Colors.green;
      case 'purple':
        return Colors.purple;
      case 'orange':
        return Colors.orange;
      case 'pink':
        return Colors.pink;
      case 'teal':
        return Colors.teal;
      default:
        return Color(0xFF3E63A8);
    }
  }

  String _getFontSizeLabel() {
    if (_fontSize <= 0.8) return 'Pequeño';
    if (_fontSize <= 0.9) return 'Reducido';
    if (_fontSize <= 1.1) return 'Normal';
    if (_fontSize <= 1.2) return 'Grande';
    return 'Muy grande';
  }
}
