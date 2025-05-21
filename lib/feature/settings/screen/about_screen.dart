import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mk_mesenger/common/utils/colors.dart';

class AboutScreen extends ConsumerStatefulWidget {
  static const String routeName = '/about';

  const AboutScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> {
  final String _appVersion = '1.2.3';
  int _logoTapCount = 0;
  bool _showDebugInfo = false;

  void _incrementLogoTap() {
    setState(() {
      _logoTapCount++;
      if (_logoTapCount >= 7) {
        _showDebugInfo = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Modo desarrollador activado!'),
            backgroundColor: accentColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        title: const Text(
          'Acerca de',
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              
              // Logo y nombre de la app
              GestureDetector(
                onTap: _incrementLogoTap,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'P',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 60,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'ParlaPay',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Versión $_appVersion',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 16,
                ),
              ),
              
              if (_showDebugInfo) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Información de depuración',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Build: 20230615.1',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                      Text(
                        'Device ID: 8f7d6e5c4b3a2f1e',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                      Text(
                        'API Endpoint: api.parlapay.com/v2',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 40),
              
              // Información de la app
              _buildSettingsSection(
                title: 'Información',
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.description_outlined,
                      color: Colors.grey[400],
                    ),
                    title: const Text(
                      'Términos de servicio',
                      style: TextStyle(color: Colors.white),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.grey[600],
                      size: 16,
                    ),
                    onTap: () {
                      // Implementar términos de servicio
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.privacy_tip_outlined,
                      color: Colors.grey[400],
                    ),
                    title: const Text(
                      'Política de privacidad',
                      style: TextStyle(color: Colors.white),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.grey[600],
                      size: 16,
                    ),
                    onTap: () {
                      // Implementar política de privacidad
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.security_outlined,
                      color: Colors.grey[400],
                    ),
                    title: const Text(
                      'Seguridad',
                      style: TextStyle(color: Colors.white),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.grey[600],
                      size: 16,
                    ),
                    onTap: () {
                      // Implementar información de seguridad
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.code_outlined,
                      color: Colors.grey[400],
                    ),
                    title: const Text(
                      'Licencias de código abierto',
                      style: TextStyle(color: Colors.white),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.grey[600],
                      size: 16,
                    ),
                    onTap: () {
                      // Implementar licencias
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Sección de contacto
              _buildSettingsSection(
                title: 'Contacto',
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.help_outline,
                      color: Colors.grey[400],
                    ),
                    title: const Text(
                      'Centro de ayuda',
                      style: TextStyle(color: Colors.white),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.grey[600],
                      size: 16,
                    ),
                    onTap: () {
                      // Implementar centro de ayuda
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.contact_support_outlined,
                      color: Colors.grey[400],
                    ),
                    title: const Text(
                      'Contactar con soporte',
                      style: TextStyle(color: Colors.white),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.grey[600],
                      size: 16,
                    ),
                    onTap: () {
                      // Implementar contacto con soporte
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.star_outline,
                      color: Colors.grey[400],
                    ),
                    title: const Text(
                      'Calificar la aplicación',
                      style: TextStyle(color: Colors.white),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.grey[600],
                      size: 16,
                    ),
                    onTap: () {
                      // Implementar calificación
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.share_outlined,
                      color: Colors.grey[400],
                    ),
                    title: const Text(
                      'Compartir ParlaPay',
                      style: TextStyle(color: Colors.white),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.grey[600],
                      size: 16,
                    ),
                    onTap: () {
                      // Implementar compartir
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 40),
              
              // Equipo
              Text(
                'Hecho con ❤️ por el equipo de ParlaPay',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '© 2023 ParlaPay Inc. Todos los derechos reservados.',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
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
}
