// lib/feature/group/widgets/record_funds_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:mk_mesenger/common/utils/utils.dart';
import 'package:mk_mesenger/feature/chat/controller/chat_controller.dart';
import 'package:mk_mesenger/feature/group/widgets/EventDetailsScreen.dart';
import 'package:uuid/uuid.dart';
import 'package:mk_mesenger/common/enums/message_enum.dart';
import 'package:mk_mesenger/common/utils/colors.dart';
import 'package:mk_mesenger/feature/wallet/controller/wallet_controller.dart';
import 'package:mk_mesenger/common/models/wallet.dart';

// Provider para eventos activos
final activeEventsProvider = StreamProvider.family<
  List<Map<String, dynamic>>,
  String
>((ref, groupId) {
  return ref
    .read(recordFundsControllerProvider)
    .getGroupActiveEvents(groupId);
});

// Estado de selección de destinatario para el evento
final selectedRecipientProvider = StateProvider<String?>((ref) => null);

// Provider para el controlador de eventos de fondos
final recordFundsControllerProvider = Provider((ref) {
  return RecordFundsController(
    firestore: FirebaseFirestore.instance,
    auth: FirebaseAuth.instance,
    ref: ref,
  );
});

class RecordFundsController {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final Ref ref;

  RecordFundsController({
    required this.firestore,
    required this.ref,
    required this.auth,
  });

  // Método para diagnosticar un evento
  Future<Map<String, dynamic>> diagnoseFundEvent(String eventId) async {
    try {
      final result = <String, dynamic>{};
      
      // Verificar el evento
      final eventDoc = await firestore.collection('fund_events').doc(eventId).get();
      if (!eventDoc.exists) {
        result['event_status'] = 'not_found';
        return result;
      }
      
      final eventData = eventDoc.data()!;
      result['event_status'] = 'found';
      result['event_data'] = eventData;
      
      // Verificar la wallet del creador
      final creatorId = eventData['creatorId'] as String? ?? '';
      if (creatorId.isNotEmpty) {
        final creatorWallet = await firestore.collection('wallets').doc(creatorId).get();
        result['creator_wallet_exists'] = creatorWallet.exists;
      }
      
      // Verificar la wallet del destinatario
      final recipientId = eventData['recipientId'] as String? ?? '';
      if (recipientId.isNotEmpty) {
        final recipientWallet = await firestore.collection('wallets').doc(recipientId).get();
        result['recipient_wallet_exists'] = recipientWallet.exists;
      }
      
      // Verificar la wallet del usuario actual
      final currentUser = auth.currentUser;
      if (currentUser != null) {
        final userWallet = await firestore.collection('wallets').doc(currentUser.uid).get();
        result['user_wallet_exists'] = userWallet.exists;
        if (userWallet.exists) {
          result['user_wallet_balance'] = userWallet.data()?['balance'] ?? 0.0;
        }
      }
      
      return result;
    } catch (e) {
      print('Error en diagnoseFundEvent: $e');
      return {'error': e.toString()};
    }
  }

  // Crear nuevo evento de recaudación de fondos
  Future<bool> createFundEvent({
    required BuildContext context,
    required String groupId,
    required String title,
    required double amount,
    required String purpose,
    required String recipientId,
    DateTime? deadline,
  }) async {
    try {
      final currentUser = auth.currentUser!;
      final eventId = const Uuid().v1();

      // Verificar si el destinatario tiene una wallet
      final recipientWalletSnap = await firestore.collection('wallets').doc(recipientId).get();
      if (!recipientWalletSnap.exists) {
        // Si no tiene wallet, verificar si debemos crear una
        bool createWallet = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: containerColor,
            title: const Text(
              'El destinatario no tiene wallet',
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
            ),
            content: const Text(
              'Para recibir fondos, el destinatario necesita tener una wallet. ¿Deseas crear una wallet para este usuario?',
              style: TextStyle(color: textColor),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                style: TextButton.styleFrom(foregroundColor: Colors.grey),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Crear Wallet'),
              ),
            ],
          ),
        ) ?? false;
        
