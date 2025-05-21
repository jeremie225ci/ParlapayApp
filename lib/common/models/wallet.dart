import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WalletTransaction {
  final String id;
  final double amount;
  final String senderId;
  final String receiverId;
  final DateTime timestamp;
  final String? description;
  final String? status;
  final String? paymentId; // Nuevo campo para almacenar el ID de pago de Rapyd
  final String type; // Añadido el campo type

  WalletTransaction({
    required this.id,
    required this.amount,
    required this.senderId,
    required this.receiverId,
    required this.timestamp,
    this.description,
    this.status = 'completed',
    this.paymentId, // Añadir este campo opcional
    this.type = 'transaction', // Valor por defecto
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'senderId': senderId,
      'receiverId': receiverId,
      'timestamp': timestamp,
      'description': description,
      'status': status,
      'paymentId': paymentId, // Incluir el campo en el mapa
      'type': type, // Incluir el campo type en el mapa
    };
  }

  factory WalletTransaction.fromMap(Map<String, dynamic> map) {
    debugPrint('🔄 Creando WalletTransaction desde mapa: $map');
    
    // Manejar diferentes formatos de timestamp
    DateTime parseTimestamp(dynamic timestamp) {
      if (timestamp is Timestamp) {
        return timestamp.toDate();
      } else if (timestamp is DateTime) {
        return timestamp;
      } else if (timestamp is String) {
        try {
          return DateTime.parse(timestamp);
        } catch (e) {
          debugPrint('⚠️ Error al parsear timestamp string: $e');
          return DateTime.now();
        }
      } else if (timestamp is int) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else {
        debugPrint('⚠️ Formato de timestamp desconocido: $timestamp (${timestamp.runtimeType})');
        return DateTime.now();
      }
    }
    
    try {
      return WalletTransaction(
        id: map['id'] ?? '',
        amount: (map['amount'] is int) 
            ? (map['amount'] as int).toDouble() 
            : (map['amount'] ?? 0.0),
        senderId: map['senderId'] ?? '',
        receiverId: map['receiverId'] ?? '',
        timestamp: map['timestamp'] != null 
            ? parseTimestamp(map['timestamp']) 
            : DateTime.now(),
        description: map['description'],
        status: map['status'] ?? 'completed',
        paymentId: map['paymentId'], // Leer el campo desde el mapa
        type: map['type'] ?? 'transaction', // Leer el campo type desde el mapa
      );
    } catch (e) {
      debugPrint('❌ Error al crear WalletTransaction: $e');
      // Devolver una transacción por defecto en caso de error
      return WalletTransaction(
        id: 'error-${DateTime.now().millisecondsSinceEpoch}',
        amount: 0.0,
        senderId: 'error',
        receiverId: 'error',
        timestamp: DateTime.now(),
        description: 'Error al cargar transacción: $e',
        status: 'error',
        paymentId: null,
        type: 'error', // Añadir type en caso de error
      );
    }
  }
  
  // Método para crear una copia con algunas propiedades modificadas
  WalletTransaction copyWith({
    String? id,
    double? amount,
    String? senderId,
    String? receiverId,
    DateTime? timestamp,
    String? description,
    String? status,
    String? paymentId, // Incluir en copyWith
    String? type, // Incluir type en copyWith
  }) {
    return WalletTransaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      timestamp: timestamp ?? this.timestamp,
      description: description ?? this.description,
      status: status ?? this.status,
      paymentId: paymentId ?? this.paymentId, // Usar en copyWith
      type: type ?? this.type, // Usar type en copyWith
    );
  }
}

class Wallet {
  final String userId;
  final double balance;
  final String? walletId; // ID de Rapyd
  final bool kycCompleted;
  final String? kycStatus; // 'pending', 'initiated', 'processing', 'approved', 'rejected'
  final DateTime? kycInitiatedAt;
  final DateTime? kycApprovedAt;
  final String? accountStatus; // 'pending', 'active', 'suspended'
  final List<WalletTransaction> transactions;
  
  // Datos personales
  final String? firstName;
  final String? lastName;
  final String? email;
  final DateTime? birthDate;
  final String? address;
  final String? city;
  final String? postalCode;
  final String? country;
  
  // Datos bancarios
  final String? iban;
  final String? bankAccountNumber;
  final String? routingNumber;
  
  // Flags de sincronización
  final bool pendingSyncWithRapyd;

  Wallet({
    required this.userId,
    this.balance = 0.0,
    this.walletId,
    this.kycCompleted = false,
    this.kycStatus = 'pending',
    this.kycInitiatedAt,
    this.kycApprovedAt,
    this.accountStatus = 'pending',
    this.transactions = const [],
    this.firstName,
    this.lastName,
    this.email,
    this.birthDate,
    this.address,
    this.city,
    this.postalCode,
    this.country,
    this.iban,
    this.bankAccountNumber,
    this.routingNumber,
    this.pendingSyncWithRapyd = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'balance': balance,
      'walletId': walletId,
      'kycCompleted': kycCompleted,
      'kycStatus': kycStatus,
      'kycInitiatedAt': kycInitiatedAt,
      'kycApprovedAt': kycApprovedAt,
      'accountStatus': accountStatus,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'birthDate': birthDate,
      'address': address,
      'city': city,
      'postalCode': postalCode,
      'country': country,
      'iban': iban,
      'bankAccountNumber': bankAccountNumber,
      'routingNumber': routingNumber,
      'pendingSyncWithRapyd': pendingSyncWithRapyd,
    };
  }

