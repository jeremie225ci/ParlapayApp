import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mk_mesenger/common/models/wallet.dart';
import 'package:mk_mesenger/common/utils/logger.dart';

class WalletRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Obtener wallet por ID de usuario
  Future<Wallet?> getWallet(String userId) async {
    logInfo('WalletRepository', 'Obteniendo wallet para usuario: $userId');
    try {
      // Obtener documento de wallet
      final walletDoc = await _firestore.collection('wallets').doc(userId).get();
    
      if (!walletDoc.exists) {
        logInfo('WalletRepository', 'No existe wallet para el usuario: $userId');
        // Si no existe, crear una wallet vacía
        final newWallet = Wallet(userId: userId);
        await _firestore.collection('wallets').doc(userId).set({
          'userId': userId,
          ...newWallet.toMap(),
        });
        return newWallet;
      }
    
      // Obtener transacciones
      final transactionsSnapshot = await _firestore
          .collection('wallets')
          .doc(userId)
          .collection('transactions')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();
    
      final transactions = transactionsSnapshot.docs
          .map((doc) => WalletTransaction.fromMap(doc.data()))
          .toList();
    
      logInfo('WalletRepository', 'Transacciones obtenidas: ${transactions.length}');
    
      // Crear objeto Wallet con datos del documento y asegurar que userId esté establecido
      final walletData = {
        'userId': userId, // Asegurar que userId esté presente
        'documentId': userId, // Añadir el ID del documento como respaldo
        ...walletDoc.data() ?? {},
      };
      
      // Crear objeto Wallet
      return Wallet.fromMap(walletData, transactions);
    } catch (e) {
      logError('WalletRepository', 'Error al obtener wallet', e);
      return null;
    }
  }

  // Stream para observar cambios en la wallet
  Stream<Wallet?> watchWallet(String userId) {
    logInfo('WalletRepository', 'Observando wallet para usuario: $userId');
    
    // Stream de documento de wallet
    final walletStream = _firestore.collection('wallets').doc(userId).snapshots();
    
    // Combinar streams
    return walletStream.asyncMap((walletDoc) async {
      try {
        if (!walletDoc.exists) {
          logInfo('WalletRepository', 'No existe wallet para el usuario (stream): $userId');
          // Si no existe, crear una wallet vacía
          final newWallet = Wallet(userId: userId);
          await _firestore.collection('wallets').doc(userId).set({
            'userId': userId,
            ...newWallet.toMap(),
          });
          return newWallet;
        }
        
        // Obtener transacciones actuales
        final transactionsSnapshot = await _firestore
            .collection('wallets')
            .doc(userId)
            .collection('transactions')
            .orderBy('timestamp', descending: true)
            .limit(20)
            .get();
        
        final transactions = transactionsSnapshot.docs
            .map((doc) => WalletTransaction.fromMap(doc.data()))
            .toList();
        
        // Crear objeto Wallet con userId explícito
        final walletData = {
          'userId': userId, // Asegurar que userId esté presente
          'documentId': userId, // Añadir el ID del documento como respaldo
          ...walletDoc.data() ?? {},
        };
        
        // Crear objeto Wallet
        return Wallet.fromMap(walletData, transactions);
      } catch (e) {
        logError('WalletRepository', 'Error en stream de wallet', e);
        return null;
      }
    });
  }

  // Actualizar wallet
  Future<void> updateWallet(String userId, Map<String, dynamic> data) async {
    logInfo('WalletRepository', 'Actualizando wallet para usuario: $userId');
    logInfo('WalletRepository', 'Datos a actualizar: $data');
    
    try {
      // Asegurar que userId esté en los datos
      if (!data.containsKey('userId')) {
        data['userId'] = userId;
      }
      
      await _firestore.collection('wallets').doc(userId).update(data);
      logInfo('WalletRepository', 'Wallet actualizada correctamente');
    } catch (e) {
      logError('WalletRepository', 'Error al actualizar wallet', e);
      
      // Si el documento no existe, crearlo
      if (e is FirebaseException && e.code == 'not-found') {
        logInfo('WalletRepository', 'Documento no encontrado, creando nuevo...');
        
        final newData = {
          'userId': userId,
          'balance': 0.0,
          'kycCompleted': false,
          'kycStatus': 'pending',
          'accountStatus': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          ...data,
        };
        
        await _firestore.collection('wallets').doc(userId).set(newData);
        logInfo('WalletRepository', 'Nuevo documento de wallet creado');
      } else {
        // Relanzar el error para que sea manejado por el llamador
        rethrow;
      }
    }
  }

  // Añadir transacción
  Future<void> addTransaction(String userId, Map<String, dynamic> transaction) async {
    logInfo('WalletRepository', 'Añadiendo transacción para usuario: $userId');
    logInfo('WalletRepository', 'Datos de transacción: $transaction');
    
    try {
      // Asegurar que el ID de transacción existe
      final transactionId = transaction['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
      transaction['id'] = transactionId;
      
      // Añadir timestamp si no existe
      if (!transaction.containsKey('timestamp')) {
        transaction['timestamp'] = FieldValue.serverTimestamp();
      }
      
      // Guardar transacción
      await _firestore
          .collection('wallets')
          .doc(userId)
          .collection('transactions')
          .doc(transactionId)
          .set(transaction);
      
      logInfo('WalletRepository', 'Transacción añadida correctamente');
    } catch (e) {
      logError('WalletRepository', 'Error al añadir transacción', e);
      rethrow;
    }
  }

  // NUEVO MÉTODO: Añadir transacción solo si no existe ya (evitar duplicados)
  Future<void> addTransactionIfNotExists(String userId, Map<String, dynamic> transaction) async {
    logInfo('WalletRepository', 'Añadiendo transacción para usuario: $userId (con verificación de duplicados)');
    logInfo('WalletRepository', 'Datos de transacción: $transaction');
    
    try {
      // Asegurar que el ID de transacción existe
      final transactionId = transaction['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
      transaction['id'] = transactionId;
      
      // Añadir timestamp si no existe
      if (!transaction.containsKey('timestamp')) {
        transaction['timestamp'] = FieldValue.serverTimestamp();
      }
      
      // 1. Verificar si la transacción ya existe para evitar duplicados
      final existingTransaction = await _firestore
          .collection('wallets')
          .doc(userId)
          .collection('transactions')
          .doc(transactionId)
          .get();
      
      if (existingTransaction.exists) {
        logInfo('WalletRepository', 'Transacción $transactionId ya existe, evitando duplicado');
        return; // La transacción ya existe, no hacer nada
      }
      
      // 2. También verificar por otras propiedades para evitar transacciones similares
      if (transaction.containsKey('rapydPaymentId') && transaction['rapydPaymentId'] != null) {
        final similarTransactions = await _firestore
            .collection('wallets')
            .doc(userId)
            .collection('transactions')
            .where('rapydPaymentId', isEqualTo: transaction['rapydPaymentId'])
            .get();
        
        if (similarTransactions.docs.isNotEmpty) {
          logInfo('WalletRepository', 'Transacción con mismo rapydPaymentId ya existe, evitando duplicado');
          return; // Ya existe una transacción con el mismo rapydPaymentId
        }
      }
      
      // 3. Verificar por combinación de monto, tipo y timestamp cercano
      if (transaction.containsKey('amount') && 
          transaction.containsKey('type') && 
          transaction.containsKey('description')) {
        
        // Buscar transacciones similares en los últimos 10 minutos
        final limitTime = DateTime.now().subtract(const Duration(minutes: 10));
        
        final similarTransactions = await _firestore
            .collection('wallets')
            .doc(userId)
            .collection('transactions')
            .where('amount', isEqualTo: transaction['amount'])
            .where('description', isEqualTo: transaction['description'])
            .get();
        
        for (var doc in similarTransactions.docs) {
          // Si hay transacciones similares recientes con el mismo monto y descripción,
          // consideramos que es un duplicado
          logInfo('WalletRepository', 'Transacción similar encontrada, evitando duplicado');
          return;
        }
      }
      
      // 4. Si pasó todas las verificaciones, guardar la transacción
      await _firestore
          .collection('wallets')
          .doc(userId)
          .collection('transactions')
          .doc(transactionId)
          .set(transaction);
      
      logInfo('WalletRepository', 'Transacción añadida correctamente sin duplicados');
    } catch (e) {
      logError('WalletRepository', 'Error al añadir transacción', e);
      rethrow;
    }
  }

  // Obtener transacciones
  Future<List<WalletTransaction>> getTransactions(String userId, {int limit = 20}) async {
    logInfo('WalletRepository', 'Obteniendo transacciones para usuario: $userId (límite: $limit)');
    
    try {
      final snapshot = await _firestore
          .collection('wallets')
          .doc(userId)
          .collection('transactions')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      
      final transactions = snapshot.docs
          .map((doc) => WalletTransaction.fromMap(doc.data()))
          .toList();
      
      logInfo('WalletRepository', 'Transacciones obtenidas: ${transactions.length}');
      return transactions;
    } catch (e) {
      logError('WalletRepository', 'Error al obtener transacciones', e);
      return [];
    }
  }

  // Crear wallet si no existe
  Future<Wallet> createWalletIfNotExists(String userId) async {
    logInfo('WalletRepository', 'Creando wallet si no existe para usuario: $userId');
    
    try {
      final walletDoc = await _firestore.collection('wallets').doc(userId).get();
      
      if (walletDoc.exists) {
        logInfo('WalletRepository', 'La wallet ya existe para el usuario: $userId');
        
        // Obtener transacciones
        final transactionsSnapshot = await _firestore
            .collection('wallets')
            .doc(userId)
            .collection('transactions')
            .orderBy('timestamp', descending: true)
            .limit(20)
            .get();
        
        final transactions = transactionsSnapshot.docs
            .map((doc) => WalletTransaction.fromMap(doc.data()))
            .toList();
        
        // Asegurar que userId esté presente
        final walletData = {
          'userId': userId,
          'documentId': userId,
          ...walletDoc.data() ?? {},
        };
        
        return Wallet.fromMap(walletData, transactions);
      }
      
      // Crear nueva wallet
      final newWallet = Wallet(
        userId: userId,
        balance: 0.0,
        kycCompleted: false,
        kycStatus: 'pending',
        accountStatus: 'pending',
      );
      
      await _firestore.collection('wallets').doc(userId).set({
        'userId': userId,
        ...newWallet.toMap(),
      });
      logInfo('WalletRepository', 'Nueva wallet creada para el usuario: $userId');
      
      return newWallet;
    } catch (e) {
      logError('WalletRepository', 'Error al crear wallet', e);
      
      // En caso de error, devolver una wallet básica
      return Wallet(userId: userId);
    }
  }

  // Sincronizar wallets pendientes con Rapyd
  Future<List<Wallet>> getPendingSyncWallets() async {
    logInfo('WalletRepository', 'Obteniendo wallets pendientes de sincronización');
    
    try {
      final snapshot = await _firestore
          .collection('wallets')
          .where('pendingSyncWithRapyd', isEqualTo: true)
          .limit(10)
          .get();
      
      final wallets = await Future.wait(
        snapshot.docs.map((doc) async {
          final userId = doc.id;
          
          // Obtener transacciones
          final transactionsSnapshot = await _firestore
              .collection('wallets')
              .doc(userId)
              .collection('transactions')
              .orderBy('timestamp', descending: true)
              .limit(20)
              .get();
          
          final transactions = transactionsSnapshot.docs
              .map((doc) => WalletTransaction.fromMap(doc.data()))
              .toList();
          
          // Asegurar que userId esté presente
          final walletData = {
            'userId': userId,
            'documentId': userId,
            ...doc.data(),
          };
          
          return Wallet.fromMap(walletData, transactions);
        }),
      );
      
      logInfo('WalletRepository', 'Wallets pendientes obtenidas: ${wallets.length}');
      return wallets;
    } catch (e) {
      logError('WalletRepository', 'Error al obtener wallets pendientes', e);
      return [];
    }
  }

  // Marcar wallet como sincronizada
  Future<void> markWalletSynced(String userId) async {
    logInfo('WalletRepository', 'Marcando wallet como sincronizada: $userId');
    
    try {
      await _firestore.collection('wallets').doc(userId).update({
        'pendingSyncWithRapyd': false,
        'lastSyncedAt': FieldValue.serverTimestamp(),
      });
      
      logInfo('WalletRepository', 'Wallet marcada como sincronizada');
    } catch (e) {
      logError('WalletRepository', 'Error al marcar wallet como sincronizada', e);
      rethrow;
    }
  }
  // Corrección para el error de timestamp en getPaymentsHistory

// Método para obtener pagos desde la colección "payments"
// Método para obtener pagos y transferencias
// Método para obtener pagos y transferencias sin duplicados
// Método para obtener pagos y transferencias sin duplicados
// Método para obtener pagos y transferencias sin duplicados
Future<List<WalletTransaction>> getPaymentsHistory(String userId, {int limit = 100}) async {
    logInfo('WalletRepository', 'Obteniendo historial de transacciones para usuario: $userId');
    
    try {
      // Mapa para almacenar transacciones únicas por timestamp redondeado y monto
      final Map<String, WalletTransaction> uniqueTransactions = {};
      
      // 1. Obtener todas las transacciones de la subcollection "transactions" del usuario
      final transactionsSnapshot = await _firestore
          .collection('wallets')
          .doc(userId)
          .collection('transactions')
          .orderBy('timestamp', descending: true)
          .get();
      
      logInfo('WalletRepository', 'Transacciones encontradas: ${transactionsSnapshot.docs.length}');
      
      // 2. Obtener transacciones de la colección principal "transactions"
      final mainTransactionsSnapshot = await _firestore
          .collection('transactions')
          .where('senderId', isEqualTo: userId)
          .get();
      
      final receivedTransactionsSnapshot = await _firestore
          .collection('transactions')
          .where('receiverId', isEqualTo: userId)
          .get();
      
      // 3. Obtener transacciones de la colección "payments" (depósitos)
      final paymentsSnapshot = await _firestore
          .collection('payments')
          .where('userId', isEqualTo: userId)
          .get();
      
      // Combinar todas las transacciones en una sola lista
      final allDocs = [
        ...transactionsSnapshot.docs,
        ...mainTransactionsSnapshot.docs,
        ...receivedTransactionsSnapshot.docs,
        ...paymentsSnapshot.docs,
      ];
      
      // Procesar cada documento
      for (var doc in allDocs) {
        final data = doc.data();
        
        // Extraer información clave
        final String senderId = data['senderId']?.toString() ?? '';
        final String receiverId = data['receiverId']?.toString() ?? '';
        
        // Determinar si es una transacción relevante para este usuario
        final bool isSender = senderId == userId;
        final bool isReceiver = receiverId == userId;
        
        // Si no es ni remitente ni destinatario, saltar
        if (!isSender && !isReceiver) {
          continue;
        }
        
        // Determinar si es un depósito
        final bool isDeposit = senderId == 'payment_system' || 
                              senderId == 'deposit' || 
                              data['type']?.toString() == 'deposit';
        
        // Obtener el monto
        double amount = 0.0;
        if (data['amount'] is num) {
          amount = (data['amount'] as num).toDouble();
        } else if (data['amount'] is String) {
          amount = double.tryParse(data['amount'].toString()) ?? 0.0;
        }
        
        // Determinar el tipo y ajustar el monto
        String type;
        String description;
        
        if (isDeposit) {
          type = 'deposit';
          description = 'Depósito';
          // Asegurar que el monto sea positivo
          amount = amount.abs();
        } else if (isSender && (!isReceiver || senderId != receiverId)) {
          type = 'sent';
          description = 'Transferencia enviada';
          // Asegurar que el monto sea negativo
          amount = -amount.abs();
        } else if (isReceiver && !isSender) {
          type = 'received';
          description = 'Transferencia recibida';
          // Asegurar que el monto sea positivo
          amount = amount.abs();
        } else {
          // Transacción no relevante o interna
          continue;
        }
        
        // Convertir timestamp a DateTime
        DateTime timestamp = DateTime.now();
        if (data['timestamp'] is Timestamp) {
          timestamp = (data['timestamp'] as Timestamp).toDate();
        } else if (data['timestamp'] is String) {
          timestamp = DateTime.parse(data['timestamp']);
        } else if (data['createdAt'] is Timestamp) {
          timestamp = (data['createdAt'] as Timestamp).toDate();
        }
        
        // Redondear el timestamp al minuto para agrupar transacciones similares
        final int roundedTimestamp = (timestamp.millisecondsSinceEpoch / 60000).round() * 60000;
        
        // Crear una clave única basada en el tipo, timestamp redondeado y monto
        final String key = '$type-$roundedTimestamp-${amount.abs().toStringAsFixed(2)}';
        
        // Si ya existe una transacción con esta clave, verificar cuál mantener
        if (uniqueTransactions.containsKey(key)) {
          // Si la transacción existente tiene un ID más corto o más legible, mantenerla
          final existingTransaction = uniqueTransactions[key]!;
          if (existingTransaction.id.length <= doc.id.length) {
            continue;
          }
        }
        
        // Crear la transacción
        uniqueTransactions[key] = WalletTransaction(
          id: doc.id,
          amount: amount,
          senderId: senderId,
          receiverId: receiverId,
          timestamp: timestamp,
          description: description,
          paymentId: data['paymentId']?.toString() ?? '',
          status: data['status']?.toString() ?? 'completed',
          type: type,
        );
      }
      
      // Convertir el mapa a una lista y ordenar por fecha
      final List<WalletTransaction> result = uniqueTransactions.values.toList();
      result.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      // Limitar el número de transacciones si es necesario
      if (result.length > limit) {
        return result.sublist(0, limit);
      }
      
      logInfo('WalletRepository', 'Total de transacciones únicas: ${result.length}');
      return result;
    } catch (e, stack) {
      logError('WalletRepository', 'Error al obtener historial de transacciones', e, stack);
      return [];
    }
  }


// Método auxiliar mejorado para descripciones de pagos
String _getPaymentDescription(Map<String, dynamic> paymentData) {
  String type = '';
  
  // Intentar determinar el tipo de transacción
  if (paymentData.containsKey('type')) {
    type = paymentData['type'].toString();
  } else if (paymentData.containsKey('operation')) {
    type = paymentData['operation'].toString();
  } else if (paymentData.containsKey('description')) {
    return paymentData['description'].toString();
  } else if (paymentData.containsKey('checkoutUrl') || paymentData.containsKey('rapydCheckoutId')) {
    type = 'deposit';
  }
  
  String status = '';
  if (paymentData.containsKey('status')) {
    status = paymentData['status'].toString();
  }
  
  String amount = '';
  if (paymentData.containsKey('amount')) {
    amount = paymentData['amount'].toString();
  }
  
  String currency = 'EUR';
  if (paymentData.containsKey('currency')) {
    currency = paymentData['currency'].toString();
  }
  
  // Generar descripción basada en el tipo y monto
  if (type == 'deposit' || type == 'credit') {
    if (status == 'completed' || status == 'success') {
      return 'Depósito de $amount $currency completado';
    } else if (status == 'pending') {
      return 'Depósito de $amount $currency pendiente';
    } else if (status == 'failed') {
      return 'Depósito de $amount $currency fallido';
    }
    return 'Depósito de $amount $currency';
  } else if (type == 'withdrawal' || type == 'debit') {
    return 'Retiro de $amount $currency';
  } else if (type == 'transfer') {
    return 'Transferencia de $amount $currency';
  }
  
  // Si no podemos determinar un tipo específico
  if (amount.isNotEmpty) {
    return 'Transacción de $amount $currency';
  }
  
  return 'Transacción';
}
}