        if (createWallet) {
          // Crear wallet para el destinatario
          await firestore.collection('wallets').doc(recipientId).set({
            'userId': recipientId,
            'balance': 0.0,
            'kycCompleted': false,
            'kycStatus': 'pending',
            'accountStatus': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          });
          
          showSnackBar(
            context: context, 
            content: 'Se ha creado una wallet para el destinatario'
          );
        } else {
          showSnackBar(
            context: context, 
            content: 'No se puede crear el evento sin wallet de destinatario'
          );
          return false;
        }
      }

      // 1. Crear el documento del evento
      await firestore.collection('fund_events').doc(eventId).set({
        'eventId': eventId,
        'groupId': groupId,
        'title': title,
        'amount': amount,
        'purpose': purpose,
        'creatorId': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'recipientId': recipientId,
        'status': 'active',
        'participants': [],
        'totalCollected': 0.0,
        'deadline': deadline,
      });

      // 2. Añadir la notificación al chat
     final notificationMessage = '¡Nuevo evento de recaudación: $title! 💰 Objetivo: €${amount.toStringAsFixed(2)} - eventId:$eventId';
    
    // 1. Guardar el mensaje en la colección de chats
    final messageId = const Uuid().v1();
    await firestore
      .collection('groups')
      .doc(groupId)
      .collection('chats')
      .doc(messageId)
      .set({
        'senderId': currentUser.uid,
        'text': notificationMessage,
        'type': MessageEnum.eventNotification.name,
        'timeSent': FieldValue.serverTimestamp(),
        'messageId': messageId,
        'isSeen': false,
        'repliedMessage': '',
        'repliedTo': '',
        'repliedMessageType': '',
        'eventId': eventId,
      });
    
    // 2. IMPORTANTE: Actualizar el último mensaje
   

      showSnackBar(
        context: context, 
        content: 'Evento creado con éxito',
        backgroundColor: Colors.green,
      );
      return true;
    } catch (e) {
      showSnackBar(
        context: context, 
        content: 'Error: $e',
        backgroundColor: errorColor,
      );
      return false;
    }
  }

  // Participar en un evento (contribuir fondos) utilizando la función sendMoney
  Future<bool> participateInEvent({
    required BuildContext context,
    required String groupId,
    required String eventId,
    required double contribution,
  }) async {
    try {
      print('====== INICIO DE PARTICIPATEINEVENT (VERSIÓN MEJORADA) ======');
      final currentUser = auth.currentUser;
      if (currentUser == null) {
        print('Error: Usuario no autenticado');
        if (context.mounted) {
          showSnackBar(
            context: context, 
            content: 'Usuario no autenticado',
            backgroundColor: errorColor,
          );
        }
        return false;
      }
      
      final userId = currentUser.uid;
      
      print('Usuario autenticado: ${currentUser.uid}');
      print('Evento: $eventId');
      print('Contribución: $contribution');
      
      // Verificar si el evento existe y está activo
      print('Paso 1: Verificando evento...');
      final eventSnap = await firestore.collection('fund_events').doc(eventId).get();
      if (!eventSnap.exists) {
        print('Error: Evento no encontrado');
        if (context.mounted) {
          showSnackBar(
            context: context, 
            content: 'Evento no encontrado',
            backgroundColor: errorColor,
          );
        }
        return false;
      }
      
      final eventData = eventSnap.data() as Map<String, dynamic>;
      if (eventData['status'] != 'active') {
        print('Error: Evento no activo. Estado: ${eventData['status']}');
        if (context.mounted) {
          showSnackBar(
            context: context, 
            content: 'Este evento ya no está activo',
            backgroundColor: errorColor,
          );
        }
        return false;
      }
      
      print('Evento verificado: ${eventData['title']}');
      
      // Verificar si ya ha participado
      print('Paso 2: Verificando participación previa...');
      final participants = (eventData['participants'] as List<dynamic>? ?? []);
      if (participants.any((p) => p['userId'] == currentUser.uid)) {
        print('Error: Usuario ya ha participado');
        if (context.mounted) {
          showSnackBar(
            context: context, 
            content: 'Ya has participado en este evento',
            backgroundColor: Colors.orange,
          );
        }
        return false;
      }
      
      print('No hay participación previa');
      
      // Obtener el ID del destinatario
      final recipientId = eventData['recipientId'] as String;
      
      // Usar el controlador de wallet para enviar el dinero
      print('Paso 3: Utilizando walletController.sendMoney...');
      final walletController = ref.read(walletControllerProvider.notifier);
      
      // Comprobamos si el controller está disponible
      if (walletController == null) {
        print('Error: Controlador de wallet no disponible');
        if (context.mounted) {
          showSnackBar(
            context: context, 
            content: 'Error interno: Controlador de wallet no disponible',
            backgroundColor: errorColor,
          );
        }
        return false;
      }
      
      final success = await walletController.sendMoney(
        recipientId,
        contribution,
        context,
      );
      
      // Si la transferencia fue exitosa, actualizar el evento
      if (success) {
        print('Transferencia exitosa, actualizando evento...');
        
        try {
          final ts = Timestamp.now();
          final transactionId = const Uuid().v1();

          await firestore.collection('fund_events').doc(eventId).update({
            'participants': FieldValue.arrayUnion([
              {
                'userId': userId,
                'contribution': contribution,
                'timestamp': ts,
                'transactionId': transactionId,
              }
            ]),
            'totalCollected': FieldValue.increment(contribution),
          });
          
          print('Evento actualizado exitosamente');
          
          // Añadir notificación al chat
          await firestore
            .collection('groups')
            .doc(groupId)
            .collection('chats')
            .add({
              'senderId': currentUser.uid,
              'text': '${currentUser.displayName ?? "Un usuario"} ha contribuido €${contribution.toStringAsFixed(2)} al evento "${eventData['title']}" - eventId:$eventId',
              'type': MessageEnum.eventContribution.name,
              'timeSent': FieldValue.serverTimestamp(),
              'messageId': const Uuid().v1(),
              'isSeen': false,
              'repliedMessage': '',
              'repliedTo': '',
              'repliedMessageType': '',
              'eventId': eventId,
            });
          
          print('====== CONTRIBUCIÓN COMPLETADA CON ÉXITO ======');
          if (context.mounted) {
            // Mostrar un SnackBar informando de la contribución exitosa
            showSnackBar(
              context: context, 
              content: 'Has contribuido €${contribution.toStringAsFixed(2)} al evento',
              backgroundColor: Colors.green,
            );
          }
          return true;
        } catch (e) {
          print('Error al actualizar evento: $e');
          if (context.mounted) {
            showSnackBar(
              context: context, 
              content: 'Tu contribución fue procesada pero ocurrió un error al actualizar el evento: $e',
              backgroundColor: Colors.orange,
            );
          }
          return true; // Retornamos true porque el dinero fue enviado correctamente
        }
      } else {
        print('La transferencia falló');
        if (context.mounted) {
          showSnackBar(
            context: context, 
            content: 'No se pudo procesar la contribución',
            backgroundColor: errorColor,
          );
        }
        return false;
      }
    } catch (e) {
      print('====== ERROR EN PARTICIPATEINEVENT ======');
      print('Error detallado: $e');
      if (e is FirebaseException) {
        print('Código de error Firebase: ${e.code}, mensaje: ${e.message}');
      }
      if (context.mounted) {
        showSnackBar(
          context: context, 
          content: 'Error al contribuir: $e',
          backgroundColor: errorColor,
        );
      }
      return false;
    }
  }

  // Finalizar un evento
  Future<bool> finalizeEvent({
    BuildContext? context,
    required String eventId,
    bool automatic = false,
  }) async {
    try {
      final currentUser = auth.currentUser;
      if (currentUser == null) {
        if (context != null) {
          showSnackBar(
            context: context, 
            content: 'Usuario no autenticado',
            backgroundColor: errorColor,
          );
        }
        return false;
      }

      // 1. Obtener datos del evento
      final eventDoc = await firestore.collection('fund_events').doc(eventId).get();
      if (!eventDoc.exists) {
        if (context != null) {
          showSnackBar(
            context: context, 
            content: 'Evento no encontrado',
            backgroundColor: errorColor,
          );
        }
        return false;
      }

      final eventData = eventDoc.data() as Map<String, dynamic>;

      // Solo el creador puede finalizar el evento manualmente
      if (!automatic && eventData['creatorId'] != currentUser.uid) {
        if (context != null) {
          showSnackBar(
            context: context, 
            content: 'Solo el creador puede finalizar el evento',
            backgroundColor: errorColor,
          );
        }
        return false;
      }

      if (eventData['status'] != 'active') {
        if (context != null) {
          showSnackBar(
            context: context, 
            content: 'Este evento ya fue finalizado',
            backgroundColor: Colors.orange,
          );
        }
        return false;
      }

      final recipientId = eventData['recipientId'] as String;
      final double totalCollected = (eventData['totalCollected'] as num?)?.toDouble() ?? 0.0;
      
      print('Finalizando evento: $eventId');
      print('Total recaudado: $totalCollected');
      print('Destinatario: $recipientId');

      // Simplemente marcar el evento como completado
      await firestore.collection('fund_events').doc(eventId).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Notificar en el chat
      final groupId = eventData['groupId'] as String;
      String messageText;

      if (automatic) {
        final Timestamp? deadlineTs = eventData['deadline'] as Timestamp?;
        final DateTime? deadline = deadlineTs?.toDate();
        final double targetAmount = (eventData['amount'] as num?)?.toDouble() ?? 0.0;

        if (deadline != null && DateTime.now().isAfter(deadline)) {
          messageText =
            'El evento "${eventData['title']}" ha finalizado automáticamente por fecha límite. ' +
            'Se recaudó un total de €${totalCollected.toStringAsFixed(2)}. - eventId:$eventId';
        } else if (totalCollected >= targetAmount) {
          messageText =
            'El evento "${eventData['title']}" ha finalizado automáticamente al alcanzar el objetivo. ' +
            'Se recaudó un total de €${totalCollected.toStringAsFixed(2)}. - eventId:$eventId';
        } else {
          messageText =
            'El evento "${eventData['title']}" ha finalizado. ' +
            'Se recaudó un total de €${totalCollected.toStringAsFixed(2)}. - eventId:$eventId';
        }
      } else {
        messageText =
          'El evento "${eventData['title']}" ha finalizado. ' +
          'Se recaudó un total de €${totalCollected.toStringAsFixed(2)}. - eventId:$eventId';
      }

      await firestore
        .collection('groups')
        .doc(groupId)
        .collection('chats')
        .add({
          'senderId': currentUser.uid,
          'text': messageText,
          'type': MessageEnum.eventCompleted.name,
          'timeSent': FieldValue.serverTimestamp(),
          'messageId': const Uuid().v1(),
          'isSeen': false,
          'repliedMessage': '',
          'repliedTo': '',
          'repliedMessageType': '',
          'eventId': eventId,
        });

      if (context != null) {
        showSnackBar(
          context: context,
          content: 'Evento finalizado con éxito.',
          backgroundColor: Colors.green,
        );
      }
      
      print('Evento finalizado con éxito: $eventId');
      return true;
    } catch (e) {
      print('Error finalizando evento: $e');
      if (context != null) {
        showSnackBar(
          context: context, 
          content: 'Error: $e',
          backgroundColor: errorColor,
        );
      }
      return false;
    }
  }

  // Verificar y crear wallet si es necesario
  Future<Map<String, dynamic>> checkAndCreateWallet({
    required BuildContext context,
    required String userId,
    double initialBalance = 0.0,
  }) async {
    try {
      // Verificar si el usuario existe
      final userDoc = await firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        showSnackBar(
          context: context, 
          content: 'Usuario no encontrado',
          backgroundColor: errorColor,
        );
        return {'success': false, 'error': 'Usuario no encontrado'};
      }
      
      final userData = userDoc.data() as Map<String, dynamic>?;
      final userName = userData?['name'] ?? 'Usuario';
      
      // Verificar si la wallet existe
      final walletDoc = await firestore.collection('wallets').doc(userId).get();
      
      if (!walletDoc.exists) {
        // Wallet no existe, crear una nueva
        await firestore.collection('wallets').doc(userId).set({
          'userId': userId,
          'balance': initialBalance,
          'kycCompleted': false,
          'kycStatus': 'pending',
          'accountStatus': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        showSnackBar(
          context: context, 
          content: 'Wallet creada exitosamente para $userName',
          backgroundColor: Colors.green,
        );
        return {
          'success': true, 
          'message': 'Wallet creada exitosamente', 
          'walletExists': true
        };
      } else {
        // Wallet ya existe
        return {
          'success': true, 
          'message': 'La wallet ya existe', 
          'walletExists': true
        };
      }
    } catch (e) {
      print('Error en checkAndCreateWallet: $e');
      showSnackBar(
        context: context, 
        content: 'Error: $e',
        backgroundColor: errorColor,
      );
      return {'success': false, 'error': e.toString()};
    }
  }

  // Verificar todas las wallets relacionadas con un evento
  Future<void> checkEventWallets({
    required BuildContext context,
    required String eventId,
  }) async {
    try {
      final eventDoc = await firestore.collection('fund_events').doc(eventId).get();
      if (!eventDoc.exists) {
        showSnackBar(
          context: context, 
          content: 'Evento no encontrado',
          backgroundColor: errorColor,
        );
        return;
      }
      
      final eventData = eventDoc.data() as Map<String, dynamic>;
      final recipientId = eventData['recipientId'] as String? ?? '';
      final creatorId = eventData['creatorId'] as String? ?? '';
      final List<dynamic> participants = eventData['participants'] ?? [];
      
      int walletsCreated = 0;
      int walletsExisted = 0;
      
      // Verificar wallet del creador
      final creatorWalletDoc = await firestore.collection('wallets').doc(creatorId).get();
      if (!creatorWalletDoc.exists) {
        await firestore.collection('wallets').doc(creatorId).set({
          'userId': creatorId,
          'balance': 0.0,
          'kycCompleted': false,
          'kycStatus': 'pending',
          'accountStatus': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
        walletsCreated++;
      } else {
        walletsExisted++;
      }
      
      // Verificar wallet del destinatario
      final recipientWalletDoc = await firestore.collection('wallets').doc(recipientId).get();
      if (!recipientWalletDoc.exists) {
        await firestore.collection('wallets').doc(recipientId).set({
          'userId': recipientId,
          'balance': 0.0,
          'kycCompleted': false,
          'kycStatus': 'pending',
          'accountStatus': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
        walletsCreated++;
      } else {
        walletsExisted++;
      }
      
      // Verificar wallets de los participantes
      for (final participant in participants) {
        if (participant is Map<String, dynamic>) {
          final userId = participant['userId'] as String? ?? '';
          if (userId.isNotEmpty) {
            final walletDoc = await firestore.collection('wallets').doc(userId).get();
            if (!walletDoc.exists) {
              await firestore.collection('wallets').doc(userId).set({
                'userId': userId,
                'balance': 0.0,
                'kycCompleted': false,
                'kycStatus': 'pending',
                'accountStatus': 'pending',
                'createdAt': FieldValue.serverTimestamp(),
              });
              walletsCreated++;
            } else {
              walletsExisted++;
            }
          }
        }
      }
      
      showSnackBar(
        context: context, 
        content: 'Verificación completada: $walletsExisted wallets existentes, $walletsCreated wallets creadas',
        backgroundColor: Colors.green,
      );
    } catch (e) {
      print('Error en checkEventWallets: $e');
      showSnackBar(
        context: context, 
        content: 'Error: $e',
        backgroundColor: errorColor,
      );
    }
  }

  // Verificar y cerrar eventos expirados o que alcanzaron su objetivo
  Future<void> checkAndCloseExpiredEvents(String groupId) async {
    try {
      final now = DateTime.now();
      final querySnapshot = await firestore
          .collection('fund_events')
          .where('groupId', isEqualTo: groupId)
          .where('status', isEqualTo: 'active')
          .get();
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final eventId = data['eventId'];
        final deadline = data['deadline']?.toDate();
        final double totalCollected = data['totalCollected'] ?? 0.0;
        final double targetAmount = data['amount'] ?? 0.0;
        
        // Cerrar si pasó la fecha límite o se alcanzó el objetivo
        if ((deadline != null && now.isAfter(deadline)) || 
            (totalCollected >= targetAmount)) {
          await finalizeEvent(
            context: null,
            eventId: eventId,
            automatic: true,
          );
        }
      }
    } catch (e) {
      print('Error checking expired events: $e');
    }
  }

  // Obtener eventos activos de un grupo
  Stream<List<Map<String, dynamic>>> getGroupActiveEvents(String groupId) {
    print('Buscando eventos activos para grupo: $groupId');
    
    return firestore
        .collection('fund_events')
        .where('groupId', isEqualTo: groupId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .asyncMap((snapshot) async {
          print('Snapshot recibido - docs: ${snapshot.docs.length}');
          
          final List<Map<String, dynamic>> events = [];
          
          for (final doc in snapshot.docs) {
            try {
              final data = doc.data();
              print('Procesando evento: ${data['title']} - ID: ${data['eventId']}');
              
              // Manejo correcto de Timestamp
              DateTime? createdAt;
              if (data['createdAt'] is Timestamp) {
                createdAt = (data['createdAt'] as Timestamp).toDate();
              } else if (data['createdAt'] == null) {
                createdAt = DateTime.now();
              }
              
              DateTime? deadline;
              if (data['deadline'] is Timestamp) {
                deadline = (data['deadline'] as Timestamp).toDate();
              } else if (data['deadline'] != null) {
                deadline = data['deadline'] as DateTime?;
              }
              
              // Crear una copia segura con todas las conversiones
              final Map<String, dynamic> processedEvent = {
                ...data,
                'createdAt': createdAt ?? DateTime.now(),
                'deadline': deadline,
                'amount': (data['amount'] is num) ? (data['amount'] as num).toDouble() : 0.0,
                'totalCollected': (data['totalCollected'] is num) ? (data['totalCollected'] as num).toDouble() : 0.0,
                'participants': data['participants'] ?? [],
              };
              
              events.add(processedEvent);
            } catch (e) {
              print('Error procesando evento: $e');
            }
          }
          
          // Ordenar por fecha de creación
          events.sort((a, b) {
            final aDate = a['createdAt'] as DateTime?;
            final bDate = b['createdAt'] as DateTime?;
            
            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;
            
            return bDate.compareTo(aDate); // Orden descendente
          });
          
          return events;
        });
  }

  // Obtener eventos completados de un grupo
  Stream<List<Map<String, dynamic>>> getGroupCompletedEvents(String groupId) {
    return firestore
        .collection('fund_events')
        .where('groupId', isEqualTo: groupId)
        .where('status', isEqualTo: 'completed')
        .orderBy('completedAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              ...data,
              'completedAt': data['completedAt']?.toDate() ?? DateTime.now(),
              'createdAt':   data['createdAt']?.toDate()   ?? DateTime.now(),
            };
          }).toList();
        });
  }

  // Obtener detalles de evento específico
  Stream<Map<String, dynamic>?> getEventDetails(String eventId) {
    return firestore
        .collection('fund_events')
        .doc(eventId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) return null;
          final data = snapshot.data()!;
          return {
            ...data,
            'createdAt': data['createdAt']?.toDate() ?? DateTime.now(),
            'completedAt': data['completedAt']?.toDate(),
            'deadline': data['deadline']?.toDate(),
          };
        });
  }
}

