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
import 'package:mk_mesenger/common/models/user_model.dart';
import 'package:mk_mesenger/common/providers/message_reply_provider.dart';
import 'package:mk_mesenger/common/repositories/common_firebase_storage_repository.dart';
import 'package:mk_mesenger/common/utils/utils.dart';
import 'package:mk_mesenger/common/utils/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as contacts;

final chatRepositoryProvider = Provider(
  (ref) => ChatRepository(
    firestore: FirebaseFirestore.instance,
    auth: FirebaseAuth.instance,
  ),
);

class ChatRepository {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  
  ChatRepository({
    required this.firestore,
    required this.auth,
  });

  Stream<List<ChatContact>> getChatContacts() {
    final user = auth.currentUser;
    if (user == null) {
      return Stream.value([]); // Retornar lista vacía si no hay usuario
    }
    
    return firestore
        .collection('users')
        .doc(user.uid)
        .collection('chats')
        .snapshots()
        .asyncMap((snapshot) async {
      List<ChatContact> contacts = [];
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          final contactId = doc.id;
          
          // Verificar si es un chat grupal según los datos o el ID
          final bool isGroup = data['isGroup'] == true || _isGroupChat(contactId);
          
          // Si es un grupo, lo saltamos completamente
          if (isGroup) {
            continue;
          }
          
          // Es un chat individual, procesarlo
          var chatContact = ChatContact.fromMap(data);
          
          // Obtener información actualizada del otro usuario
          var userSnap = await firestore.collection('users').doc(chatContact.contactId).get();
          if (userSnap.exists) {
            var userData = UserModel.fromMap(userSnap.data()!);
            contacts.add(ChatContact(
              name: userData.name,
              profilePic: userData.profilePic,
              contactId: userData.uid,
              timeSent: chatContact.timeSent,
              lastMessage: chatContact.lastMessage,
              phoneNumber: userData.phoneNumber,
              unreadCount: data['unreadCount'] ?? 0,
              isPinned: data['isPinned'] ?? false,
              pinnedOrder: data['pinnedOrder'] ?? 0,
            ));
          }
        } catch (e) {
          logError('ChatRepository', 'Error procesando contacto de chat', e);
        }
      }
      
      // Ordenar los contactos por tiempo de envío (más recientes primero)
      contacts.sort((a, b) => b.timeSent.compareTo(a.timeSent));
      
      return contacts;
    });
  }

  // Método para obtener el conteo total de chats no leídos
  Stream<int> getUnreadChatsCount() {
    final user = auth.currentUser;
    if (user == null) {
      return Stream.value(0);
    }
    
    return firestore
        .collection('users')
        .doc(user.uid)
        .collection('chats')
        .snapshots()
        .map((snapshot) {
          int count = 0;
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final unreadCount = data['unreadCount'] ?? 0;
            if (unreadCount > 0) {
              count++;
            }
          }
          return count;
        });
  }

  // Método para buscar mensajes que contengan un texto específico
  Stream<List<SearchResult>> searchMessages(String query) {
    final user = auth.currentUser;
    if (user == null || query.isEmpty) {
      return Stream.value([]);
    }
    
    // Convertir a minúsculas para búsqueda insensible a mayúsculas/minúsculas
    final lowerQuery = query.toLowerCase();
    
    // Buscar en todos los chats del usuario
    return firestore
        .collection('users')
        .doc(user.uid)
        .collection('chats')
        .snapshots()
        .asyncMap((chatSnapshot) async {
          List<SearchResult> results = [];
          
          for (var chatDoc in chatSnapshot.docs) {
            final contactId = chatDoc.id;
            final chatData = chatDoc.data();
            
            // Obtener información sobre el contacto
            String contactName = chatData['name'] ?? '';
            String contactProfilePic = chatData['profilePic'] ?? '';
            String? phoneNumber = chatData['phoneNumber']; // Guardar el número de teléfono
            bool isGroup = chatData['isGroup'] ?? false;
            
            // Obtener mensajes de este chat que contengan la consulta
            final messagesSnapshot = await firestore
                .collection('users')
                .doc(user.uid)
                .collection('chats')
                .doc(contactId)
                .collection('messages')
                .get();
            
            for (var msgDoc in messagesSnapshot.docs) {
              final msgData = msgDoc.data();
              final msgText = msgData['text'] as String? ?? '';
              final msgType = (msgData['type'] as String?)?.toEnum() ?? MessageEnum.text;
              
              // Solo buscar coincidencias en el texto del mensaje
              if (msgText.toLowerCase().contains(lowerQuery)) {
                // Construir el snippet con contexto
                final snippet = _buildSnippet(msgText, lowerQuery);
                
                // Determinar quién envió el mensaje
                final isSentByMe = msgData['senderId'] == user.uid;
                
                // Agregar a resultados
                results.add(SearchResult(
                  contactId: contactId,
                  messageId: msgDoc.id,
                  text: msgText,
                  snippet: snippet,
                  matchIndex: msgText.toLowerCase().indexOf(lowerQuery),
                  matchLength: lowerQuery.length,
                  isSentByMe: isSentByMe,
                  timeSent: DateTime.fromMillisecondsSinceEpoch(msgData['timeSent']),
                  contactName: contactName,
                  contactProfilePic: contactProfilePic,
                  isGroup: isGroup,
                  messageType: msgType,
                  phoneNumber: phoneNumber, // Pasar el número de teléfono
                ));
              }
            }
          }
          
          // Ordenar resultados por tiempo, más recientes primero
          results.sort((a, b) => b.timeSent.compareTo(a.timeSent));
          
          return results;
        });
  }
  
  // Método auxiliar para construir un snippet de texto con contexto
  String _buildSnippet(String text, String query) {
    final lowerText = text.toLowerCase();
    final matchIndex = lowerText.indexOf(query);
    
    if (matchIndex == -1) return text;
    
    // Determinar cuánto contexto mostrar antes y después
    final contextLength = 15; // caracteres de contexto
    
    int startIndex = matchIndex - contextLength;
    if (startIndex < 0) startIndex = 0;
    
    int endIndex = matchIndex + query.length + contextLength;
    if (endIndex > text.length) endIndex = text.length;
    
    String snippet = text.substring(startIndex, endIndex);
    
    // Agregar elipsis si estamos truncando
    if (startIndex > 0) snippet = '...$snippet';
    if (endIndex < text.length) snippet = '$snippet...';
    
    return snippet;
  }

  // Método para alternar el estado destacado de un chat
  Future<void> togglePinnedChat(String contactId, bool isPinned) async {
    final user = auth.currentUser;
    if (user == null) return;
    
    // Si estamos anclando, necesitamos asignar un orden
    int pinnedOrder = 0;
    if (isPinned) {
      // Obtener el máximo orden actual de chats anclados
      final pinnedChatsSnapshot = await firestore
          .collection('users')
          .doc(user.uid)
          .collection('chats')
          .where('isPinned', isEqualTo: true)
          .get();
      
      for (var doc in pinnedChatsSnapshot.docs) {
        final order = doc.data()['pinnedOrder'] ?? 0;
        if (order > pinnedOrder) pinnedOrder = order;
      }
      
      // Incrementar para tener el siguiente orden
      pinnedOrder++;
    }
    
    // Actualizar el chat
    await firestore
        .collection('users')
        .doc(user.uid)
        .collection('chats')
        .doc(contactId)
        .update({
          'isPinned': isPinned,
          'pinnedOrder': isPinned ? pinnedOrder : 0,
        });
  }

  // Método para marcar una conversación como leída completamente
  Future<void> markConversationRead(
    BuildContext context,
    String contactId,
    bool isGroupChat,
  ) async {
    try {
      final user = auth.currentUser;
      if (user == null) return;
      
      if (isGroupChat) {
        // Actualizar para chats grupales
        await firestore
            .collection('users')
            .doc(user.uid)
            .collection('chats')
            .doc(contactId)
            .update({
              'unreadCount': 0,
            });
      } else {
        // Actualizar para chats individuales
        await firestore
            .collection('users')
            .doc(user.uid)
            .collection('chats')
            .doc(contactId)
            .update({
              'unreadCount': 0,
            });
        
        // También actualizar todos los mensajes como vistos
        final messages = await firestore
            .collection('users')
            .doc(user.uid)
            .collection('chats')
            .doc(contactId)
            .collection('messages')
            .where('isSeen', isEqualTo: false)
            .where('senderId', isNotEqualTo: user.uid) // Solo los que no son míos
            .get();
        
        for (final doc in messages.docs) {
          await doc.reference.update({'isSeen': true});
          
          // También actualizar en la colección del otro usuario
          await firestore
              .collection('users')
              .doc(contactId)
              .collection('chats')
              .doc(user.uid)
              .collection('messages')
              .doc(doc.id)
              .update({'isSeen': true});
        }
      }
    } catch (e) {
      showSnackBar(context: context, content: 'Error al marcar como leído: $e');
    }
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
    await firestore.collection('groups').doc(groupId).update({
      'lastMessage': text,
      'timeSent': time.millisecondsSinceEpoch,
    });
  }
  
  // Método auxiliar para verificar si un ID corresponde a un grupo
  bool _isGroupChat(String id) {
    // Verifica si el ID está en la colección de grupos
    return id.startsWith('group_') || id.contains('_group_');
  }

  Stream<List<Group>> getChatGroups() {
    final user = auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }
    
    return firestore.collection('groups').snapshots().map((snapshot) {
      List<Group> groups = [];
      for (var doc in snapshot.docs) {
        var groupData = doc.data();
        
        // Filtrar lastMessage si es una notificación (comprobando el contenido)
        String lastMessage = groupData['lastMessage'] ?? '';
        if (lastMessage.contains('eventId:') || 
            lastMessage.contains('Nuevo evento') || 
            lastMessage.startsWith('€')) {
          // Buscar el último mensaje no-notificación para este grupo
          groupData['lastMessage'] = ''; // O algún valor como "Nuevo mensaje"
        }
        
        var group = Group.fromMap(groupData);
        if (group.membersUid.contains(user.uid)) {
          groups.add(group);
        }
      }
      return groups;
    });
  }

  // CORREGIDO: Usar asyncExpand en lugar de switchMap que no está disponible
  Stream<List<Message>> getChatStream(String receiverUserId) {
    final user = auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }
    
    logInfo('ChatRepository', 'Obteniendo stream de chat para: $receiverUserId');
    
    // Verificamos si el documento principal de chat existe
    return firestore
        .collection('users')
        .doc(user.uid)
        .collection('chats')
        .doc(receiverUserId)
        .get()
        .asStream()
        .asyncExpand((doc) {
          // Si existe la conversación, obtenemos los mensajes
          if (doc.exists) {
            logInfo('ChatRepository', 'Documento de chat encontrado, obteniendo mensajes');
            
            return firestore
                .collection('users')
                .doc(user.uid)
                .collection('chats')
                .doc(receiverUserId)
                .collection('messages')
                .orderBy('timeSent')
                .snapshots()
                .map((snapshot) {
                  List<Message> messages = [];
                  for (var doc in snapshot.docs) {
                    try {
                      messages.add(Message.fromMap(doc.data()));
                    } catch (e) {
                      logError('ChatRepository', 'Error convirtiendo mensaje', e);
                    }
                  }
                  logInfo('ChatRepository', 'Obtenidos ${messages.length} mensajes');
                  return messages;
                });
          } else {
            // Si no existe el documento principal, intentar recuperarlo
            logWarning('ChatRepository', 'Documento de chat no encontrado para: $receiverUserId, intentando recuperar');
            
            _recreateConversationIfNeeded(user.uid, receiverUserId);
            
            // Mientras tanto, retornar una lista vacía
            return Stream.value([]);
          }
        });
  }

  // Función que intenta recuperar conversaciones "perdidas"
  Future<void> _recreateConversationIfNeeded(String currentUserId, String contactId) async {
    try {
      logInfo('ChatRepository', 'Intentando recuperar conversación: $currentUserId <-> $contactId');
      
      // Verificar si hay mensajes en la base de datos
      final messagesQuery = await firestore
          .collection('users')
          .doc(currentUserId)
          .collection('chats')
          .doc(contactId)
          .collection('messages')
          .limit(1)
          .get();
      
      if (messagesQuery.docs.isNotEmpty) {
        logInfo('ChatRepository', '¡Encontrados mensajes huérfanos! Recuperando conversación...');
        
        // Obtener información del contacto
        final contactDoc = await firestore.collection('users').doc(contactId).get();
        if (contactDoc.exists) {
          final contactData = contactDoc.data()!;
          
          // Crear o actualizar documento principal de chat
          final chatContact = ChatContact(
            name: contactData['name'] ?? '',
            profilePic: contactData['profilePic'] ?? '',
            contactId: contactId,
            timeSent: DateTime.now(),
            lastMessage: 'Conversación recuperada',
            phoneNumber: contactData['phoneNumber'],
            isGroup: false,
            unreadCount: 0,
          );
          
          // Crear documento principal sin sobrescribir los mensajes
          await firestore
              .collection('users')
              .doc(currentUserId)
              .collection('chats')
              .doc(contactId)
              .set(chatContact.toMap());
          
          // También asegurar que existe en el otro usuario
          final currentUserDoc = await firestore.collection('users').doc(currentUserId).get();
          if (currentUserDoc.exists) {
            final currentUserData = currentUserDoc.data()!;
            
            final reciprocalChatContact = ChatContact(
              name: currentUserData['name'] ?? '',
              profilePic: currentUserData['profilePic'] ?? '',
              contactId: currentUserId,
              timeSent: DateTime.now(),
              lastMessage: 'Conversación recuperada',
              phoneNumber: currentUserData['phoneNumber'],
              isGroup: false,
              unreadCount: 0,
            );
            
            // Crear en el otro usuario
            await firestore
                .collection('users')
                .doc(contactId)
                .collection('chats')
                .doc(currentUserId)
                .set(reciprocalChatContact.toMap());
          }
          
          logInfo('ChatRepository', '¡Conversación recuperada correctamente!');
        } else {
          logWarning('ChatRepository', 'No se encontró el documento del contacto');
        }
      } else {
        logInfo('ChatRepository', 'No se encontraron mensajes para recuperar');
      }
    } catch (e, stack) {
      logError('ChatRepository', 'Error recuperando conversación', e, stack);
    }
  }

  Stream<List<Message>> getGroupChatStream(String groupId) {
    final user = auth.currentUser;
    if (user == null) return Stream.value([]);

    return firestore
        .collection('groups')
        .doc(groupId)
        .collection('chats')
        .orderBy('timeSent', descending: false)    
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();

            // Conversión segura de timeSent:
            final dynamic ts = data['timeSent'];
            final DateTime time = ts is Timestamp
              ? ts.toDate()
              : DateTime.fromMillisecondsSinceEpoch(ts as int);

            return Message(
              messageId: doc.id,
              senderId: data['senderId'] as String,
              // Para grupales, recieverid = groupId
              recieverid: groupId,
              text: data['text'] as String,
              type: MessageEnum.values.firstWhere(
                (e) => e.name == data['type'],
                orElse: () => MessageEnum.text,
              ),
              timeSent: time,
              isSeen: data['isSeen'] as bool,
              repliedMessage: data['repliedMessage'] as String? ?? '',
              repliedTo: data['repliedTo'] as String? ?? '',
              repliedMessageType: MessageEnum.values.firstWhere(
                (e) => e.name == (data['repliedMessageType'] as String? ?? ''),
                orElse: () => MessageEnum.text,
              ),
            );
          }).toList();
        });
  }

  Future<void> _saveDataToContactsSubcollection(
    UserModel senderUser,
    UserModel? receiverUser,
    String text,
    DateTime timeSent,
    String receiverUserId,
    bool isGroupChat,
  ) async {
    if (isGroupChat) {
      // 1. Actualizar el documento del grupo
      await firestore.collection('groups').doc(receiverUserId).update({
        'lastMessage': text,
        'timeSent': DateTime.now().millisecondsSinceEpoch,
      });
      
      // 2. Obtener datos del grupo
      final groupDoc = await firestore.collection('groups').doc(receiverUserId).get();
      if (groupDoc.exists) {
        final groupData = groupDoc.data()!;
        final String groupName = groupData['name'] ?? 'Grupo';
        final String groupPic = groupData['groupPic'] ?? '';
        final List<dynamic> membersUid = groupData['membersUid'] ?? [];
        
        // 3. Actualizar la entrada en la colección de chats de todos los miembros del grupo
        for (final memberId in membersUid) {
          // Incrementar contador para todos menos el remitente
          int unreadCount = 0;
          if (memberId != senderUser.uid) {
            // Obtener conteo actual y aumentarlo en 1
            final chatDoc = await firestore
                .collection('users')
                .doc(memberId)
                .collection('chats')
                .doc(receiverUserId)
                .get();
            
            if (chatDoc.exists) {
              unreadCount = (chatDoc.data()?['unreadCount'] ?? 0) + 1;
            } else {
              unreadCount = 1; // Primer mensaje no leído
            }
          }
          
          // Mantener propiedades de anclaje existentes
          bool isPinned = false;
          int pinnedOrder = 0;
          
          final existingDoc = await firestore
              .collection('users')
              .doc(memberId)
              .collection('chats')
              .doc(receiverUserId)
              .get();
          
          if (existingDoc.exists) {
            isPinned = existingDoc.data()?['isPinned'] ?? false;
            pinnedOrder = existingDoc.data()?['pinnedOrder'] ?? 0;
          }
          
          var groupChatContact = ChatContact(
            name: groupName,
            profilePic: groupPic,
            contactId: receiverUserId, // ID del grupo
            timeSent: timeSent,
            lastMessage: text,
            phoneNumber: '', // Los grupos no tienen número de teléfono
            isGroup: true,
            unreadCount: memberId == senderUser.uid ? 0 : unreadCount, // 0 para remitente, incrementado para otros
            isPinned: isPinned,
            pinnedOrder: pinnedOrder,
          );
          
          await firestore
              .collection('users')
              .doc(memberId)
              .collection('chats')
              .doc(receiverUserId) // Usar ID del grupo como ID del documento
              .set(groupChatContact.toMap());
        }
      }
    } else {
      // Chat individual - Actualizar para el receptor
      int receiverUnreadCount = 0;
      bool receiverIsPinned = false;
      int receiverPinnedOrder = 0;
      
      final receiverChatDoc = await firestore
          .collection('users')
          .doc(receiverUserId)
          .collection('chats')
          .doc(auth.currentUser!.uid)
          .get();
      
      if (receiverChatDoc.exists) {
        receiverUnreadCount = (receiverChatDoc.data()?['unreadCount'] ?? 0) + 1;
        receiverIsPinned = receiverChatDoc.data()?['isPinned'] ?? false;
        receiverPinnedOrder = receiverChatDoc.data()?['pinnedOrder'] ?? 0;
      } else {
        receiverUnreadCount = 1; // Primer mensaje no leído
      }
      
      var receiverChatContact = ChatContact(
        name: senderUser.name,
        profilePic: senderUser.profilePic,
        contactId: senderUser.uid,
        timeSent: timeSent,
        lastMessage: text,
        phoneNumber: senderUser.phoneNumber,
        isGroup: false,
        unreadCount: receiverUnreadCount, // Incrementar contador para receptor
        isPinned: receiverIsPinned,
        pinnedOrder: receiverPinnedOrder,
      );
      
      await firestore
          .collection('users')
          .doc(receiverUserId)
          .collection('chats')
          .doc(auth.currentUser!.uid)
          .set(receiverChatContact.toMap());
      
      // Actualizar para el remitente (sin incrementar contador)
      bool senderIsPinned = false;
      int senderPinnedOrder = 0;
      
      final senderChatDoc = await firestore
          .collection('users')
          .doc(auth.currentUser!.uid)
          .collection('chats')
          .doc(receiverUserId)
          .get();
      
      if (senderChatDoc.exists) {
        senderIsPinned = senderChatDoc.data()?['isPinned'] ?? false;
        senderPinnedOrder = senderChatDoc.data()?['pinnedOrder'] ?? 0;
      }
      
      var senderChatContact = ChatContact(
        name: receiverUser!.name,
        profilePic: receiverUser.profilePic,
        contactId: receiverUser.uid,
        timeSent: timeSent,
        lastMessage: text,
        phoneNumber: receiverUser.phoneNumber,
        isGroup: false,
        unreadCount: 0, // Para el remitente siempre es 0 (sus propios mensajes)
        isPinned: senderIsPinned,
        pinnedOrder: senderPinnedOrder,
      );
      
      await firestore
          .collection('users')
          .doc(auth.currentUser!.uid)
          .collection('chats')
          .doc(receiverUserId)
          .set(senderChatContact.toMap());
    }
  }

  Future<void> _saveMessageToMessageSubcollection({
    required String receiverUserId,
    required String text,
    required DateTime timeSent,
    required String messageId,
    required String username,
    required MessageEnum messageType,
    required MessageReply? messageReply,
    required String senderUsername,
    required String? receiverUserName,
    required bool isGroupChat,
  }) async {
    final message = Message(
      senderId: auth.currentUser!.uid,
      recieverid: receiverUserId,
      text: text,
      type: messageType,
      timeSent: timeSent,
      messageId: messageId,
      isSeen: false,
      repliedMessage: messageReply == null ? '' : messageReply.message,
      repliedTo: messageReply == null ? '' : (messageReply.isMe ? senderUsername : receiverUserName ?? ''),
      repliedMessageType: messageReply == null ? MessageEnum.text : messageReply.messageEnum,
    );
    if (isGroupChat) {
      await firestore.collection('groups').doc(receiverUserId).collection('chats').doc(messageId).set(message.toMap());
    } else {
      await firestore
          .collection('users')
          .doc(auth.currentUser!.uid)
          .collection('chats')
          .doc(receiverUserId)
          .collection('messages')
          .doc(messageId)
          .set(message.toMap());
      await firestore
          .collection('users')
          .doc(receiverUserId)
          .collection('chats')
          .doc(auth.currentUser!.uid)
          .collection('messages')
          .doc(messageId)
          .set(message.toMap());
    }
  }

  Future<void> sendTextMessage({
    required BuildContext context,
    required String text,
    required String receiverUserId,
    required UserModel senderUser,
    required MessageReply? messageReply,
    required bool isGroupChat,
  }) async {
    try {
      var timeSent = DateTime.now();
      UserModel? receiverUserData;
      if (!isGroupChat) {
        var userSnap = await firestore.collection('users').doc(receiverUserId).get();
        if (userSnap.exists) {
          receiverUserData = UserModel.fromMap(userSnap.data()!);
        } else {
          throw Exception('El usuario receptor no existe');
        }
      }
      var messageId = const Uuid().v1();
      await _saveDataToContactsSubcollection(senderUser, receiverUserData, text, timeSent, receiverUserId, isGroupChat);
      await _saveMessageToMessageSubcollection(
        receiverUserId: receiverUserId,
        text: text,
        timeSent: timeSent,
        messageType: MessageEnum.text,
        messageId: messageId,
        username: senderUser.name,
        messageReply: messageReply,
        receiverUserName: receiverUserData?.name,
        senderUsername: senderUser.name,
        isGroupChat: isGroupChat,
      );
    } catch (e) {
      showSnackBar(context: context, content: e.toString());
    }
  }

  Future<void> sendFileMessage({
    required BuildContext context,
    required File file,
    required String receiverUserId,
    required MessageEnum messageEnum,
    required bool isGroupChat,
    required dynamic ref,
    required MessageReply? messageReply,
    required UserModel senderUserData,
  }) async {
    try {
      var timeSent = DateTime.now();
      var messageId = const Uuid().v1();
      String imageUrl = await ref
          .read(commonFirebaseStorageRepositoryProvider)
          .storeFileToFirebase('chat/${messageEnum.type}/${senderUserData.uid}/$receiverUserId/$messageId', file);
      UserModel? receiverUserData;
      if (!isGroupChat) {
        var userSnap = await firestore.collection('users').doc(receiverUserId).get();
        if (userSnap.exists) {
          receiverUserData = UserModel.fromMap(userSnap.data()!);
        }
      }
      String contactMsg;
      switch (messageEnum) {
        case MessageEnum.image:
          contactMsg = '📷 Photo';
          break;
        case MessageEnum.video:
          contactMsg = '📸 Video';
          break;
        case MessageEnum.audio:
          contactMsg = '🎵 Audio';
          break;
        case MessageEnum.gif:
          contactMsg = 'GIF';
          break;
        default:
          contactMsg = 'GIF';
      }
      await _saveDataToContactsSubcollection(senderUserData, receiverUserData, contactMsg, timeSent, receiverUserId, isGroupChat);
      await _saveMessageToMessageSubcollection(
        receiverUserId: receiverUserId,
        text: imageUrl,
        timeSent: timeSent,
        messageId: messageId,
        username: senderUserData.name,
        messageType: messageEnum,
        messageReply: messageReply,
        receiverUserName: receiverUserData?.name,
        senderUsername: senderUserData.name,
        isGroupChat: isGroupChat,
      );
    } catch (e) {
      showSnackBar(context: context, content: e.toString());
    }
  }

  Future<void> sendGIFMessage({
    required BuildContext context,
    required String gifUrl,
    required String receiverUserId,
    required bool isGroupChat,
    required MessageReply? messageReply,
    required UserModel senderUser,
  }) async {
    try {
      var timeSent = DateTime.now();
      UserModel? receiverUserData;
      if (!isGroupChat) {
        var userSnap = await firestore.collection('users').doc(receiverUserId).get();
        if (userSnap.exists) {
          receiverUserData = UserModel.fromMap(userSnap.data()!);
        }
      }
      var messageId = const Uuid().v1();
      await _saveDataToContactsSubcollection(senderUser, receiverUserData, 'GIF', timeSent, receiverUserId, isGroupChat);
      await _saveMessageToMessageSubcollection(
        receiverUserId: receiverUserId,
        text: gifUrl,
        timeSent: timeSent,
        messageType: MessageEnum.gif,
        messageId: messageId,
        username: senderUser.name,
        messageReply: messageReply,
        receiverUserName: receiverUserData?.name,
        senderUsername: senderUser.name,
        isGroupChat: isGroupChat,
      );
    } catch (e) {
      showSnackBar(context: context, content: e.toString());
    }
  }

  Future<void> setChatMessageSeen(BuildContext context, String receiverUserId, String messageId) async {
    try {
      final currentUser = auth.currentUser;
      if (currentUser == null) return;
      
      await firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('chats')
          .doc(receiverUserId)
          .collection('messages')
          .doc(messageId)
          .update({'isSeen': true});
          
      await firestore
          .collection('users')
          .doc(receiverUserId)
          .collection('chats')
          .doc(currentUser.uid)
          .collection('messages')
          .doc(messageId)
          .update({'isSeen': true});
    } catch (e) {
      showSnackBar(context: context, content: e.toString());
    }
  }
}