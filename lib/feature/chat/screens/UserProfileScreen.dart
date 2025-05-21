import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mk_mesenger/common/models/user_model.dart';
import 'package:mk_mesenger/common/utils/colors.dart';
import 'package:mk_mesenger/common/utils/widgets/loader.dart';
import 'package:mk_mesenger/feature/auth/controller/auth_controller.dart';
import 'package:mk_mesenger/feature/chat/screens/mobile_chat_screen.dart';
import 'package:mk_mesenger/feature/wallet/screens/payment_screen.dart';
import 'package:mk_mesenger/feature/call/controller/call_controller.dart';
import 'package:mk_mesenger/feature/call/screens/call_screen.dart';
import 'package:mk_mesenger/common/models/call.dart';

class UserProfileScreen extends ConsumerWidget {
  final String userId;
  final String name;
  final String profilePic;

  const UserProfileScreen({
    Key? key,
    required this.userId,
    required this.name,
    required this.profilePic,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Color(0xFF1A1A1A),
        elevation: 0,
        title: const Text(
          'Perfil',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<UserModel>(
        stream: ref.read(authControllerProvider).userDataById(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Loader();
          }
          
          final user = snapshot.data ?? UserModel(
            name: name,
            uid: userId,
            profilePic: profilePic,
            isOnline: false, // Valor por defecto
            phoneNumber: '',
            groupId: [],
            status: 'Hola, estoy usando ParlaPay', // Valor por defecto
          );
          
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                
                // Foto de perfil
                Hero(
                  tag: 'profile-$userId',
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: accentColor, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withOpacity(0.3),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      backgroundImage: user.profilePic.isNotEmpty 
                          ? NetworkImage(user.profilePic) 
                          : null,
                      backgroundColor: user.profilePic.isEmpty ? accentColor : null,
                      radius: 70,
                      child: user.profilePic.isEmpty 
                          ? Text(
                              user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 50,
                              ),
                            ) 
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Nombre
                Text(
                  user.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Estado online
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: user.isOnline ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      user.isOnline ? 'En línea' : 'Desconectado',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                
                // Información del usuario
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      // Teléfono
                      _buildInfoItem(
                        icon: Icons.phone,
                        title: 'Teléfono',
                        subtitle: user.phoneNumber,
                      ),
                      
                      // Estado
                      _buildInfoItem(
                        icon: Icons.info_outline,
                        title: 'Estado',
                        subtitle: user.status ?? 'Hola, estoy usando ParlaPay',
                      ),
                      
                      // Medios compartidos
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.photo_library_outlined,
                              color: accentColor,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Medios compartidos',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.grey[600],
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                
                // Botones de acción
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Botón de mensaje
                      _buildActionButton(
                        icon: Icons.message,
                        label: 'Mensaje',
                        color: accentColor,
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            MobileChatScreen.routeName,
                            arguments: {
                              'name': user.name,
                              'uid': user.uid,
                              'isGroupChat': false,
                              'profilePic': user.profilePic,
                            },
                          );
                        },
                      ),
                      
                     _buildActionButton(
  icon: Icons.call,
  label: 'Llamar',
  color: Colors.green,
  onTap: () {
    // Mostrar indicador de "llamando..."
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Iniciando llamada de voz...'),
        duration: Duration(seconds: 2),
      ),
    );
    
    // Crear y realizar la llamada
    Call call = ref.read(callControllerProvider).makeCall(
      context,
      user.name,
      user.uid,
      user.profilePic,
      false, // No es una llamada grupal
      callType: 'audio', // Llamada de voz desde el perfil
    );
    
    // Navegar a CallScreen
    if (call.callStatus != 'error') {
      Navigator.pushNamed(
        context,
        CallScreen.routeName,
        arguments: {
          'channelId': call.callId,
          'call': call,
          'isGroupChat': false,
        },
      );
    } else {
      // Mostrar mensaje de error
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al iniciar la llamada. Intente nuevamente.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  },
),

// Botón de video
_buildActionButton(
  icon: Icons.videocam,
  label: 'Video',
  color: Colors.blue,
  onTap: () {
    // Mostrar indicador de "iniciando videollamada..."
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Iniciando videollamada...'),
        duration: Duration(seconds: 2),
      ),
    );
    
    // Crear y realizar la videollamada
    Call call = ref.read(callControllerProvider).makeCall(
      context,
      user.name,
      user.uid,
      user.profilePic,
      false, // No es una llamada grupal
      callType: 'video', // Videollamada
    );
    
    // Navegar a CallScreen
    if (call.callStatus != 'error') {
      Navigator.pushNamed(
        context,
        CallScreen.routeName,
        arguments: {
          'channelId': call.callId,
          'call': call,
          'isGroupChat': false,
        },
      );
    } else {
      // Mostrar mensaje de error
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al iniciar la videollamada. Intente nuevamente.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  },
),
                      // Botón de video (NUEVO)
                      _buildActionButton(
                        icon: Icons.videocam,
                        label: 'Video',
                        color: Colors.blue,
                        onTap: () {
                          // Mostrar indicador de "iniciando videollamada..."
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Iniciando videollamada...'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                          
                          // Crear y realizar la videollamada
                          Call call = ref.read(callControllerProvider).makeCall(
                            context,
                            user.name,
                            user.uid,
                            user.profilePic,
                            false, // No es una llamada grupal
                            callType: 'video', // Videollamada
                          );
                          
                          // Navegar a CallScreen
                          if (call.callStatus != 'error') {
                            Navigator.pushNamed(
                              context,
                              CallScreen.routeName,
                              arguments: {
                                'channelId': call.callId,
                                'call': call,
                                'isGroupChat': false,
                              },
                            );
                          } else {
                            // Mostrar mensaje de error
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Error al iniciar la videollamada. Intente nuevamente.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                      ),
                      
                      // Botón de pago
                      _buildActionButton(
                        icon: Icons.payments_outlined,
                        label: 'Pagar',
                        color: Colors.amber[700]!,
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            PaymentScreen.routeName,
                            arguments: {
                              'receiverId': user.uid,
                              'receiverName': user.name,
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: accentColor,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}