class RecordFundsTab extends ConsumerStatefulWidget {
  final String groupId;
  const RecordFundsTab({Key? key, required this.groupId}) : super(key: key);

  @override
  ConsumerState<RecordFundsTab> createState() => _RecordFundsTabState();
}

class _RecordFundsTabState extends ConsumerState<RecordFundsTab> with SingleTickerProviderStateMixin {
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _purposeCtrl = TextEditingController();
  
  late TabController _tabController;
  bool _isLoading = false;
  DateTime? _selectedDeadline;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Verificar eventos expirados al cargar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recordFundsControllerProvider).checkAndCloseExpiredEvents(widget.groupId);
      _debugCheckEvents();
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _purposeCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: accentColor,
              onPrimary: Colors.white,
              surface: containerColor,
              onSurface: textColor,
            ),
            dialogBackgroundColor: cardColor,
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.dark(
                primary: accentColor,
                onPrimary: Colors.white,
                surface: containerColor,
                onSurface: textColor,
              ),
              dialogBackgroundColor: cardColor,
            ),
            child: child!,
          );
        },
      );
      
      if (pickedTime != null) {
        setState(() {
          _selectedDeadline = DateTime(
            picked.year,
            picked.month,
            picked.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  // Método de depuración para verificar eventos
  void _debugCheckEvents() async {
    try {
      print('Depuración: Verificando eventos para grupo: ${widget.groupId}');
      
      // Consulta todos los eventos para este grupo
      final allEvents = await FirebaseFirestore.instance
          .collection('fund_events')
          .where('groupId', isEqualTo: widget.groupId)
          .get();
      
      print('Depuración: Total de eventos encontrados: ${allEvents.docs.length}');
      
      // Mostrar detalles de cada evento
      for (final doc in allEvents.docs) {
        final data = doc.data();
        print('Depuración: Evento ID: ${doc.id}');
        print('  - Título: ${data['title']}');
        print('  - Estado: ${data['status']}');
      }
    } catch (e) {
      print('Depuración: Error al verificar eventos: $e');
    }
  }

  // Método para crear un nuevo evento
  Future<void> _submitEvent() async {
    final title = _titleCtrl.text.trim();
    final total = double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0;
    final purpose = _purposeCtrl.text.trim();
    final recipientId = ref.read(selectedRecipientProvider);

    if (title.isEmpty || total <= 0 || purpose.isEmpty || recipientId == null) {
      showSnackBar(
        context: context, 
        content: 'Por favor completa todos los campos',
        backgroundColor: Colors.orange,
      );
      return;
    }

    if (_selectedDeadline == null) {
      showSnackBar(
        context: context, 
        content: 'Por favor selecciona una fecha límite',
        backgroundColor: Colors.orange,
      );
      return;
    }

    setState(() => _isLoading = true);

    final success = await ref.read(recordFundsControllerProvider).createFundEvent(
      context: context,
      groupId: widget.groupId,
      title: title,
      amount: total,
      purpose: purpose,
      recipientId: recipientId,
      deadline: _selectedDeadline,
    );

    if (success) {
      _titleCtrl.clear();
      _amountCtrl.clear();
      _purposeCtrl.clear();
      ref.read(selectedRecipientProvider.notifier).state = null;
      setState(() {
        _selectedDeadline = null;
      });
      
      // Cambiar automáticamente a la pestaña de eventos activos
      _tabController.animateTo(1);
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    // Suscribirse a eventos activos con el provider externo
    final activeEvents = ref.watch(activeEventsProvider(widget.groupId));

    // Suscribirse a eventos completados
    final completedEvents = ref.watch(
      StreamProvider((ref) => ref.read(recordFundsControllerProvider)
          .getGroupCompletedEvents(widget.groupId))
    );

    // Estado actual de la wallet
    final walletState = ref.watch(walletControllerProvider);

    return Scaffold(
      backgroundColor: Color(0xFF121212),
      body: Column(
        children: [
          Container(
            color: Color(0xFF1A1A1A),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Color(0xFF3E63A8),
              labelColor: Color(0xFF3E63A8),
              unselectedLabelColor: unselectedItemColor,
              tabs: const [
                Tab(text: 'Crear Evento'),
                Tab(text: 'Eventos Activos'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Crear nuevo evento
                Container(
                  color: Color(0xFF121212),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Mostrar estado de la wallet
                        walletState.when(
                          data: (wallet) {
                            if (wallet == null) {
                              return Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: errorColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: errorColor.withOpacity(0.5)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded, color: errorColor),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Text(
                                        'Necesitas crear una wallet para crear eventos',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            } else if (!wallet.kycCompleted) {
                              return Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.orange.withOpacity(0.5)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline, color: Colors.orange),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Text(
                                        'Tu wallet necesita KYC para funcionalidad completa',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              return Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: accentColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: accentColor.withOpacity(0.2)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.account_balance_wallet, color: accentColor),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Saldo disponible: €${wallet.balance.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                          },
                          loading: () => Container(
                            height: 60,
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(child: CircularProgressIndicator()),
                          ),
                          error: (_, __) => Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: errorColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: errorColor.withOpacity(0.5)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: errorColor),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Error al cargar información de wallet',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const Text(
                          'Crear evento de recaudación',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Título del evento
                        Container(
                          decoration: BoxDecoration(
                            color: Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: dividerColor),
                          ),
                          child: TextField(
                            controller: _titleCtrl,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Título del Evento',
                              labelStyle: TextStyle(color: Colors.grey),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Monto a recaudar
                        Container(
                          decoration: BoxDecoration(
                            color: Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: dividerColor),
                          ),
                          child: TextField(
                            controller: _amountCtrl,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Monto Total (€)',
                              labelStyle: const TextStyle(color: Colors.grey),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              prefixIcon: Icon(Icons.euro, color: accentColor),
                            ),
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Propósito del evento
                        Container(
                          decoration: BoxDecoration(
                            color: Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: dividerColor),
                          ),
                          child: TextField(
                            controller: _purposeCtrl,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Propósito',
                              labelStyle: TextStyle(color: Colors.grey),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                            maxLines: 3,
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Selector de fecha límite
                        InkWell(
                          onTap: () => _selectDate(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: dividerColor),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _selectedDeadline == null
                                      ? 'Selecciona fecha límite'
                                      : 'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(_selectedDeadline!)}',
                                  style: TextStyle(
                                    color: _selectedDeadline == null ? Colors.grey : Colors.white,
                                  ),
                                ),
                                Icon(
                                  Icons.calendar_today,
                                  color: accentColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Selector de destinatario
                        _buildRecipientSelector(),
                        
                        const SizedBox(height: 24),
                        
                        // Botón para crear evento
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _submitEvent,
                          icon: const Icon(Icons.attach_money),
                          label: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text('CREAR EVENTO'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF3E63A8),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            disabledBackgroundColor: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Tab 2: Eventos activos
                Container(
                  color: Color(0xFF121212),
                  child: activeEvents.when(
                    data: (events) => events.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(32),
                                  decoration: BoxDecoration(
                                    color: containerColor.withOpacity(0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.event_note,
                                    size: 64,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'No hay eventos activos',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Crea un nuevo evento para recaudar fondos',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[400],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: () => _tabController.animateTo(0),
                                  icon: const Icon(Icons.add),
                                  label: const Text('CREAR EVENTO'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xFF3E63A8),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: events.length,
                            itemBuilder: (context, index) => _buildEventCard(events[index], true),
                          ),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: errorColor),
                          const SizedBox(height: 16),
                          const Text(
                            'Error al cargar eventos',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Si hay eventos completados, mostrar una sección adicional
          completedEvents.when(
            data: (events) => events.isNotEmpty
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    color: Color(0xFF1A1A1A),
                    child: ExpansionTile(
                      collapsedIconColor: accentColor,
                      iconColor: accentColor,
                      collapsedTextColor: Colors.white,
                      textColor: accentColor,
                      title: const Text(
                        'Eventos Completados',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      children: [
                        SizedBox(
                          height: 200,
                          child: ListView.builder(
                            itemCount: events.length,
                            itemBuilder: (context, index) => _buildEventCard(events[index], false),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // Construir el selector de destinatarios
  Widget _buildRecipientSelector() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('groups').doc(widget.groupId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            height: 120,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final groupData = snapshot.data!.data() as Map<String, dynamic>?;
        if (groupData == null) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: errorColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: errorColor.withOpacity(0.5)),
            ),
            child: const Text(
              'Error al cargar miembros del grupo',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        final List<dynamic> membersUid = groupData['membersUid'] ?? [];
        final selectedRecipient = ref.watch(selectedRecipientProvider);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Seleccionar destinatario:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 110,
              decoration: BoxDecoration(
                color: Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: dividerColor),
              ),
              child: membersUid.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay miembros en este grupo',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      itemCount: membersUid.length,
                      itemBuilder: (context, index) {
                        final uid = membersUid[index];
                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
                          builder: (context, userSnapshot) {
                            if (!userSnapshot.hasData) {
                              return const SizedBox(
                                width: 80,
                                child: Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              );
                            }
                            
                            final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                            if (userData == null) return const SizedBox.shrink();
                            
                            final name = userData['name'] ?? 'Usuario';
                            final profilePic = userData['profilePic'] ?? '';
                            
                            return GestureDetector(
                              onTap: () async {
                                // Verificar si el usuario tiene una wallet antes de seleccionarlo
                                final walletExists = await FirebaseFirestore.instance
                                    .collection('wallets')
                                    .doc(uid)
                                    .get()
                                    .then((doc) => doc.exists);
                                
                                if (walletExists) {
                                  ref.read(selectedRecipientProvider.notifier).state = uid;
                                } else {
                                  // El usuario no tiene wallet, preguntar si queremos crear una
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      backgroundColor: cardColor,
                                      title: Text(
                                        'Wallet necesaria',
                                        style: TextStyle(color: textColor),
                                      ),
                                      content: Text(
                                        '$name no tiene una wallet. Si lo seleccionas como destinatario, se creará una wallet automáticamente.',
                                        style: TextStyle(color: textColor),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          style: TextButton.styleFrom(foregroundColor: Colors.grey),
                                          child: const Text('Cancelar'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            ref.read(selectedRecipientProvider.notifier).state = uid;
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: accentColor,
                                            foregroundColor: Colors.white,
                                          ),
                                          child: const Text('Continuar'),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              },
                              child: Container(
                                width: 80,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: selectedRecipient == uid
                                      ? accentColor.withOpacity(0.2)
                                      : null,
                                  border: Border.all(
                                    color: selectedRecipient == uid
                                        ? accentColor
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Stack(
                                      children: [
                                        CircleAvatar(
                                          radius: 25,
                                          backgroundImage: profilePic.isNotEmpty
                                              ? NetworkImage(profilePic)
                                              : null,
                                          backgroundColor: profilePic.isEmpty
                                              ? accentColor.withOpacity(0.7)
                                              : null,
                                          child: profilePic.isEmpty
                                              ? Text(
                                                  name[0].toUpperCase(),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                )
                                              : null,
                                        ),
                                        // Indicador de wallet
                                        Positioned(
                                          right: 0,
                                          bottom: 0,
                                          child: FutureBuilder<DocumentSnapshot>(
                                            future: FirebaseFirestore.instance
                                                .collection('wallets')
                                                .doc(uid)
                                                .get(),
                                            builder: (context, walletSnap) {
                                              final hasWallet = walletSnap.hasData && walletSnap.data!.exists;
                                              
                                              return Container(
                                                padding: const EdgeInsets.all(2),
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: hasWallet ? Colors.green : Colors.grey[800],
                                                ),
                                                child: Icon(
                                                  hasWallet ? Icons.check : Icons.add,
                                                  size: 12,
                                                  color: Colors.white,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      name,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                        fontWeight: selectedRecipient == uid
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  // Construir tarjeta de evento
  Widget _buildEventCard(Map<String, dynamic> event, bool isActive) {
    final title = event['title'] ?? 'Evento sin título';
    final amount = event['amount'] ?? 0.0;
    final purpose = event['purpose'] ?? 'Sin descripción';
    final createdAt = event['createdAt'] as DateTime? ?? DateTime.now();
    final deadline = event['deadline'] as DateTime?;
    final totalCollected = event['totalCollected'] ?? 0.0;
    final List<dynamic> participants = event['participants'] ?? [];
    final progress = amount > 0 ? (totalCollected / amount) : 0.0;
    final eventId = event['eventId'];
    final recipientId = event['recipientId'];

    return GestureDetector(
      onTap: () {
        // Navegar a la pantalla de detalles del evento
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EventDetailsScreen(eventId: eventId),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '€${totalCollected.toStringAsFixed(2)} / €${amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: Colors.grey[800],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress >= 1.0 ? Colors.green : accentColor,
                  ),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                purpose,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[300]),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('users').doc(recipientId).get(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Text(
                          'Cargando destinatario...',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        );
                      }
                      
                      final userData = snapshot.data!.data() as Map<String, dynamic>?;
                      final name = userData?['name'] ?? 'Usuario';
                      
                      return Row(
                        children: [
                          Icon(Icons.person, size: 14, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text(
                            name,
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  Row(
                    children: [
                      Icon(Icons.people, size: 14, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text(
                        '${participants.length}',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              if (deadline != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.timer,
                        size: 14,
                        color: DateTime.now().isAfter(deadline) ? errorColor : Colors.grey[400],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('dd/MM/yyyy HH:mm').format(deadline),
                        style: TextStyle(
                          color: DateTime.now().isAfter(deadline) ? errorColor : Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                
              const SizedBox(height: 16),
              
              if (isActive)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.attach_money, size: 16),
                        label: const Text('Contribuir'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _showContributeDialog(eventId),
                      ),
                    ),
                    const SizedBox(width: 12),
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('fund_events')
                          .doc(eventId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox.shrink();
                        
                        final data = snapshot.data!.data() as Map<String, dynamic>?;
                        if (data == null) return const SizedBox.shrink();
                        
                        final creatorId = data['creatorId'];
                        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                        
                        // Solo mostrar el botón de finalizar al creador del evento
                        if (creatorId == currentUserId) {
                          return TextButton.icon(
                            icon: const Icon(Icons.check_circle, size: 16),
                            label: const Text('Finalizar'),
                            style: TextButton.styleFrom(
                              foregroundColor: accentColor,
                            ),
                            onPressed: () => _showFinalizeDialog(eventId),
                          );
                        }
                        
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  decoration: BoxDecoration(
                    color: containerColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 14,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Completado: ${_formatDate(event['completedAt'] as DateTime? ?? DateTime.now())}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontStyle: FontStyle.italic,
                          fontSize: 12,
                        ),
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

  // Mostrar diálogo para contribuir a un evento
  void _showContributeDialog(String eventId) {
    final amountController = TextEditingController();
    final groupId = widget.groupId;
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Contribuir al Evento',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Ingresa el monto con el que deseas contribuir:',
                  style: TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: containerColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: dividerColor),
                  ),
                  child: TextField(
                    controller: amountController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Monto (€)',
                      labelStyle: TextStyle(color: Colors.grey[400]),
                      border: InputBorder.none,
                      prefixIcon: Icon(
                        Icons.euro,
                        color: accentColor,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    enabled: !isProcessing,
                  ),
                ),
                if (isProcessing) ...[
                  const SizedBox(height: 16),
                  const Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 8),
                        Text(
                          'Procesando contribución...',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: isProcessing ? null : () => Navigator.pop(dialogContext), 
                      child: Text(
                        'Cancelar',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: isProcessing ? null : () async {
                        final amount = double.tryParse(amountController.text.trim().replaceAll(',', '.')) ?? 0;
                        if (amount <= 0) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                              content: Text('Ingresa un monto válido'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }
                        
                        setState(() => isProcessing = true);
                        
                        // Obtener diagnóstico del evento
                        final diagnosis = await ref.read(recordFundsControllerProvider).diagnoseFundEvent(eventId);
                        print('Diagnóstico del evento antes de contribuir:');
                        print(diagnosis);
                        
                        // Verificar si el usuario tiene suficiente saldo
                        final walletState = ref.read(walletControllerProvider);
                        if (walletState is AsyncData<Wallet?>) {
                          final wallet = walletState.value;
                          if (wallet == null) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text('No tienes una wallet activa'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            setState(() => isProcessing = false);
                            return;
                          }
                          
                          if (wallet.balance < amount) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text('Saldo insuficiente'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            setState(() => isProcessing = false);
                            return;
                          }
                        }
                        
                        try {
                          final success = await ref.read(recordFundsControllerProvider).participateInEvent(
                            context: dialogContext,
                            groupId: groupId,
                            eventId: eventId,
                            contribution: amount,
                          );
                          
                          Navigator.pop(dialogContext);
                          
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Has contribuido €${amount.toStringAsFixed(2)} al evento'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('No se pudo completar la contribución'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } catch (e) {
                          print('Error al contribuir: $e');
                          setState(() => isProcessing = false);
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF3E63A8),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Contribuir'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Mostrar diálogo para finalizar un evento
  void _showFinalizeDialog(String eventId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1A1A1A),
        title: const Text(
          'Finalizar Evento',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          '¿Estás seguro de que deseas finalizar este evento? Esta acción marcará el evento como completado y no podrá deshacerse.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF3E63A8),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              
              // Mostrar indicador de carga
              setState(() => _isLoading = true);
              
              await ref.read(recordFundsControllerProvider).finalizeEvent(
                context: context,
                eventId: eventId,
              );
              
              setState(() => _isLoading = false);
            },
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
  }

  // Formatear fecha
  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }
}
