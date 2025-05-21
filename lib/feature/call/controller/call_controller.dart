import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mk_mesenger/common/models/call.dart';
import 'package:mk_mesenger/common/utils/logger.dart';
import 'package:mk_mesenger/feature/call/repository/call_repository.dart';
import 'package:uuid/uuid.dart';

final callControllerProvider = Provider((ref) {
  final callRepository = ref.read(callRepositoryProvider);
  return CallController(
    callRepository: callRepository,
    ref: ref,
    auth: FirebaseAuth.instance,
  );
});

class CallController {
  final CallRepository callRepository;
  final ProviderRef ref;
  final FirebaseAuth auth;

  CallController({
    required this.callRepository,
    required this.ref,
    required this.auth,
  });

  Stream<DocumentSnapshot> get callStream => callRepository.callStream;
  
  // Stream para historial de llamadas
  Stream<List<Call>> get callHistory => callRepository.getCallHistory();

  // MODIFICADO: Ahora acepta el tipo de llamada como parámetro
  Call makeCall(
    BuildContext context,
    String receiverName,
    String receiverId,
    String receiverProfilePic,
    bool isGroupChat,
    {String callType = 'video'} // Cambia los corchetes [] por llaves {}
  ) {
    try {
      String callId = const Uuid().v1();
      String currentUserId = auth.currentUser!.uid;
      
      // Crear objeto Call para el emisor
      Call senderCallData = Call(
        callerId: currentUserId,
        callerName: auth.currentUser!.displayName ?? 'Usuario',
        callerPic: auth.currentUser!.photoURL ?? '',
        receiverId: receiverId,
        receiverName: receiverName,
        receiverPic: receiverProfilePic,
        callId: callId,
        hasDialled: true,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        isGroupCall: isGroupChat,
        callType: callType, // Usar el parámetro callType
        callStatus: 'ongoing',
        callTime: 0,
      );

      // Crear objeto Call para el receptor
      Call receiverCallData = Call(
        callerId: currentUserId,
        callerName: auth.currentUser!.displayName ?? 'Usuario',
        callerPic: auth.currentUser!.photoURL ?? '',
        receiverId: receiverId,
        receiverName: receiverName,
        receiverPic: receiverProfilePic,
        callId: callId,
        hasDialled: false,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        isGroupCall: isGroupChat,
        callType: callType, // Usar el parámetro callType
        callStatus: 'incoming',
        callTime: 0,
      );

      // Hacer la llamada
      callRepository.makeCall(senderCallData, receiverCallData, context);
      return senderCallData;
    } catch (e) {
      logError('CallController', 'Error en makeCall', e);
      // Devolver un objeto Call con estado de error
      return Call(
        callerId: auth.currentUser!.uid,
        callerName: auth.currentUser!.displayName ?? 'Usuario',
        callerPic: auth.currentUser!.photoURL ?? '',
        receiverId: receiverId,
        receiverName: receiverName,
        receiverPic: receiverProfilePic,
        callId: const Uuid().v1(),
        hasDialled: true,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        isGroupCall: isGroupChat,
        callType: callType,
        callStatus: 'error',
        callTime: 0,
      );
    }
  }

  // Finalizar una llamada - MODIFICADO para soportar estados
  Future<void> endCall(
    String callerId,
    String receiverId,
    BuildContext context,
    {String status = 'ended'} // NUEVO: Parámetro de estado
  ) async {
    try {
      // Pasar el estado explícitamente al repositorio
      await callRepository.endCall(callerId, receiverId, status: status);
    } catch (e) {
      logError('CallController', 'Error en endCall', e);
    }
  }
  
  // Guardar llamada en historial con estado específico
  Future<void> saveCallToHistory(Call call, {String status = 'ended'}) async {
    try {
      // Crear copia actualizada con nuevo estado
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
        callStatus: status,
        callType: call.callType,
        callTime: call.callTime,
      );
      
      await callRepository.saveCallToHistory(updatedCall);
    } catch (e) {
      logError('CallController', 'Error en saveCallToHistory', e);
    }
  }
}