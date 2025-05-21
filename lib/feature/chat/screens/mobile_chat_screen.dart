import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mk_mesenger/feature/call/controller/call_controller.dart';
import 'package:mk_mesenger/feature/call/screens/call_pickup_screen.dart';
import 'package:mk_mesenger/feature/call/screens/call_screen.dart';
import 'package:mk_mesenger/feature/chat/screens/UserProfileScreen.dart';
import 'package:mk_mesenger/feature/chat/widgets/chat_list.dart';
import 'package:mk_mesenger/feature/group/screens/GroupProfileScreen%20.dart';
import 'package:mk_mesenger/feature/group/widgets/chat_list_group.dart';
import 'package:mk_mesenger/feature/chat/widgets/bottom_chat_field.dart';
import 'package:mk_mesenger/common/models/user_model.dart';
import 'package:mk_mesenger/common/utils/widgets/loader.dart';
import 'package:mk_mesenger/feature/auth/controller/auth_controller.dart';
import 'package:mk_mesenger/feature/chat/controller/chat_controller.dart';
import 'package:mk_mesenger/common/models/call.dart';


class MobileChatScreen extends ConsumerStatefulWidget {
  static const String routeName = '/mobile-chat-screen';
  final String name;
  final String uid; // Este uid ahora puede ser userId o groupId
  final bool isGroupChat;
  final String profilePic;

  const MobileChatScreen({
    Key? key,
    required this.name,
    required this.uid,
    required this.isGroupChat,
    required this.profilePic,
  }) : super(key: key);

  @override
  ConsumerState<MobileChatScreen> createState() => _MobileChatScreenState();
}

class _MobileChatScreenState extends ConsumerState<MobileChatScreen> {
  @override
  void initState() {
    super.initState();
    // Marcar la conversación como leída cuando se abre la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatControllerProvider).markConversationRead(
            context,
            widget.uid,
            widget.isGroupChat,
          );
    });
  }
  
  void makeCall(WidgetRef ref, BuildContext context, {String callType = 'video'}) {
    // Mostrar indicador de "llamando..."
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(callType == 'video' ? 'Iniciando videollamada...' : 'Iniciando llamada de voz...'),
        duration: const Duration(seconds: 2),
      ),
    );

    // Crear la llamada
    Call call = ref.read(callControllerProvider).makeCall(
      context,
      widget.name,
      widget.uid,
      widget.profilePic,
      widget.isGroupChat,
      callType: callType, // Pasar el tipo de llamada
    );

    // Navegar a CallScreen
    if (call.callStatus != 'error') {
      Navigator.pushNamed(
        context,
        CallScreen.routeName,
        arguments: {
          'channelId': call.callId,
          'call': call,
          'isGroupChat': widget.isGroupChat,
        },
      );
    } else {
      // Mostrar mensaje de error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(callType == 'video' 
            ? 'Error al iniciar videollamada. Intente nuevamente.' 
            : 'Error al iniciar llamada de voz. Intente nuevamente.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openProfile(BuildContext context) {
    if (widget.isGroupChat) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GroupProfileScreen(
            groupId: widget.uid,
            name: widget.name,
            profilePic: widget.profilePic,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UserProfileScreen(
            userId: widget.uid,
            name: widget.name,
            profilePic: widget.profilePic,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CallPickupScreen(
      scaffold: Scaffold(
        backgroundColor: Color(0xFF121212),
        appBar: AppBar(
          backgroundColor: Color(0xFF1A1A1A),
          elevation: 0,
          leadingWidth: 30,
          title: GestureDetector(
            onTap: () => _openProfile(context),
            child: Row(
              children: [
                // Profile image
                Hero(
                  tag: 'profile-${widget.uid}',
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Color(0xFF3E63A8), width: 2),
                    ),
                    child: CircleAvatar(
                      backgroundImage: widget.profilePic.isNotEmpty 
                          ? NetworkImage(widget.profilePic) 
                          : null,
                      backgroundColor: widget.profilePic.isEmpty ? Color(0xFF3E63A8) : null,
                      radius: 18,
                      child: widget.profilePic.isEmpty 
                          ? Text(
                              widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ) 
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // User/group info
                Expanded(
                  child: widget.isGroupChat
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Grupo',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        )
                      : StreamBuilder<UserModel>(
                          stream: ref.read(authControllerProvider).userDataById(widget.uid),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Loader();
                            } else if (!snapshot.hasData || snapshot.data == null) {
                              return Text(
                                widget.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              );
                            } else {
                              final user = snapshot.data!;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: (user.isOnline ?? false) ? Colors.green : Colors.grey,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        (user.isOnline ?? false) ? 'En línea' : 'Desconectado',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[400],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            }
                          },
                        ),
                ),
              ],
            ),
          ),
          centerTitle: false,
          actions: [
            IconButton(
              onPressed: () => makeCall(ref, context, callType: 'video'),
              icon: const Icon(Icons.video_call, color: Colors.white),
              tooltip: 'Videollamada',
            ),
            IconButton(
              onPressed: () => makeCall(ref, context, callType: 'audio'),
              icon: const Icon(Icons.call, color: Colors.white),
              tooltip: 'Llamada de voz',
            ),
            IconButton(
              onPressed: () => _openProfile(context),
              icon: const Icon(Icons.more_vert, color: Colors.white),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: widget.isGroupChat
                  ? ChatListGroup(
                      groupId: widget.uid,
                    )
                  : ChatList(
                      recieverUserId: widget.uid,
                      isGroupChat: false,
                      groupId: '',
                    ),
            ),
            BottomChatField(
              recieverUserId: widget.uid,
              isGroupChat: widget.isGroupChat,
            ),
          ],
        ),
      ),
    );
  }
}