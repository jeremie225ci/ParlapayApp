import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mk_mesenger/common/enums/message_enum.dart';
import 'package:mk_mesenger/common/models/chat_contact.dart';
import 'package:mk_mesenger/common/models/group.dart';
import 'package:mk_mesenger/common/models/message.dart';
import 'package:mk_mesenger/common/models/search_result.dart';
import 'package:mk_mesenger/common/providers/message_reply_provider.dart';
import 'package:mk_mesenger/feature/auth/controller/auth_controller.dart';
import 'package:mk_mesenger/feature/chat/repositories/chat_repository.dart';
import 'package:mk_mesenger/feature/wallet/controller/wallet_controller.dart';

final chatControllerProvider = Provider<ChatController>((ref) {
  final chatRepository = ref.watch(chatRepositoryProvider);
  return ChatController(
    FirebaseFirestore.instance,
    chatRepository: chatRepository,
    ref: ref,
  );
});

class ChatController {
  final FirebaseFirestore _firestore;
  final ChatRepository chatRepository;
  final Ref ref;

  ChatController(this._firestore, {
    required this.chatRepository,
    required this.ref,
  });

  Stream<List<ChatContact>> chatContacts() {
    return chatRepository.getChatContacts();
  }

  Stream<List<Group>> chatGroups() {
    return chatRepository.getChatGroups();
  }

  Stream<int> unreadChatsCount() {
    return chatRepository.getUnreadChatsCount();
  }

  Stream<List<Message>> chatStream(String receiverUserId) {
    return chatRepository.getChatStream(receiverUserId);
  }

  Stream<List<Message>> groupChatStream(String groupId) {
    return chatRepository.getGroupChatStream(groupId);
  }

  // Método para buscar mensajes
  Stream<List<SearchResult>> searchMessages(String query) {
    return chatRepository.searchMessages(query);
  }

  // Método para alternar el estado anclado/destacado de un chat
  Future<void> togglePinnedChat(String contactId, bool isPinned) async {
    return chatRepository.togglePinnedChat(contactId, isPinned);
  }

  void sendTextMessage(
    BuildContext context,
    String text,
    String receiverUserId,
    bool isGroupChat,
  ) {
    final messageReply = ref.read(messageReplyProvider);
    ref.read(userDataAuthProvider).whenData((senderUser) {
      if (senderUser != null) {
        chatRepository.sendTextMessage(
          context: context,
          text: text,
          receiverUserId: receiverUserId,
          senderUser: senderUser,
          messageReply: messageReply,
          isGroupChat: isGroupChat,
        );
      }
    });
    ref.read(messageReplyProvider.notifier).update((state) => null);
  }

  /// Envía dinero. Si la transacción es exitosa, envía un mensaje de texto informando.
  Future<void> sendMoneyMessage(
    BuildContext context,
    double amount,
    String receiverUserId,
    bool isGroupChat,
  ) async {
    // Invoca sendMoney con parámetros posicionales
    bool success = await ref
        .read(walletControllerProvider.notifier)
        .sendMoney(
          receiverUserId,
          amount,
          context,
        );
    if (success) {
      // Aquí está el error - se eliminó el carácter de escape \
      final message = '€${amount.toStringAsFixed(2)}';
      sendTextMessage(context, message, receiverUserId, isGroupChat);
    }
  }

  void sendFileMessage(
    BuildContext context,
    File file,
    String receiverUserId,
    MessageEnum messageEnum,
    bool isGroupChat,
  ) {
    final messageReply = ref.read(messageReplyProvider);
    ref.read(userDataAuthProvider).whenData((senderUser) {
      if (senderUser != null) {
        chatRepository.sendFileMessage(
          context: context,
          file: file,
          receiverUserId: receiverUserId,
          senderUserData: senderUser,
          messageEnum: messageEnum,
          ref: ref,
          messageReply: messageReply,
          isGroupChat: isGroupChat,
        );
      }
    });
    ref.read(messageReplyProvider.notifier).update((state) => null);
  }
    
  Future<void> updateGroupLastMessage(
    String groupId,
    String text,
    DateTime time,
    MessageEnum textType,
  ) async {
    // Ignorar todos los tipos de notificaciones de sistema
    if (textType == MessageEnum.marketplaceNotification ||
        textType == MessageEnum.eventNotification ||
        textType == MessageEnum.eventContribution ||
        textType == MessageEnum.eventCompleted ||
        textType == MessageEnum.money) {
      return;
    }
    await _firestore.collection('groups').doc(groupId).update({
      'lastMessage': text,
      'timeSent': time.millisecondsSinceEpoch,
    });
  }

  /// Listener interno para chats de grupo
  void listenToGroupChats(String groupId) {
    _firestore
      .collection('groups')
      .doc(groupId)
      .collection('chats')
      .orderBy('timeSent')
      .snapshots()
      .listen((snapshot) {
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data();
            if (data == null) continue;
            final msg = Message.fromMap(data);
            // Solo actualizamos para mensajes normales (filtrando TODOS los tipos de notificaciones)
            if (msg.type != MessageEnum.marketplaceNotification &&
                msg.type != MessageEnum.eventNotification &&
                msg.type != MessageEnum.eventContribution &&
                msg.type != MessageEnum.eventCompleted &&
                msg.type != MessageEnum.money) {
              updateGroupLastMessage(
                groupId,
                msg.text,
                msg.timeSent,
                msg.type,
              );
            }
          }
        }
      });
  }

  void sendGIFMessage(
    BuildContext context,
    String gifUrl,
    String receiverUserId,
    bool isGroupChat,
  ) {
    final messageReply = ref.read(messageReplyProvider);
    int gifUrlPartIndex = gifUrl.lastIndexOf('-') + 1;
    String gifUrlPart = gifUrl.substring(gifUrlPartIndex);
    String newGifUrl = 'https://i.giphy.com/media/\$gifUrlPart/200.gif';
    ref.read(userDataAuthProvider).whenData((senderUser) {
      if (senderUser != null) {
        chatRepository.sendGIFMessage(
          context: context,
          gifUrl: newGifUrl,
          receiverUserId: receiverUserId,
          senderUser: senderUser,
          messageReply: messageReply,
          isGroupChat: isGroupChat,
        );
      }
    });
    ref.read(messageReplyProvider.notifier).update((state) => null);
  }

  void setChatMessageSeen(
    BuildContext context,
    String receiverUserId,
    String messageId,
  ) {
    chatRepository.setChatMessageSeen(
      context,
      receiverUserId,
      messageId,
    );
  }
  
  Future<void> markConversationRead(
    BuildContext context,
    String contactId,
    bool isGroupChat,
  ) async {
    await chatRepository.markConversationRead(
      context, 
      contactId, 
      isGroupChat
    );
  }
}