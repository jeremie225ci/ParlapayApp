import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mk_mesenger/common/utils/colors.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  static const String routeName = '/notification-settings';

  const NotificationSettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen> {
  bool _messageNotifications = true;
  bool _groupNotifications = true;
  bool _callNotifications = true;
  bool _statusNotifications = true;
  bool _vibrate = true;
  bool _sound = true;
  bool _showPreview = true;
  bool _useHighPriority = true;
  String _lightColor = 'blue';
  String _ringtone = 'default';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        title: const Text(
          'Notificaciones',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sección de mensajes
              _buildSettingsSection(
                title: 'Mensajes',
                children: [
                  SwitchListTile(
                    title: const Text(
                      'Notificaciones de mensajes',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Recibir notificaciones de mensajes nuevos',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    value: _messageNotifications,
                    activeColor: accentColor,
                    onChanged: (value) {
                      setState(() {
                        _messageNotifications = value;
                      });
                    },
                  ),
                  SwitchListTile(
                    title: const Text(
                      'Notificaciones de grupos',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Recibir notificaciones de mensajes de grupos',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    value: _groupNotifications,
                    activeColor: accentColor,
                    onChanged: (value) {
                      setState(() {
                        _groupNotifications = value;
                      });
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Sección de llamadas
              _buildSettingsSection(
                title: 'Llamadas',
                children: [
                  SwitchListTile(
                    title: const Text(
                      'Notificaciones de llamadas',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Recibir notificaciones de llamadas entrantes',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    value: _callNotifications,
                    activeColor: accentColor,
                    onChanged: (value) {
                      setState(() {
                        _callNotifications = value;
                      });
                    },
                  ),
                  ListTile(
                    title: const Text(
                      'Tono de llamada',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      _getRingtoneName(),
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.grey[600],
                      size: 16,
                    ),
                    onTap: () {
                      _showRingtoneDialog();
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Sección de estados
              _buildSettingsSection(
                title: 'Estados',
                children: [
                  SwitchListTile(
                    title: const Text(
                      'Notificaciones de estados',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Recibir notificaciones cuando tus contactos publiquen estados',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    value: _statusNotifications,
                    activeColor: accentColor,
                    onChanged: (value) {
                      setState(() {
                        _statusNotifications = value;
                      });
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Sección de configuración general
              _buildSettingsSection(
                title: 'Configuración general',
                children: [
                  SwitchListTile(
                    title: const Text(
                      'Vibración',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Vibrar al recibir notificaciones',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    value: _vibrate,
                    activeColor: accentColor,
                    onChanged: (value) {
                      setState(() {
                        _vibrate = value;
                      });
                    },
                  ),
                  SwitchListTile(
                    title: const Text(
                      'Sonido',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Reproducir sonido al recibir notificaciones',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    value: _sound,
                    activeColor: accentColor,
                    onChanged: (value) {
                      setState(() {
                        _sound = value;
                      });
                    },
                  ),
                  SwitchListTile(
                    title: const Text(
                      'Mostrar vista previa',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Mostrar contenido del mensaje en la notificación',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    value: _showPreview,
                    activeColor: accentColor,
                    onChanged: (value) {
                      setState(() {
                        _showPreview = value;
                      });
                    },
                  ),
                  SwitchListTile(
                    title: const Text(
                      'Alta prioridad',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Mostrar notificaciones como banners emergentes',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    value: _useHighPriority,
                    activeColor: accentColor,
                    onChanged: (value) {
                      setState(() {
                        _useHighPriority = value;
                      });
                    },
                  ),
                  ListTile(
                    title: const Text(
                      'Color de LED',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      _getLightColorName(),
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    trailing: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: _getLightColor(),
                        shape: BoxShape.circle,
                      ),
                    ),
                    onTap: () {
                      _showLightColorDialog();
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Sección de no molestar
              _buildSettingsSection(
                title: 'No molestar',
                children: [
                  ListTile(
                    title: const Text(
                      'Programar modo No molestar',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Silenciar notificaciones durante ciertos períodos',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.grey[600],
                      size: 16,
                    ),
                    onTap: () {
                      // Implementar programación de No molestar
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 40),
              
              // Botón de restablecer
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _messageNotifications = true;
                      _groupNotifications = true;
                      _callNotifications = true;
                      _statusNotifications = true;
                      _vibrate = true;
                      _sound = true;
                      _showPreview = true;
                      _useHighPriority = true;
                      _lightColor = 'blue';
                      _ringtone = 'default';
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

  String _getLightColorName() {
    switch (_lightColor) {
      case 'blue':
        return 'Azul';
      case 'green':
        return 'Verde';
      case 'red':
        return 'Rojo';
      case 'yellow':
        return 'Amarillo';
      case 'purple':
        return 'Púrpura';
      case 'white':
        return 'Blanco';
      default:
        return 'Azul';
    }
  }

  Color _getLightColor() {
    switch (_lightColor) {
      case 'blue':
        return Colors.blue;
      case 'green':
        return Colors.green;
      case 'red':
        return Colors.red;
      case 'yellow':
        return Colors.yellow;
      case 'purple':
        return Colors.purple;
      case 'white':
        return Colors.white;
      default:
        return Colors.blue;
    }
  }

  String _getRingtoneName() {
    switch (_ringtone) {
      case 'default':
        return 'Tono predeterminado';
      case 'classic':
        return 'Clásico';
      case 'chime':
        return 'Campanilla';
      case 'electronic':
        return 'Electrónico';
      case 'marimba':
        return 'Marimba';
      case 'none':
        return 'Ninguno';
      default:
        return 'Tono predeterminado';
    }
  }

  void _showLightColorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        title: const Text(
          'Color de LED',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildColorOption('blue', 'Azul', Colors.blue),
            _buildColorOption('green', 'Verde', Colors.green),
            _buildColorOption('red', 'Rojo', Colors.red),
            _buildColorOption('yellow', 'Amarillo', Colors.yellow),
            _buildColorOption('purple', 'Púrpura', Colors.purple),
            _buildColorOption('white', 'Blanco', Colors.white),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorOption(String value, String name, Color color) {
    return RadioListTile<String>(
      title: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            name,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
      value: value,
      groupValue: _lightColor,
      activeColor: accentColor,
      onChanged: (newValue) {
        setState(() {
          _lightColor = newValue!;
        });
        Navigator.pop(context);
      },
    );
  }

  void _showRingtoneDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        title: const Text(
          'Tono de llamada',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRingtoneOption('default', 'Tono predeterminado', Icons.notifications_active),
            _buildRingtoneOption('classic', 'Clásico', Icons.music_note),
            _buildRingtoneOption('chime', 'Campanilla', Icons.notifications),
            _buildRingtoneOption('electronic', 'Electrónico', Icons.electric_bolt),
            _buildRingtoneOption('marimba', 'Marimba', Icons.piano),
            _buildRingtoneOption('none', 'Ninguno', Icons.notifications_off),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRingtoneOption(String value, String name, IconData icon) {
    return RadioListTile<String>(
      title: Row(
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 16),
          Text(
            name,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
      value: value,
      groupValue: _ringtone,
      activeColor: accentColor,
      onChanged: (newValue) {
        setState(() {
          _ringtone = newValue!;
        });
        Navigator.pop(context);
      },
    );
  }
}
