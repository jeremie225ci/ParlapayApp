import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mk_mesenger/common/utils/colors.dart';
import 'package:mk_mesenger/feature/group/widgets/display_text_image_group.dart';
import 'package:swipe_to/swipe_to.dart';
import 'package:mk_mesenger/common/enums/message_enum.dart';

class SenderMessageCardGroup extends ConsumerWidget {
  final String message;
  final String date;
  final MessageEnum type;
  final Function(DragUpdateDetails) onRightSwipe;
  final String repliedText;
  final String username;
  final MessageEnum repliedMessageType;
  final String senderId;

  const SenderMessageCardGroup({
    Key? key,
    required this.message,
    required this.date,
    required this.type,
    required this.username,
    required this.repliedMessageType,
    required this.senderId,
    required this.onRightSwipe,
    required this.repliedText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isReplying = repliedText.isNotEmpty;
    
    // Verificar que senderId no esté vacío
    if (senderId.isEmpty) {
      print("WARNING: senderId está vacío en SenderMessageCardGroup");
    }

    return SwipeTo(
      onRightSwipe: onRightSwipe,
      child: FutureBuilder<DocumentSnapshot>(
        // Solo realizar la consulta si tenemos un senderId válido
        future: senderId.isNotEmpty 
            ? FirebaseFirestore.instance.collection('users').doc(senderId).get()
            : null,
        builder: (context, snapshot) {
          // Valor por defecto para el nombre del remitente
          String senderName = "Usuario";
          String profilePic = "";
          
          // Si los datos están disponibles, usa el nombre real
          if (snapshot.connectionState == ConnectionState.done && 
              snapshot.hasData && 
              snapshot.data != null) {
            final userData = snapshot.data!.data() as Map<String, dynamic>?;
            if (userData != null) {
              senderName = userData['name'] ?? "Usuario";
              profilePic = userData['profilePic'] ?? "";
            }
          }
          
          return Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width - 45,
              ),
              child: Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: cardColor,
                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Encabezado con info del remitente
                    Padding(
                      padding: const EdgeInsets.only(left: 10, right: 10, top: 8),
                      child: Row(
                        children: [
                          // Mostrar avatar si tenemos foto de perfil
                          if (profilePic.isNotEmpty)
                            CircleAvatar(
                              backgroundImage: NetworkImage(profilePic),
                              radius: 15,
                            )
                          else
                            CircleAvatar(
                              radius: 15,
                              backgroundColor: accentColor.withOpacity(0.7),
                              child: Text(
                                senderName.isNotEmpty ? senderName[0].toUpperCase() : "?",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          Text(
                            senderName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Mensaje respondido (si existe)
                    if (isReplying) ...[
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: backgroundColor.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: accentColor.withOpacity(0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                username,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: accentColor,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 5),
                              DisplayTextImageGIFGroup(
                                message: repliedText,
                                type: repliedMessageType,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    
                    // Contenido del mensaje
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 12,
                        right: 12,
                        top: 6,
                        bottom: 26,
                      ),
                      child: DisplayTextImageGIFGroup(
                        message: message,
                        type: type,
                      ),
                    ),
                    
                    // Timestamp
                    Padding(
                      padding: const EdgeInsets.only(left: 10, right: 10, bottom: 5),
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          date,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}