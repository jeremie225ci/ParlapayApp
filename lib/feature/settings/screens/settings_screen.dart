import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mk_mesenger/common/utils/colors.dart';
import 'package:mk_mesenger/feature/auth/controller/auth_controller.dart';

class SettingsScreen extends ConsumerWidget {
  static const String routeName = '/settings';

  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Color(0xFF1A1A1A),
        elevation: 0,
        title: const Text(
          'Configuración',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF121212),
          image: DecorationImage(
            image: AssetImage('assets/images/chat_bg.png'),
            fit: BoxFit.cover,
            opacity: 0.03,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Sección de perfil
            _buildSettingsSection(
              title: 'Perfil',
              icon: Icons.person,
              children: [
                _buildSettingsTile(
                  icon: Icons.person,
                  title: 'Información de perfil',
                  onTap: () {
                    // Navegar a la pantalla de edición de perfil
                  },
                ),
                _buildSettingsTile(
                  icon: Icons.privacy_tip,
                  title: 'Privacidad',
                  onTap: () {
                    // Navegar a ajustes de privacidad
                  },
                ),
                _buildSettingsTile(
                  icon: Icons.verified_user,
                  title: 'Verificación',
                  onTap: () {
                    // Navegar a verificación de cuenta
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Sección de notificaciones
            _buildSettingsSection(
              title: 'Notificaciones',
              icon: Icons.notifications,
              children: [
                _buildSettingsTile(
                  icon: Icons.chat_bubble,
                  title: 'Notificaciones de chat',
                  onTap: () {
                    // Ajustes de notificaciones de chat
                  },
                ),
                _buildSettingsTile(
                  icon: Icons.group,
                  title: 'Notificaciones de grupos',
                  onTap: () {
                    // Ajustes de notificaciones de grupos
                  },
                ),
                _buildSettingsTile(
                  icon: Icons.payments,
                  title: 'Notificaciones de pagos',
                  onTap: () {
                    // Ajustes de notificaciones de pagos
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Sección de seguridad
            _buildSettingsSection(
              title: 'Seguridad',
              icon: Icons.security,
              children: [
                _buildSettingsTile(
                  icon: Icons.lock,
                  title: 'Contraseña y seguridad',
                  onTap: () {
                    // Ajustes de contraseña
                  },
                ),
                _buildSettingsTile(
                  icon: Icons.verified_user,
                  title: 'Verificación en dos pasos',
                  onTap: () {
                    // Configuración de 2FA
                  },
                ),
                _buildSettingsTile(
                  icon: Icons.devices,
                  title: 'Dispositivos conectados',
                  onTap: () {
                    // Ver dispositivos conectados
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Sección de apariencia
            _buildSettingsSection(
              title: 'Apariencia',
              icon: Icons.palette,
              children: [
                _buildSettingsTile(
                  icon: Icons.color_lens,
                  title: 'Tema',
                  onTap: () {
                    // Ajustes de tema
                  },
                ),
                _buildSettingsTile(
                  icon: Icons.font_download,
                  title: 'Texto y fuentes',
                  onTap: () {
                    // Ajustes de fuentes
                  },
                ),
                _buildSettingsTile(
                  icon: Icons.wallpaper,
                  title: 'Fondo de chat',
                  onTap: () {
                    // Cambiar fondo de chat
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Sección de Wallet
            _buildSettingsSection(
              title: 'Wallet y Pagos',
              icon: Icons.account_balance_wallet,
              children: [
                _buildSettingsTile(
                  icon: Icons.credit_card,
                  title: 'Métodos de pago',
                  onTap: () {
                    // Gestionar métodos de pago
                  },
                ),
                _buildSettingsTile(
                  icon: Icons.receipt_long,
                  title: 'Historial de transacciones',
                  onTap: () {
                    // Ver historial
                  },
                ),
                _buildSettingsTile(
                  icon: Icons.notifications,
                  title: 'Alertas de pagos',
                  onTap: () {
                    // Configurar alertas
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Sección de soporte
            _buildSettingsSection(
              title: 'Soporte y Ayuda',
              icon: Icons.help,
              children: [
                _buildSettingsTile(
                  icon: Icons.contact_support,
                  title: 'Centro de ayuda',
                  onTap: () {
                    // Abrir centro de ayuda
                  },
                ),
                _buildSettingsTile(
                  icon: Icons.feedback,
                  title: 'Enviar comentarios',
                  onTap: () {
                    // Enviar feedback
                  },
                ),
                _buildSettingsTile(
                  icon: Icons.info,
                  title: 'Acerca de',
                  onTap: () {
                    // Información sobre la app
                    Navigator.pushNamed(context, '/about');
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Botón de cerrar sesión
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                onPressed: () {
                  ref.read(authControllerProvider).signOut();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF1A1A1A),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text(
                  'Cerrar sesión',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: Color(0xFF3E63A8),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: Color(0xFF3E63A8),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: Colors.white,
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
      ),
      trailing: trailing ?? Icon(
        Icons.arrow_forward_ios,
        color: Colors.grey,
        size: 16,
      ),
      onTap: onTap,
    );
  }
}