  factory Wallet.fromMap(Map<String, dynamic> map, List<WalletTransaction> transactions) {
    debugPrint('🔄 Creando Wallet desde mapa: $map');
    
    // Manejar diferentes formatos de timestamp
    DateTime? parseTimestamp(dynamic timestamp) {
      if (timestamp == null) return null;
      
      if (timestamp is Timestamp) {
        return timestamp.toDate();
      } else if (timestamp is DateTime) {
        return timestamp;
      } else if (timestamp is String) {
        try {
          // Intentar parsear como ISO 8601
          return DateTime.parse(timestamp);
        } catch (e) {
          // Intentar parsear como formato dd/MM/yyyy
          try {
            final parts = timestamp.split('/');
            if (parts.length == 3) {
              final day = int.parse(parts[0]);
              final month = int.parse(parts[1]);
              final year = int.parse(parts[2]);
              return DateTime(year, month, day);
            }
          } catch (e2) {
            debugPrint('⚠️ Error al parsear timestamp en formato dd/MM/yyyy: $e2');
          }
          
          debugPrint('⚠️ Error al parsear timestamp string: $e');
          return null;
        }
      } else if (timestamp is int) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else {
        debugPrint('⚠️ Formato de timestamp desconocido: $timestamp (${timestamp.runtimeType})');
        return null;
      }
    }
    
    try {
      // Obtener el userId del mapa, o usar el ID del documento si está disponible
      String userIdValue = '';
      if (map.containsKey('userId') && map['userId'] != null && map['userId'].toString().isNotEmpty) {
        userIdValue = map['userId'].toString();
      } else if (map.containsKey('id') && map['id'] != null && map['id'].toString().isNotEmpty) {
        userIdValue = map['id'].toString();
      } else if (map.containsKey('documentId') && map['documentId'] != null) {
        userIdValue = map['documentId'].toString();
      }
      
      debugPrint('📝 UserId obtenido: $userIdValue');
      
      return Wallet(
        userId: userIdValue,
        balance: (map['balance'] is int) 
            ? (map['balance'] as int).toDouble() 
            : (map['balance'] ?? 0.0),
        walletId: map['walletId'],
        kycCompleted: map['kycCompleted'] ?? false,
        kycStatus: map['kycStatus'] ?? 'pending',
        kycInitiatedAt: parseTimestamp(map['kycInitiatedAt']),
        kycApprovedAt: parseTimestamp(map['kycApprovedAt']),
        accountStatus: map['accountStatus'] ?? 'pending',
        transactions: transactions,
        firstName: map['firstName'],
        lastName: map['lastName'],
        email: map['email'],
        birthDate: parseTimestamp(map['birthDate']),
        address: map['address'],
        city: map['city'],
        postalCode: map['postalCode'],
        country: map['country'],
        iban: map['iban'],
        bankAccountNumber: map['bankAccountNumber'],
        routingNumber: map['routingNumber'],
        pendingSyncWithRapyd: map['pendingSyncWithRapyd'] ?? false,
      );
    } catch (e) {
      debugPrint('❌ Error al crear Wallet: $e');
      // Devolver una wallet por defecto en caso de error
      return Wallet(
        userId: map['userId'] ?? '',
        balance: 0.0,
        kycStatus: 'error',
        transactions: transactions,
      );
    }
  }

  Wallet copyWith({
    String? userId,
    double? balance,
    String? walletId,
    bool? kycCompleted,
    String? kycStatus,
    DateTime? kycInitiatedAt,
    DateTime? kycApprovedAt,
    String? accountStatus,
    List<WalletTransaction>? transactions,
    String? firstName,
    String? lastName,
    String? email,
    DateTime? birthDate,
    String? address,
    String? city,
    String? postalCode,
    String? country,
    String? iban,
    String? bankAccountNumber,
    String? routingNumber,
    bool? pendingSyncWithRapyd,
  }) {
    return Wallet(
      userId: userId ?? this.userId,
      balance: balance ?? this.balance,
      walletId: walletId ?? this.walletId,
      kycCompleted: kycCompleted ?? this.kycCompleted,
      kycStatus: kycStatus ?? this.kycStatus,
      kycInitiatedAt: kycInitiatedAt ?? this.kycInitiatedAt,
      kycApprovedAt: kycApprovedAt ?? this.kycApprovedAt,
      accountStatus: accountStatus ?? this.accountStatus,
      transactions: transactions ?? this.transactions,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      birthDate: birthDate ?? this.birthDate,
      address: address ?? this.address,
      city: city ?? this.city,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      iban: iban ?? this.iban,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      routingNumber: routingNumber ?? this.routingNumber,
      pendingSyncWithRapyd: pendingSyncWithRapyd ?? this.pendingSyncWithRapyd,
    );
  }
}
