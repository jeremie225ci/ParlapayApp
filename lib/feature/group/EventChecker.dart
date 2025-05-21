// lib/feature/group/utils/event_checker.dart

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mk_mesenger/feature/group/widgets/record_funds_tab.dart';

/// Servicio para verificar periódicamente el estado de eventos
/// y cerrar aquellos que hayan alcanzado su fecha límite o su objetivo
class EventChecker {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Ref _ref;
  Timer? _timer;

  EventChecker({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    required Ref ref,
  })  : _firestore = firestore,
        _auth = auth,
        _ref = ref;

  /// Iniciar la verificación periódica
  void initialize() {
    // Verificar eventos cada 15 minutos
    _timer = Timer.periodic(const Duration(minutes: 15), (timer) {
      final user = _auth.currentUser;
      if (user != null) {
        _checkUserEvents(user.uid);
      }
    });
  }

  /// Detener la verificación periódica
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  /// Verificar todos los eventos de los grupos a los que pertenece el usuario
  Future<void> _checkUserEvents(String userId) async {
    try {
      // Obtener todos los grupos donde el usuario es miembro
      final userGroups = await _firestore
          .collection('groups')
          .where('membersUid', arrayContains: userId)
          .get();
      
      final recordFundsController = RecordFundsController(
        firestore: _firestore,
        auth: _auth,
        ref: _ref,
      );
      
      // Verificar eventos para cada grupo
      for (final group in userGroups.docs) {
        final groupId = group.id;
        await recordFundsController.checkAndCloseExpiredEvents(groupId);
      }
    } catch (e) {
      print('Error verificando eventos del usuario: $e');
    }
  }

  /// Verificar eventos manualmente (útil cuando la app se inicia o se reactiva)
  Future<void> checkEventsNow() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _checkUserEvents(user.uid);
    }
  }
}

// Provider para el verificador de eventos
final eventCheckerProvider = Provider<EventChecker>((ref) {
  final eventChecker = EventChecker(
    firestore: FirebaseFirestore.instance,
    auth: FirebaseAuth.instance,
    ref: ref,
  );
  
  // Iniciar automáticamente
  eventChecker.initialize();
  
  // Verificar eventos inmediatamente al iniciar la app
  WidgetsBinding.instance.addPostFrameCallback((_) {
    eventChecker.checkEventsNow();
  });
  
  // Asegurarse de detener el timer al cerrar la app
  ref.onDispose(() {
    eventChecker.dispose();
  });
  
  return eventChecker;
});