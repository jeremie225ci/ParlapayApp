// chat_list_group.dart
// Modificado para ordenar mensajes correctamente por hora dentro de cada día

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mk_mesenger/feature/chat/controller/chat_controller.dart';
import 'package:mk_mesenger/feature/chat/widgets/my_message_card.dart';
import 'package:mk_mesenger/common/enums/message_enum.dart';
import 'package:mk_mesenger/common/models/message.dart';
import 'package:mk_mesenger/common/providers/message_reply_provider.dart';
import 'package:mk_mesenger/common/utils/widgets/loader.dart';
import 'package:mk_mesenger/common/utils/colors.dart';
import 'package:mk_mesenger/feature/group/widgets/sender_message_card_group.dart';

class ChatListGroup extends ConsumerStatefulWidget {
  final String groupId;
  const ChatListGroup({
    Key? key,
    required this.groupId,
  }) : super(key: key);

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _ChatListGroupState();
}

class _ChatListGroupState extends ConsumerState<ChatListGroup> {
  final ScrollController messageController = ScrollController();
  List<Message> _lastMessages = [];

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  void onMessageSwipe(
    String message,
    bool isMe,
    MessageEnum messageEnum,
  ) {
    ref.read(messageReplyProvider.notifier).state = MessageReply(
      message,
      isMe,
      messageEnum,
    );
  }

  void _updateLastMessage() {
    if (_lastMessages.isEmpty) return;
    
    // IMPORTANTE: Buscar el último mensaje que NO sea una notificación
    Message? lastRealMessage;
    for (int i = _lastMessages.length - 1; i >= 0; i--) {
      final msg = _lastMessages[i];
      if (msg.type != MessageEnum.marketplaceNotification &&
          msg.type != MessageEnum.eventNotification &&
          msg.type != MessageEnum.eventContribution &&
          msg.type != MessageEnum.eventCompleted &&
          msg.type != MessageEnum.money) {
        lastRealMessage = msg;
        break;
      }
    }
    
    // Solo actualizar si encontramos un mensaje válido
    if (lastRealMessage != null) {
      ref.read(chatControllerProvider).updateGroupLastMessage(
        widget.groupId,
        lastRealMessage.text,
        lastRealMessage.timeSent,
        lastRealMessage.type,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Center(
        child: Text('No has iniciado sesión', style: TextStyle(color: Colors.white)),
      );
    }
    final currentUserId = currentUser.uid;

    return StreamBuilder<List<Message>>(
      stream: ref.read(chatControllerProvider).groupChatStream(widget.groupId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Loader();
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: \${snapshot.error}', style: const TextStyle(color: Colors.white)),
          );
        }

        final messages = snapshot.data ?? [];
        // Si cambia la lista, guardamos y actualizamos el último mensaje
        if (_lastMessages != messages) {
          _lastMessages = List.from(messages);
          _updateLastMessage();
        }

        // Auto-scroll al final
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (messageController.hasClients) {
            messageController.jumpTo(messageController.position.maxScrollExtent);
          }
        });

        // Agrupar por fecha
        final Map<String, List<Message>> messagesByDate = {};
        for (var msg in messages) {
          final key = DateFormat('yyyy-MM-dd').format(msg.timeSent);
          messagesByDate.putIfAbsent(key, () => []).add(msg);
        }
        final sortedDates = messagesByDate.keys.toList()..sort();

        // IMPORTANTE: Ordenar mensajes por hora dentro de cada día
        for (final key in messagesByDate.keys) {
          messagesByDate[key]!.sort((a, b) => a.timeSent.compareTo(b.timeSent));
        }

        return ListView.builder(
          controller: messageController,
          itemCount: sortedDates.length * 2,
          itemBuilder: (context, index) {
            if (index.isEven) {
              final dateIndex = index ~/ 2;
              final dateKey = sortedDates[dateIndex];
              final date = DateTime.parse(dateKey);
              final now = DateTime.now();
              final yesterday = DateTime(now.year, now.month, now.day - 1);
              String label;
              if (dateKey == DateFormat('yyyy-MM-dd').format(now)) {
                label = 'Hoy';
              } else if (dateKey == DateFormat('yyyy-MM-dd').format(yesterday)) {
                label = 'Ayer';
              } else {
                label = DateFormat('dd MMMM, yyyy').format(date);
              }
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: containerColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              );
            } else {
              final dateIndex = index ~/ 2;
              final dateKey = sortedDates[dateIndex];
              final dayMessages = messagesByDate[dateKey]!;
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: dayMessages.length,
                itemBuilder: (ctx, i) {
                  final m = dayMessages[i];
                  final time = DateFormat.Hm().format(m.timeSent);
                  if (!m.isSeen && m.recieverid == currentUserId) {
                    ref.read(chatControllerProvider).setChatMessageSeen(
                      context,
                      widget.groupId,
                      m.messageId,
                    );
                  }
                  if (m.senderId == currentUserId) {
                    return MyMessageCard(
                      message: m.text,
                      timeSent: m.timeSent,
                      type: m.type,
                      repliedText: m.repliedMessage,
                      repliedBy: m.repliedTo,
                      repliedType: m.repliedMessageType,
                      onSwipeRight: () => onMessageSwipe(m.text, true, m.type),
                      isSeen: m.isSeen,
                    );
                  }
                  return SenderMessageCardGroup(
                    message: m.text,
                    date: time,
                    type: m.type,
                    username: m.repliedTo,
                    repliedMessageType: m.repliedMessageType,
                    onRightSwipe: (_) => onMessageSwipe(m.text, false, m.type),
                    repliedText: m.repliedMessage,
                    senderId: m.senderId,
                  );
                },
              );
            }
          },
        );
      },
    );
  }
}