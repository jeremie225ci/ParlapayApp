import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mk_mesenger/common/models/call.dart';
import 'package:mk_mesenger/common/utils/logger.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mk_mesenger/main.dart';

final callRepositoryProvider = Provider(
  (ref) => CallRepository(
    firestore: FirebaseFirestore.instance,
    auth: FirebaseAuth.instance,
    messaging: FirebaseMessaging.instance,
  ),
);

class CallRepository {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final FirebaseMessaging messaging;

  CallRepository({
    required this.firestore,
    required this.auth,
    required this.messaging,
  });

  // Stream para escuchar llamadas entrantes
  Stream<DocumentSnapshot> get callStream =>
      firestore.collection('calls').doc(auth.currentUser!.uid).snapshots();

  // Obtener historial de llamadas del usuario actual
  Stream<List<Call>> getCallHistory() {
    return firestore
        .collection('users')
        .doc(auth.currentUser!.uid)
        .collection('call_history')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Call.fromMap(doc.data())).toList();
    });
  }

  // Hacer una llamada - ACTUALIZADO PARA USAR NOTIFICATIONSERVICE
  Future<void> makeCall(
    Call senderCallData,
    Call receiverCallData,
    BuildContext context,
  ) async {
    try {
      // Guardar documentos de llamada para señalización WebRTC
      await firestore
          .collection('calls')
          .doc(senderCallData.callerId)
          .set(senderCallData.toMap());

      await firestore
          .collection('calls')
          .doc(receiverCallData.receiverId)
          .set(receiverCallData.toMap());
    
      // Enviar notificación push al receptor
      try {
        // Obtener token FCM del receptor
        final userDoc = await firestore
            .collection('users')
            .doc(receiverCallData.receiverId)
            .get();
        
        final fcmToken = userDoc.data()?['fcmToken'];
        
        if (fcmToken != null) {
          // 1. PRIMERO: enviar notificación FCM para despertar la aplicación
          await firestore.collection('notifications').add({
            'to': fcmToken,
            'priority': 'high',
            'content_available': true,
            'data': {
              'type': 'call',
              'callId': receiverCallData.callId,
              'callerId': receiverCallData.callerId,
              'callerName': receiverCallData.callerName,
              'callerPic': receiverCallData.callerPic,
              'receiverId': receiverCallData.receiverId,
              'receiverName': receiverCallData.receiverName,
              'callType': receiverCallData.callType,
              'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
              'click_action': 'FLUTTER_NOTIFICATION_CLICK'
            },
            'notification': {
              'title': '${receiverCallData.callerName} te está llamando',
              'body': receiverCallData.callType == 'video' 
                  ? 'Videollamada entrante' 
                  : 'Llamada de voz entrante',
              'android_channel_id': 'call_channel',
              'sound': 'default'
            },
            'android': {
              'priority': 'high',
              'notification': {
                'channel_id': 'call_channel',
                'priority': 'high',
                'default_sound': true,
                'default_vibrate_timings': true,
                'notification_priority': 'PRIORITY_MAX',
                'visibility': 'PUBLIC',
                'notification_count': 1
              },
            },
            'apns': {
              'headers': {
                'apns-push-type': 'background',
                'apns-priority': '10',
                'apns-topic': 'io.flutter.plugins.firebase.messaging'
              },
              'payload': {
                'aps': {
                  'category': 'CALL_INVITATION',
                  'sound': 'default',
                  'badge': 1,
                  'content-available': 1,
                  'mutable-content': 1,
                }
              }
            }
          });
          
          logInfo('CallRepository', 'Notificación FCM de llamada enviada a $fcmToken');
        } else {
          logWarning('CallRepository', 'No se encontró FCM token para el receptor');
        }
      } catch (e) {
        logError('CallRepository', 'Error enviando notificación push', e);
      }
    } catch (e) {
      logError('CallRepository', 'Error en makeCall', e);
    }
  }

  // Finalizar una llamada - COMPLETAMENTE REESCRITO
  Future<void> endCall(
    String callerId,
    String receiverId,
    {String status = 'ended'}  // Parámetro con estado por defecto
  ) async {
    try {
      // IMPORTANTE: Primero verificar si los documentos existen
      final callerDoc = await firestore.collection('calls').doc(callerId).get();
      final receiverDoc = await firestore.collection('calls').doc(receiverId).get();
      
      final callData = {
        'status': status,
        'endTimestamp': FieldValue.serverTimestamp(),
      };
      
      // Actualizar solo si existen - esto evita el error NOT_FOUND
      if (callerDoc.exists) {
        await firestore.collection('calls').doc(callerId).update(callData);
        logInfo('CallRepository', 'Estado de llamada actualizado para emisor: $status');
      }
      
      if (receiverDoc.exists) {
        await firestore.collection('calls').doc(receiverId).update(callData);
        logInfo('CallRepository', 'Estado de llamada actualizado para receptor: $status');
      }
      
      // Esperar un tiempo prudencial antes de eliminar los documentos
      await Future.delayed(Duration(seconds: 2));
      
      // Ahora sí eliminar los documentos
      try {
        if (callerDoc.exists) {
          await firestore.collection('calls').doc(callerId).delete();
        }
        
        if (receiverDoc.exists) {
          await firestore.collection('calls').doc(receiverId).delete();
        }
        
        // Limpiar colecciones de candidatos ICE
        await _cleanupIceCandidates(callerId);
        
        logInfo('CallRepository', 'Llamada finalizada entre $callerId y $receiverId');
      } catch (e) {
        // Ignorar errores durante la eliminación
        logError('CallRepository', 'Error en eliminación de documentos', e);
      }
    } catch (e) {
      logError('CallRepository', 'Error en endCall', e);
    }
  }
  
  // NUEVO: Método para limpiar candidatos ICE
  Future<void> _cleanupIceCandidates(String callId) async {
    try {
      // Intentar eliminar colecciones de candidatos
      final callerCandidatesRef = firestore
          .collection('calls')
          .doc(callId)
          .collection('candidates')
          .doc('caller_candidates')
          .collection('list');
          
      final calleeCandidatesRef = firestore
          .collection('calls')
          .doc(callId)
          .collection('candidates')
          .doc('callee_candidates')
          .collection('list');
      
      // Obtener y eliminar todos los documentos de candidatos caller
      final callerSnapshot = await callerCandidatesRef.get();
      for (var doc in callerSnapshot.docs) {
        await doc.reference.delete();
      }
      
      // Obtener y eliminar todos los documentos de candidatos callee
      final calleeSnapshot = await calleeCandidatesRef.get();
      for (var doc in calleeSnapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      // Ignorar errores, esto es solo limpieza
      logError('CallRepository', 'Error limpiando candidatos ICE', e);
    }
  }

  // Guardar llamada en historial
  Future<void> saveCallToHistory(Call call) async {
    try {
      // NUEVA IMPLEMENTACIÓN: Guardamos en 3 lugares
      
      // 1. En la colección global de historial (para estadísticas o admin)
      await firestore
          .collection('calls_history')
          .doc(call.callId)
          .set(call.toMap());
      
      // 2. En el historial del llamante
      await firestore
          .collection('users')
          .doc(call.callerId)
          .collection('call_history')
          .doc(call.callId)
          .set(call.toMap());
          
      // 3. En el historial del receptor  
      await firestore
          .collection('users')
          .doc(call.receiverId)
          .collection('call_history')
          .doc(call.callId)
          .set(call.toMap());
      
      // 4. Añadir entrada en el chat (como un mensaje)
      await _addCallEntryToChat(call);
      
      logInfo('CallRepository', 'Llamada guardada en historial: ${call.callId} - Estado: ${call.callStatus}');
    } catch (e) {
      logError('CallRepository', 'Error en saveCallToHistory', e);
    }
  }
  
  // Método para añadir mensaje de llamada al chat
  Future<void> _addCallEntryToChat(Call call) async {
    try {
      final currentUserId = auth.currentUser!.uid;
      final String chatId = call.isGroupCall ? call.receiverId : 
          (currentUserId == call.callerId ? call.receiverId : call.callerId);
      
      // Crear mensaje tipo llamada con ID único
      final String uniqueMessageId = '${call.callId}_${DateTime.now().millisecondsSinceEpoch}';
      
      // Mapa compatible con la estructura Message
      final callMessage = {
        'senderId': call.callerId,
        'recieverid': call.receiverId,
        'text': _getCallStatusMessage(call),
        'type': call.callType == 'video' ? 'video_call' : 'audio_call',
        'timeSent': call.timestamp,
        'messageId': uniqueMessageId,
        'isSeen': false,
        'repliedMessage': '',
        'repliedTo': '',
        'repliedMessageType': 'text',
        'callStatus': call.callStatus,
        'callDuration': call.callTime,
      };
      
      if (call.isGroupCall) {
        await firestore
            .collection('groups')
            .doc(chatId)
            .collection('chats')
            .doc(uniqueMessageId)
            .set(callMessage);
      } else {
        await firestore
            .collection('users')
            .doc(call.callerId)
            .collection('chats')
            .doc(call.receiverId)
            .collection('messages')
            .doc(uniqueMessageId)
            .set(callMessage);
            
        await firestore
            .collection('users')
            .doc(call.receiverId)
            .collection('chats')
            .doc(call.callerId)
            .collection('messages')
            .doc(uniqueMessageId)
            .set(callMessage);
      }
    } catch (e) {
      logError('CallRepository', 'Error añadiendo entrada de llamada al chat', e);
    }
  }
  
  // Generar mensaje según estado de la llamada
  String _getCallStatusMessage(Call call) {
    String prefix = call.callType == 'video' ? 'Videollamada' : 'Llamada de voz';
    
    if (call.callerId == auth.currentUser!.uid) {
      // Llamada saliente
      if (call.callStatus == 'missed' || call.callStatus == 'rejected') {
        return '$prefix no contestada';
      } else if (call.callStatus == 'error') {
        return '$prefix fallida';
      } else if (call.callTime > 0) {
        return '$prefix saliente (${_formatCallDuration(call.callTime)})';
      } else {
        return '$prefix saliente';
      }
    } else {
      // Llamada entrante
      if (call.callStatus == 'missed') {
        return '$prefix perdida';
      } else if (call.callStatus == 'rejected') {
        return '$prefix rechazada';
      } else if (call.callTime > 0) {
        return '$prefix entrante (${_formatCallDuration(call.callTime)})';
      } else {
        return '$prefix entrante';
      }
    }
  }
  
  // Formatear duración de llamada
  String _formatCallDuration(int seconds) {
    if (seconds < 60) {
      return '$seconds seg';
    } else if (seconds < 3600) {
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      return '$minutes:${remainingSeconds.toString().padLeft(2, '0')} min';
    } else {
      final hours = seconds ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      return '$hours:${minutes.toString().padLeft(2, '0')} h';
    }
  }
  
  // MEJORADO: Manejador de notificaciones en segundo plano
  static Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    try {
      // Verificar si es una notificación de llamada
      if (message.data.containsKey('callId') && message.data.containsKey('callerId')) {
        final String callId = message.data['callId'] ?? '';
        final String callerId = message.data['callerId'] ?? '';
        final String callerName = message.data['callerName'] ?? 'Usuario';
        final String callerPic = message.data['callerPic'] ?? '';
        final String callType = message.data['callType'] ?? 'audio';
        final String receiverId = message.data['receiverId'] ?? '';
        final int timestamp = int.tryParse(message.data['timestamp'] ?? '0') ?? 
                            DateTime.now().millisecondsSinceEpoch;
        
        // Guardar datos completos de la llamada para la pantalla de llamada entrante
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pending_call', json.encode({
          'callId': callId,
          'callerId': callerId,
          'callerName': callerName,
          'callerPic': callerPic,
          'callType': callType,
          'receiverId': receiverId,
          'timestamp': timestamp,
          'hasDialled': false,
          'isGroupCall': false,
          'callStatus': 'incoming',
          'callTime': 0
        }));
        
        // Mostrar notificación de llamada entrante usando el servicio de notificaciones
        try {
          // No podemos usar directamente NotificationService.showIncomingCallNotification aquí
          // porque estamos en un contexto estático, pero podemos preparar todo
          // para que la app muestre la notificación cuando se inicie
          
          // Intentar configurar la llamada para mostrarla cuando la app se active
          await prefs.setString('call_action', json.encode({
            'action': 'show_incoming_call',
            'callId': callId,
            'callerId': callerId,
            'callerName': callerName,
            'callType': callType,
            'receiverId': receiverId,
            'timestamp': DateTime.now().millisecondsSinceEpoch
          }));
          
          print('Datos de llamada entrante guardados para mostrar notificación cuando la app se active');
        } catch (e) {
          print('Error configurando notificación de llamada: $e');
        }
      }
    } catch (e) {
      print('Error en CallRepository.firebaseMessagingBackgroundHandler: $e');
    }
  }
}