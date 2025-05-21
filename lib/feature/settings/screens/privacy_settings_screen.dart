import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mk_mesenger/common/utils/colors.dart';

class PrivacySettingsScreen extends ConsumerStatefulWidget {
  static const String routeName = '/privacy-settings';

  const PrivacySettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends ConsumerState<PrivacySettingsScreen> {
  bool _lastSeenEnabled = true;
  bool _readReceiptsEnabled = true;
  bool _onlineStatusEnabled = true;
  bool _profilePhotoPrivacy = false;
  String _statusPrivacy = 'all';
  String _callsPrivacy = 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        title: const Text(
          'Privacidad',
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
              // Información de privacidad
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accentColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: accentColor,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Tu privacidad es importante. Configura quién puede ver tu información y cómo se utiliza.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Sección de visibilidad
              _buildSettingsSection(
                title: 'Visibilidad',
                children: [
                  SwitchListTile(
                    title: const Text(
                      'Última vez visto',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Permitir que otros vean cuándo estuviste en línea por última vez',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    value: _lastSeenEnabled,
                    activeColor: accentColor,
                    onChanged: (value) {
                      setState(() {
                        _lastSeenEnabled = value;
                      });
                    },
                  ),
                  SwitchListTile(
                    title: const Text(
                      'Confirmaciones de lectura',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Enviar y recibir confirmaciones cuando los mensajes son leídos',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    value: _readReceiptsEnabled,
                    activeColor: accentColor,
                    onChanged: (value) {
                      setState(() {
                        _readReceiptsEnabled = value;
                      });
                    },
                  ),
                  SwitchListTile(
                    title: const Text(
                      'Estado en línea',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Mostrar cuando estás en línea',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    value: _onlineStatusEnabled,
                    activeColor: accentColor,
                    onChanged: (value) {
                      setState(() {
                        _onlineStatusEnabled = value;
                      });
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Sección de foto de perfil
              _buildSettingsSection(
                title: 'Foto de perfil',
                children: [
                  SwitchListTile(
                    title: const Text(
                      'Solo contactos',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Solo tus contactos pueden ver tu foto de perfil',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    value: _profilePhotoPrivacy,
                    activeColor: accentColor,
                    onChanged: (value) {
                      setState(() {
                        _profilePhotoPrivacy = value;
                      });
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Sección de estados
              _buildSettingsSection(
                title: 'Estados',
                children: [
                  RadioListTile<String>(
                    title: const Text(
                      'Todos',
                      style: TextStyle(color: Colors.white),
                    ),
                    value: 'all',
                    groupValue: _statusPrivacy,
                    activeColor: accentColor,
                    onChanged: (value) {
                      setState(() {
                        _statusPrivacy = value!;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text(
                      'Mis contactos',
                      style: TextStyle(color: Colors.white),
                    ),
                    value: 'contacts',
                    groupValue: _statusPrivacy,
                    activeColor: accentColor,
                    onChanged: (value) {
                      setState(() {
                        _statusPrivacy = value!;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text(
                      'Contactos seleccionados',
                      style: TextStyle(color: Colors.white),
                    ),
                    value: 'selected',
                    groupValue: _statusPrivacy,
                    activeColor: accentColor,
                    onChanged: (value) {
                      setState(() {
                        _statusPrivacy = value!;
                      });
                    },
                  ),
                  if (_statusPrivacy == 'selected')
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: ElevatedButton(
                        onPressed: () {
                          // Implementar selección de contactos
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Seleccionar contactos',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Sección de llamadas
              _buildSettingsSection(
                title: 'Llamadas',
                children: [
                  RadioListTile<String>(
                    title: const Text(
                      'Todos',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Cualquier persona puede llamarte',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    value: 'all',
                    groupValue: _callsPrivacy,
                    activeColor: accentColor,
                    onChanged: (value) {
                      setState(() {
                        _callsPrivacy = value!;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text(
                      'Mis contactos',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Solo tus contactos pueden llamarte',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    value: 'contacts',
                    groupValue: _callsPrivacy,
                    activeColor: accentColor,
                    onChanged: (value) {
                      setState(() {
                        _callsPrivacy = value!;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text(
                      'Nadie',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'No recibirás llamadas',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    value: 'none',
                    groupValue: _callsPrivacy,
                    activeColor: accentColor,
                    onChanged: (value) {
                      setState(() {
                        _callsPrivacy = value!;
                      });
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Sección de contactos bloqueados
              _buildSettingsSection(
                title: 'Contactos bloqueados',
                children: [
                  ListTile(
                    title: const Text(
                      'Contactos bloqueados',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Gestionar lista de contactos bloqueados',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '3',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    onTap: () {
                      // Implementar pantalla de contactos bloqueados
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Sección de seguridad
              _buildSettingsSection(
                title: 'Seguridad',
                children: [
                  ListTile(
                    title: const Text(
                      'Verificación en dos pasos',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Añade una capa adicional de seguridad a tu cuenta',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.grey[600],
                      size: 16,
                    ),
                    onTap: () {
                      // Implementar verificación en dos pasos
                    },
                  ),
                  ListTile(
                    title: const Text(
                      'Cambiar número',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Transferir tu cuenta a un nuevo número',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.grey[600],
                      size: 16,
                    ),
                    onTap: () {
                      // Implementar cambio de número
                    },
                  ),
                  ListTile(
                    title: const Text(
                      'Solicitar datos de mi cuenta',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Recibe un informe de la información de tu cuenta',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.grey[600],
                      size: 16,
                    ),
                    onTap: () {
                      // Implementar solicitud de datos
                    },
                  ),
                  ListTile(
                    title: Text(
                      'Eliminar mi cuenta',
                      style: TextStyle(color: errorColor),
                    ),
                    subtitle: Text(
                      'Eliminar permanentemente tu cuenta y todos tus datos',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.grey[600],
                      size: 16,
                    ),
                    onTap: () {
                      _showDeleteAccountDialog();
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 40),
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

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        title: const Text(
          '¿Eliminar cuenta?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Esta acción es irreversible. Todos tus mensajes, grupos y datos serán eliminados permanentemente.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Implementar eliminación de cuenta
            },
            child: Text(
              'Eliminar',
              style: TextStyle(color: errorColor),
            ),
          ),
        ],
      ),
    );
  }
}
