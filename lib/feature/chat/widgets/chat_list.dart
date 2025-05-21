import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mk_mesenger/common/models/message.dart';
import 'package:mk_mesenger/common/providers/message_reply_provider.dart';
import 'package:mk_mesenger/common/utils/widgets/loader.dart';
import 'package:mk_mesenger/common/enums/message_enum.dart';
import 'package:mk_mesenger/feature/chat/controller/chat_controller.dart';
import 'package:mk_mesenger/feature/chat/widgets/my_message_card.dart';
import 'package:mk_mesenger/feature/chat/widgets/sender_message_card.dart';

class ChatList extends ConsumerStatefulWidget {
  final String recieverUserId;
  final bool isGroupChat;
  final String groupId;

  const ChatList({
    Key? key,
    required this.recieverUserId,
    required this.isGroupChat,
    required this.groupId,
  }) : super(key: key);

  @override
  ConsumerState<ChatList> createState() => _ChatListState();
}

class _ChatListState extends ConsumerState<ChatList> {
  final ScrollController messageController = ScrollController();

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  void onMessageSwipe(String message, bool isMe, MessageEnum type) {
    ref.read(messageReplyProvider.notifier).state =
        MessageReply(message, isMe, type);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Center(child: Text('No has iniciado sesión', style: TextStyle(color: Colors.white)));
    }
    final currentUserId = currentUser.uid;
    final chatId = widget.isGroupChat ? widget.groupId : widget.recieverUserId;
    if (chatId.isEmpty) {
      return const Center(child: Text('ID de chat no válido', style: TextStyle(color: Colors.white)));
    }

    final stream = widget.isGroupChat
        ? ref.read(chatControllerProvider).groupChatStream(chatId)
        : ref.read(chatControllerProvider).chatStream(chatId);

    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF121212),
        image: DecorationImage(
          image: AssetImage('assets/images/chat_bg.png'),
          fit: BoxFit.cover,
          opacity: 0.05,
        ),
      ),
      child: StreamBuilder<List<Message>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Loader();
          }
          final messages = snapshot.data;
          if (messages == null || messages.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[700]),
                  const SizedBox(height: 16),
                  Text(
                    'No hay mensajes aún',
                    style: TextStyle(color: Colors.grey[500], fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Envía un mensaje para iniciar la conversación',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            );
          }

          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (messageController.hasClients) {
              messageController.jumpTo(
                messageController.position.maxScrollExtent,
              );
            }
          });

          // Agrupar mensajes por fecha
          final Map<String, List<Message>> groupedMessages = {};
          for (final msg in messages) {
            final dateKey = DateFormat('dd/MM/yyyy').format(msg.timeSent);
            if (!groupedMessages.containsKey(dateKey)) {
              groupedMessages[dateKey] = [];
            }
            groupedMessages[dateKey]!.add(msg);
          }
          
          // IMPORTANTE: Ordenar mensajes por hora dentro de cada día
          for (final key in groupedMessages.keys) {
            groupedMessages[key]!.sort((a, b) => a.timeSent.compareTo(b.timeSent));
          }

          // Crear lista de widgets para cada grupo de fecha
          final List<Widget> messageWidgets = [];
          groupedMessages.forEach((date, msgs) {
            // Añadir separador de fecha
            messageWidgets.add(
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      date,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            );

            // Añadir mensajes de este grupo
            for (final msg in msgs) {
              // Marca como visto si me llegó y no está visto aún
              if (!msg.isSeen && msg.recieverid == currentUserId) {
                ref
                    .read(chatControllerProvider)
                    .setChatMessageSeen(context, chatId, msg.messageId);
              }

              // Mensajes propios
              if (msg.senderId == currentUserId) {
                messageWidgets.add(
                  MyMessageCard(
                    message: msg.text,
                    timeSent: msg.timeSent,
                    type: msg.type,
                    repliedText: msg.repliedMessage,
                    repliedBy: msg.repliedTo,
                    repliedType: msg.repliedMessageType,
                    onSwipeRight: () => onMessageSwipe(msg.text, true, msg.type),
                    isSeen: msg.isSeen,
                  ),
                );
              } else {
                // Mensajes de otros
                messageWidgets.add(
                  SenderMessageCard(
                    message: msg.text,
                    date: DateFormat.Hm().format(msg.timeSent),
                    type: msg.type,
                    username: msg.repliedTo,
                    repliedMessageType: msg.repliedMessageType,
                    onRightSwipe: (details) => onMessageSwipe(msg.text, false, msg.type),
                    repliedText: msg.repliedMessage,
                    senderId: msg.senderId,
                  ),
                );
              }
            }
          });

          return ListView(
            controller: messageController,
            padding: const EdgeInsets.only(bottom: 16),
            children: messageWidgets,
          );
        },
      ),
    );
  }
}