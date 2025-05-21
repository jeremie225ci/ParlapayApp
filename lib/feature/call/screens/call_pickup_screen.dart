// call_pickup_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mk_mesenger/common/models/call.dart';
import 'package:mk_mesenger/common/utils/colors.dart';
import 'package:mk_mesenger/feature/call/controller/call_controller.dart';
import 'package:mk_mesenger/feature/call/screens/call_screen.dart';

class CallPickupScreen extends ConsumerWidget {
  final Widget scaffold;
  const CallPickupScreen({
    Key? key,
    required this.scaffold,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: ref.watch(callControllerProvider).callStream,
      builder: (context, snapshot) {
        // Si no hay datos, mostrar pantalla normal
        if (!snapshot.hasData ||
            snapshot.data == null ||
            !snapshot.data!.exists) {
          return scaffold;
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final call = Call.fromMap(data);

        // Verificar si la llamada corresponde al usuario actual
        if (call.callerId != currentUserId && call.// call_pickup_screen.dart (continuación)
receiverId != currentUserId) {
          return scaffold;
        }

        // Si es una llamada entrante (hasDialled = false) para este usuario, mostrar pantalla de incoming
        if (!call.hasDialled && call.receiverId == currentUserId) {
          return Scaffold(
            body: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1A1F38),
                    Color(0xFF2D3250),
                  ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 50),
                    // Indicador de llamada entrante con animación
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.7, end: 1.0),
                      duration: const Duration(milliseconds: 800),
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: Colors.greenAccent,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.greenAccent.withOpacity(0.5),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  call.callType == 'video' ? 'Videollamada entrante' : 'Llamada entrante',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 50),
                    // Avatar del llamante con animación
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.8, end: 1.1),
                      duration: const Duration(seconds: 2),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: accentColor, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: accentColor.withOpacity(0.5),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              backgroundImage: call.callerPic.isNotEmpty
                                  ? NetworkImage(call.callerPic)
                                  : null,
                              backgroundColor: call.callerPic.isEmpty ? accentColor : null,
                              radius: 80,
                              child: call.callerPic.isEmpty
                                  ? Text(
                                      call.callerName.isNotEmpty
                                          ? call.callerName[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 60,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 30),
                    // Nombre del llamante
                    Text(
                      call.callerName,
                      style: const TextStyle(
                        fontSize: 28,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Tipo de llamada
                    Text(
                      call.callType == 'video' ? 'Videollamada' : 'Llamada de voz',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[300],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    // Botones de acción
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Botón para rechazar
                          _buildActionButton(
                            icon: Icons.call_end,
                            color: Colors.red,
                            label: 'Rechazar',
                           // Modificar el botón "Rechazar"
onPressed: () {
  // Actualizar estado de la llamada a rechazada
  Call updatedCall = Call(
    callerId: call.callerId,
    callerName: call.callerName,
    callerPic: call.callerPic,
    receiverId: call.receiverId,
    receiverName: call.receiverName,
    receiverPic: call.receiverPic,
    callId: call.callId,
    hasDialled: call.hasDialled,
    timestamp: call.timestamp,
    isGroupCall: call.isGroupCall,
    callType: call.callType,
    callStatus: 'rejected',
    callTime: 0,
  );
  
  // Pasar explícitamente el estado 'rejected'
  ref.read(callControllerProvider).endCall(
    call.callerId, 
    call.receiverId, 
    context,
    status: 'rejected'  // AÑADIDO: especificar estado
  );
  
  ref.read(callControllerProvider).saveCallToHistory(
    updatedCall,
    status: 'rejected',
  );
},
                          ),
                          // Botón para aceptar
                          _buildActionButton(
                            icon: call.callType == 'video' ? Icons.videocam : Icons.call,
                            color: Colors.green,
                            label: 'Aceptar',
                            onPressed: () {
                              // Navegar a la pantalla de llamada
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CallScreen(
                                    channelId: call.callId,
                                    call: call,
                                    isGroupChat: call.isGroupCall,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Si no se cumple la condición de llamada entrante para el receptor,
        // mostrar la pantalla normal
        return scaffold;
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 70,
          width: 70,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.5),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white, size: 32),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}