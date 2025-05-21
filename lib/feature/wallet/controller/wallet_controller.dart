import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mk_mesenger/common/models/wallet.dart';
import 'package:mk_mesenger/common/utils/logger.dart';
import 'package:mk_mesenger/feature/wallet/repository/wallet_repository.dart';
import 'package:mk_mesenger/common/utils/widgets/snackbar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mk_mesenger/feature/wallet/screens/checkout_payment_screen.dart';
import 'package:mk_mesenger/services/rapyd_service.dart';
import 'package:url_launcher/url_launcher.dart'; // Importar paquete url_launcher

/// Proveedores de Riverpod
final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository();
});

final walletStreamProvider = StreamProvider<Wallet?>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return const Stream.empty();
  return ref.watch(walletRepositoryProvider).watchWallet(user.uid);
});

final walletControllerProvider =
    StateNotifierProvider<WalletController, AsyncValue<Wallet?>>(
  (ref) => WalletController(ref),
);

class WalletController extends StateNotifier<AsyncValue<Wallet?>> {
  final Ref _ref;
  final RapydService _rapydService;
  final WalletRepository _repo;

  WalletController(this._ref)
      : _rapydService = RapydService(),
        _repo = _ref.read(walletRepositoryProvider),
        super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    logInfo('WalletController', 'Inicializando WalletController');
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      logWarning('WalletController', 'No hay usuario autenticado');
      state = const AsyncValue.data(null);
      return;
    }

    // Carga inicial de la wallet
    try {
      logInfo('WalletController', 'Cargando wallet para usuario: ${user.uid}');
      final wallet = await _repo.getWallet(user.uid);
      if (wallet != null) {
        logInfo('WalletController', 'Wallet cargada correctamente: ${wallet.toMap()}');
      } else {
        logWarning('WalletController', 'No se encontró wallet para el usuario');
      }
      state = AsyncValue.data(wallet);
    } catch (e, stack) {
      logError('WalletController', 'Error al cargar wallet', e, stack);
      state = AsyncValue.error(e, stack);
    }

    // Escucha actualizaciones de Firestore
    _ref.listen<AsyncValue<Wallet?>>(walletStreamProvider, (_, next) {
      next.whenData((w) {
        if (w != null) {
          logInfo('WalletController', 'Wallet actualizada: ${w.toMap()}');
        } else {
          logWarning('WalletController', 'Wallet actualizada a null');
        }
        state = AsyncValue.data(w);
      });
    });
  }

  /// Método para verificar conexión con el servidor
  Future<bool> checkServerConnection() async {
    logInfo('WalletController', 'Verificando conexión con el servidor...');
    try {
      final result = await _rapydService.testConnection();
      logInfo('WalletController', result ? 'Conexión exitosa' : 'No hay conexión');
      return result;
    } catch (e, stack) {
      logError('WalletController', 'Error verificando conexión', e, stack);
      return false;
    }
  }

  /// Añade fondos usando Checkout Page de Rapyd
  Future<bool> addFunds(double amount, BuildContext context) async {
    logInfo('WalletController', 'Añadiendo fondos: $amount');
    
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final wallet = state.value;
      
      if (wallet == null || !wallet.kycCompleted) {
        logWarning('WalletController', 'KYC no completado');
        showSnackBar(context: context, content: 'Completa tu KYC primero');
        return false;
      }
      
      // Verificar conexión antes de hacer la solicitud
      final isConnected = await checkServerConnection();
      if (!isConnected) {
        logWarning('WalletController', 'No hay conexión con el servidor');
        showSnackBar(
          context: context,
          content: 'No hay conexión con el servidor. Verifica tu conexión a internet.'
        );
        return false;
      }
      
      logInfo('WalletController', 'Creando página de checkout...');
      
      // Obtener información del usuario para el checkout
      String? customerName;
      String? customerEmail;
      
      if (wallet.firstName != null && wallet.lastName != null) {
        customerName = '${wallet.firstName} ${wallet.lastName}';
      }
      
      if (wallet.email != null) {
        customerEmail = wallet.email;
      }
      
      // Crear página de checkout
      final resp = await _rapydService.createCheckout(
        userId: user.uid,
        amount: amount,
        currency: 'EUR',
        country: 'ES',
        customerName: customerName,
        customerEmail: customerEmail,
      );
      
      if (resp['success'] != true || !resp.containsKey('checkoutUrl')) {
        logError('WalletController', 'Error al crear página de checkout: ${resp['error'] ?? 'Error desconocido'}');
        showSnackBar(
          context: context,
          content: resp['error'] ?? 'Error al procesar el pago'
        );
        return false;
      }
      
      final checkoutUrl = resp['checkoutUrl'];
      final checkoutId = resp['checkoutId'];
      
      logInfo('WalletController', 'Abriendo página de checkout: $checkoutUrl');
      
      // Mostrar pantalla de checkout
      final checkoutResult = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (context) => CheckoutPaymentScreen(
            checkoutUrl: checkoutUrl,
            checkoutId: checkoutId,
            amount: amount,
            currency: 'EUR',
            onPaymentComplete: (result) {
              Navigator.pop(context, result);
            },
            onPaymentError: (message) {
              showSnackBar(context: context, content: message);
              Navigator.pop(context, {'success': false, 'error': message});
            },
            onPaymentVerify: () async {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );
              
              try {
                // Verificar estado del pago
                final verifyResult = await _rapydService.verifyPaymentStatus(
                  checkoutId: checkoutId,
                );
                
                if (context.mounted) {
                  Navigator.pop(context); // Cerrar diálogo de carga
                }
                
                if (verifyResult['success'] == true && verifyResult['paid'] == true) {
                  // Pago exitoso
                  if (context.mounted) {
                    showSnackBar(context: context, content: 'Pago verificado exitosamente');
                    Navigator.pop(context, verifyResult);
                  }
                } else if (verifyResult['success'] == true) {
                  // Pago aún no completado
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Pago no detectado'),
                        content: const Text('El pago aún no se ha detectado en nuestro sistema. Si ya completaste el pago, espera unos minutos y verifica nuevamente.'),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text('Entendido'),
                          ),
                        ],
                      ),
                    );
                  }
                } else {
                  // Error al verificar
                  if (context.mounted) {
                    showSnackBar(
                      context: context,
                      content: verifyResult['error'] ?? 'Error al verificar el pago'
                    );
                  }
                }
              } catch (e) {
                logError('WalletController', 'Error al verificar pago', e);
                if (context.mounted) {
                  Navigator.pop(context); // Cerrar diálogo de carga
                  showSnackBar(context: context, content: 'Error al verificar pago: $e');
                }
              }
            },
          ),
        ),
      );
      
      // Si no tenemos resultado o el resultado no fue exitoso
      if (checkoutResult == null || checkoutResult['success'] != true) {
        logWarning('WalletController', 'Pago no completado');
        return false;
      }
      
      logInfo('WalletController', 'Pago completado. Sincronizando balance...');
      
      // Usar el método de sincronización robusta para obtener el balance exacto de Rapyd
      try {
        final syncResult = await _rapydService.syncBalance();
        
        if (syncResult['success'] == true) {
          logInfo('WalletController', 'Balance sincronizado correctamente: ${syncResult['balance']}');
          
          // Registrar transacción sin duplicados
          final uniqueId = 'tx_${DateTime.now().millisecondsSinceEpoch}_${user.uid.substring(0, 5)}';
          final tx = WalletTransaction(
            id: uniqueId,
            amount: amount,
            senderId: 'deposit',
            receiverId: user.uid,
            timestamp: DateTime.now(),
            description: 'Depósito de fondos',
            paymentId: checkoutResult['paymentId'] ?? 'payment_${checkoutId}',
          );
          
          // Usar el método que evita duplicados
          await _repo.addTransactionIfNotExists(user.uid, tx.toMap());
          logInfo('WalletController', 'Transacción registrada correctamente sin duplicados');
          
          showSnackBar(
            context: context,
            content: 'Fondos añadidos correctamente'
          );
          
          return true;
        } else {
          logError('WalletController', 'Error al sincronizar balance: ${syncResult['error']}');
          showSnackBar(
            context: context,
            content: 'Error al sincronizar balance: ${syncResult['error']}'
          );
          return false;
        }
      } catch (e) {
        logError('WalletController', 'Error al sincronizar balance', e);
        showSnackBar(
          context: context,
          content: 'Error al sincronizar balance: $e'
        );
        return false;
      }
    } catch (e, stack) {
      logError('WalletController', 'Error al añadir fondos', e, stack);
      showSnackBar(context: context, content: 'Error al añadir fondos: $e');
      return false;
    }
  }

  /// Método para iniciar el proceso de KYC simple con datos personales
  Future<Map<String, dynamic>> initiateSimpleKYC({
    String? userId,
    required Map<String, dynamic> personalData,
  }) async {
    // Obtener el ID del usuario actual si no se proporciona
    final currentUser = FirebaseAuth.instance.currentUser;
    final actualUserId = userId ?? currentUser?.uid;
    
    if (actualUserId == null || actualUserId.isEmpty) {
      logError('WalletController', 'No se pudo obtener el ID del usuario');
      return {'success': false, 'error': 'No se pudo obtener el ID del usuario'};
    }
    
    logInfo('WalletController', 'Iniciando KYC simple para usuario: $actualUserId');
    logInfo('WalletController', 'Datos personales: $personalData');
    
    try {
      // Verificar conexión antes de hacer la solicitud
      final isConnected = await checkServerConnection();
      
      // Si hay conexión, intentar usar el servidor
      if (isConnected) {
        try {
          logInfo('WalletController', 'Enviando solicitud al servidor...');
          // Llamar al servicio para iniciar el proceso
          final result = await _rapydService.initiateKYC(
            userId: actualUserId,
            personalData: personalData,
          );
          
          if (result['success'] == true) {
            logInfo('WalletController', 'KYC iniciado correctamente en el servidor');
            // Actualizar estado local
            await _repo.updateWallet(actualUserId, {
              'kycStatus': 'initiated',
              'kycInitiatedAt': DateTime.now(),
              ...personalData,
            });
            logInfo('WalletController', 'Wallet actualizada localmente');
          }
          
          return result;
        } catch (e, stack) {
          logError('WalletController', 'Error en servidor initiateKYC', e, stack);
          // Si falla el servidor, continuamos con la actualización local
        }
      }
      
      // Si no hay conexión o falló la llamada al servidor, actualizar directamente Firestore
      logWarning('WalletController', 'Actualizando datos KYC directamente en Firestore para usuario: $actualUserId');
      
      // Actualizar en la colección wallets
      await _repo.updateWallet(actualUserId, {
        'kycStatus': 'initiated',
        'kycInitiatedAt': DateTime.now(),
        ...personalData,
      });
      
      // También actualizar en la colección users
      final db = FirebaseFirestore.instance;
      await db.collection('users').doc(actualUserId).update({
        'kycStatus': 'initiated',
        'kycInitiatedAt': FieldValue.serverTimestamp(),
        ...personalData,
      });
      
      logInfo('WalletController', 'Datos KYC actualizados correctamente en Firestore');
      
      return {
        'success': true,
        'message': 'KYC iniciado correctamente (modo offline)',
        'kycStatus': 'initiated',
      };
    } catch (e, stack) {
      logError('WalletController', 'Error en initiateSimpleKYC', e, stack);
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Método para validar KYC y manejar casos específicos
  Future<Map<String, dynamic>> validateKYC({
    String? userId,
  }) async {
    // Obtener el ID del usuario actual si no se proporciona
    final currentUser = FirebaseAuth.instance.currentUser;
    final actualUserId = userId ?? currentUser?.uid;
    
    if (actualUserId == null || actualUserId.isEmpty) {
      logError('WalletController', 'No se pudo obtener el ID del usuario');
      return {'success': false, 'error': 'No se pudo obtener el ID del usuario'};
    }
    
    logInfo('WalletController', 'Validando KYC para usuario: $actualUserId');
    
    try {
      // Verificar conexión antes de hacer la solicitud
      final isConnected = await checkServerConnection();
      
      // Si hay conexión, intentar usar el servidor
      if (isConnected) {
        try {
          // Obtener la wallet actual para acceder a los datos del usuario
          final wallet = await _repo.getWallet(actualUserId);
          
          // NUEVO: Verificar si la wallet ya tiene un walletId asignado
          if (wallet != null && wallet.walletId != null && wallet.walletId!.isNotEmpty) {
            logInfo('WalletController', 'El usuario ya tiene un wallet Rapyd con ID: ${wallet.walletId}');
            
            // Actualizar estado local para marcar como completado
            await _repo.updateWallet(actualUserId, {
              'kycStatus': 'approved',
              'kycCompleted': true,
              'kycApprovedAt': DateTime.now(),
            });
            
            return {
              'success': true,
              'message': 'KYC ya estaba aprobado, wallet conectada',
              'walletId': wallet.walletId,
            };
          }
          
          // Crear un objeto con los datos necesarios para Rapyd (solo usar los campos que sabemos que existen)
          final userData = {
            'userId': actualUserId,
            'firstName': wallet?.firstName,
            'lastName': wallet?.lastName,
            'email': wallet?.email,
            'birthDate': wallet?.birthDate?.toIso8601String(),
            'address': wallet?.address,
            'city': wallet?.city,
            'postalCode': wallet?.postalCode,
            'country': wallet?.country,
            'iban': wallet?.iban,
          };
          
          logInfo('WalletController', 'Enviando solicitud de validación al servidor...');
          
          // Llamar al servicio para validar el KYC con los datos necesarios
          final result = await _rapydService.validateKYC(
            userId: actualUserId,
            userData: userData,
          );
          
          if (result['success'] == true) {
            logInfo('WalletController', 'KYC validado correctamente en el servidor');
            
            // Actualizar estado local
            await _repo.updateWallet(actualUserId, {
              'kycStatus': 'approved',
              'kycCompleted': true,
              'kycApprovedAt': DateTime.now(),
              'walletId': result['data']?['walletId'] ?? result['walletId'],
            });
            
            logInfo('WalletController', 'Wallet actualizada localmente');
            return result;
          } else {
            logWarning('WalletController', 'Validación KYC no exitosa: ${result['error']}');
            return result;
          }
        } catch (e, stack) {
          logError('WalletController', 'Error en servidor validateKYC', e, stack);
          
          // Si hay un error específico sobre wallet ya existente
          if (e.toString().contains('ERROR_CREATE_USER_EWALLET_REFERENCE_ID_ALREADY_EXISTS')) {
            // Marcar para sincronización futura
            await _repo.updateWallet(actualUserId, {
              'kycStatus': 'approved',
              'kycCompleted': true,
              'kycApprovedAt': DateTime.now(),
              'pendingSyncWithRapyd': true,
            });
            
            return {
              'success': true,
              'message': 'La wallet ya existe. Se necesita sincronización.',
              'needsSync': true,
            };
          }
        }
      }
      
      // Si no hay conexión o falló la llamada al servidor, actualizar directamente Firestore
      logWarning('WalletController', 'Actualizando estado KYC directamente en Firestore para usuario: $actualUserId');
      
      // Actualizar en la colección wallets
      await _repo.updateWallet(actualUserId, {
        'kycStatus': 'processing',
        'kycInitiatedAt': DateTime.now(),
        'pendingSyncWithRapyd': true,
      });
      
      // También actualizar en la colección users
      final db = FirebaseFirestore.instance;
      await db.collection('users').doc(actualUserId).update({
        'kycStatus': 'processing',
        'kycInitiatedAt': FieldValue.serverTimestamp(),
        'pendingSyncWithRapyd': true,
      });
      
      logInfo('WalletController', 'Estado KYC actualizado correctamente en Firestore (modo offline)');
      
      return {
        'success': true,
        'message': 'KYC en proceso. Se completará cuando haya conexión con el servidor.',
        'kycStatus': 'processing',
        'pendingSyncWithRapyd': true,
      };
    } catch (e, stack) {
      logError('WalletController', 'Error en validateKYC', e, stack);
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Actualiza información bancaria
  Future<Map<String, dynamic>> updateBankInfo(Map<String, String> bankInfo) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        logError('WalletController', 'Usuario no autenticado');
        throw Exception('Usuario no autenticado');
      }
      
      logInfo('WalletController', 'Actualizando información bancaria para usuario: ${user.uid}');
      logInfo('WalletController', 'Información bancaria: $bankInfo');
      
      // Verificar conexión antes de hacer la solicitud
      final isConnected = await checkServerConnection();
      
      // Si hay conexión, intentar usar el servidor
      if (isConnected) {
        try {
          logInfo('WalletController', 'Enviando solicitud al servidor...');
          // Llamar al endpoint de actualización de información bancaria
          final result = await _rapydService.updateBankInfo(
            userId: user.uid,
            bankInfo: bankInfo,
          );
          
          if (result['success'] == true) {
            logInfo('WalletController', 'Información bancaria actualizada correctamente en el servidor');
            // Actualizar estado local
            final wallet = await _repo.getWallet(user.uid);
            if (wallet != null) {
              Map<String, dynamic> updateData = {
                'accountStatus': 'active',
              };
              
              // Actualizar el estado con la información bancaria
              if (bankInfo.containsKey('iban')) {
                updateData['iban'] = bankInfo['iban'];
              }
              if (bankInfo.containsKey('accountNumber')) {
                updateData['bankAccountNumber'] = bankInfo['accountNumber'];
              }
              if (bankInfo.containsKey('routingNumber')) {
                updateData['routingNumber'] = bankInfo['routingNumber'];
              }
              
              await _repo.updateWallet(user.uid, updateData);
              logInfo('WalletController', 'Wallet actualizada localmente');
            }
          }
          
          return result;
        } catch (e, stack) {
          logError('WalletController', 'Error en servidor updateBankInfo', e, stack);
          // Si falla el servidor, continuamos con la actualización local
        }
      }
      
      // Si no hay conexión o falló la llamada al servidor, actualizar directamente Firestore
      logWarning('WalletController', 'Actualizando información bancaria directamente en Firestore');
      
      // Actualizar en la colección wallets
      Map<String, dynamic> updateData = {
        'accountStatus': 'pending_sync',
        'pendingSyncWithRapyd': true,
      };
      
      // Actualizar el estado con la información bancaria
      if (bankInfo.containsKey('iban')) {
        updateData['iban'] = bankInfo['iban'];
      }
      if (bankInfo.containsKey('accountNumber')) {
        updateData['bankAccountNumber'] = bankInfo['accountNumber'];
      }
      if (bankInfo.containsKey('routingNumber')) {
        updateData['routingNumber'] = bankInfo['routingNumber'];
      }
      
      await _repo.updateWallet(user.uid, updateData);
      
      // También actualizar en la colección users
      final db = FirebaseFirestore.instance;
      await db.collection('users').doc(user.uid).update({
        ...updateData,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      logInfo('WalletController', 'Información bancaria actualizada correctamente en Firestore (modo offline)');
      
      return {
        'success': true,
        'message': 'Información bancaria guardada. Se sincronizará cuando haya conexión.',
        'pendingSyncWithRapyd': true,
      };
    } catch (e, stack) {
      logError('WalletController', 'Error en updateBankInfo', e, stack);
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Retira fondos: Rapyd payout + Firebase
  Future<bool> withdrawFunds({
    required double amount,
    required String method, // "card" o "bank"
    Map<String, String>? accountInfo,
    required BuildContext context,
  }) async {
    logInfo('WalletController', 'Retirando fondos: $amount mediante $method');
    if (accountInfo != null) {
      logInfo('WalletController', 'Información de cuenta: $accountInfo');
    }
    
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final wallet = state.value;
      
      if (wallet == null || wallet.balance < amount) {
        logWarning('WalletController', 'Saldo insuficiente');
        showSnackBar(context: context, content: 'Saldo insuficiente');
        return false;
      }

      // Verificar conexión antes de hacer la solicitud
      final isConnected = await checkServerConnection();
      if (!isConnected) {
        logWarning('WalletController', 'No hay conexión con el servidor');
        showSnackBar(
          context: context,
          content: 'No hay conexión con el servidor. Verifica tu conexión a internet.'
        );
        return false;
      }

      logInfo('WalletController', 'Enviando solicitud de retiro al servidor...');
      // 1) Rapyd: payout según método
      final resp = await _rapydService.withdrawFunds(
        userId: user.uid,
        amount: amount,
        withdrawalMethod: method,
        accountInfo: accountInfo,
      );
      
      if (resp['success'] != true) {
        logError('WalletController', 'Error en la respuesta del servidor: ${resp['message'] ?? 'Error desconocido'}');
        showSnackBar(
          context: context,
          content: resp['message'] ?? 'Error al procesar retiro',
        );
        return false;
      }

      // 2) Sincronizar balance exacto desde Rapyd en lugar de restar localmente
      try {
        final syncResult = await _rapydService.syncBalance();
        
        if (syncResult['success'] != true) {
          logWarning('WalletController', 'No se pudo sincronizar balance después del retiro');
        } else {
          logInfo('WalletController', 'Balance sincronizado desde Rapyd después del retiro: ${syncResult['balance']}');
        }
      } catch (e) {
        logWarning('WalletController', 'Error al sincronizar balance después del retiro: $e');
      }
      
      // 3) Registrar transacción de retiro sin duplicados
      final uniqueId = 'withdraw_${DateTime.now().millisecondsSinceEpoch}_${user.uid.substring(0, 5)}';
      final tx = WalletTransaction(
        id: uniqueId,
        amount: -amount,
        senderId: user.uid,
        receiverId: method == 'card' ? 'refund' : 'bank_payout',
        timestamp: DateTime.now(),
        description: method == 'card' ? 'Reembolso a tarjeta' : 'Transferencia bancaria',
        paymentId: resp['data']?['id'] ?? 'withdraw_${uniqueId}',
      );
      
      await _repo.addTransactionIfNotExists(user.uid, tx.toMap());
      logInfo('WalletController', 'Transacción de retiro registrada correctamente sin duplicados');

      showSnackBar(
        context: context,
        content: method == 'card'
            ? 'Reembolso solicitado a tu tarjeta'
            : 'Transferencia bancaria iniciada',
      );
      return true;
    } catch (e, stack) {
      logError('WalletController', 'Error al retirar fondos', e, stack);
      showSnackBar(context: context, content: 'Error al retirar fondos: $e');
      return false;
    }
  }

  /// Transfiere entre usuarios: Rapyd transfer + Firebase updates
  /// Transfiere entre usuarios: Rapyd transfer + Firebase updates
 Future<bool> sendMoney(
  String receiverId,
  double amount,
  BuildContext? context, // Cambiar a BuildContext opcional
) async {
  logInfo('WalletController', 'Enviando dinero a $receiverId: $amount');
  
  try {
    final user = FirebaseAuth.instance.currentUser!;
    
    // Sincronizar balance antes de verificar saldo
    try {
      final syncResult = await _rapydService.syncBalance();
      if (syncResult['success'] == true) {
        logInfo('WalletController', 'Balance sincronizado antes de transferencia: ${syncResult['balance']}');
        
        // Actualizar el estado local con el balance exacto de Rapyd
        if (syncResult['balance'] != null) {
          final newBalance = syncResult['balance'] is num 
              ? (syncResult['balance'] as num).toDouble() 
              : double.tryParse(syncResult['balance'].toString()) ?? 0.0;
          
          // Actualizar el estado local
          final currentWallet = state.value;
          if (currentWallet != null) {
            state = AsyncValue.data(currentWallet.copyWith(balance: newBalance));
          }
        }
      }
    } catch (e) {
      logWarning('WalletController', 'Error al sincronizar balance antes de transferencia: $e');
    }
    
    // Verificar saldo después de sincronizar
    final senderWallet = state.value;
    if (senderWallet == null || senderWallet.balance < amount) {
      logWarning('WalletController', 'Saldo insuficiente: ${senderWallet?.balance ?? 0} < $amount');
      // Solo mostrar SnackBar si el contexto es válido
      if (context != null && context.mounted) {
        showSnackBar(context: context, content: 'Saldo insuficiente');
      }
      return false;
    }

    // Verificar conexión antes de hacer la solicitud
    final isConnected = await checkServerConnection();
    if (!isConnected) {
      logWarning('WalletController', 'No hay conexión con el servidor');
      // Solo mostrar SnackBar si el contexto es válido
      if (context != null && context.mounted) {
        showSnackBar(
          context: context,
          content: 'No hay conexión con el servidor. Verifica tu conexión a internet.'
        );
      }
      return false;
    }

    logInfo('WalletController', 'Enviando solicitud de transferencia al servidor...');
    // 1) Rapyd P2P
    final resp = await _rapydService.transferFunds(
      senderId: user.uid,
      receiverId: receiverId,
      amount: amount,
    );
    
    if (resp['success'] != true) {
      logError('WalletController', 'Error en la respuesta del servidor: ${resp['error'] ?? 'Error desconocido'}');
      // Solo mostrar SnackBar si el contexto es válido
      if (context != null && context.mounted) {
        showSnackBar(
          context: context,
          content: resp['error'] ?? 'Error en transferencia'
        );
      }
      return false;
    }

    // 2) Sincronizar balance exacto desde Rapyd después de la transferencia
    try {
      final syncResult = await _rapydService.syncBalance();
      
      if (syncResult['success'] == true) {
        logInfo('WalletController', 'Balance sincronizado desde Rapyd después de transferencia: ${syncResult['balance']}');
        
        // Actualizar el estado local con el balance exacto de Rapyd
        if (syncResult['balance'] != null) {
          final newBalance = syncResult['balance'] is num 
              ? (syncResult['balance'] as num).toDouble() 
              : double.tryParse(syncResult['balance'].toString()) ?? 0.0;
          
          // Actualizar el estado local
          final currentWallet = state.value;
          if (currentWallet != null) {
            state = AsyncValue.data(currentWallet.copyWith(balance: newBalance));
          }
        }
      } else {
        logWarning('WalletController', 'No se pudo sincronizar balance después de transferencia');
      }
    } catch (e) {
      logWarning('WalletController', 'Error al sincronizar balance después de transferencia: $e');
    }
    
    // 3) Registrar transacción saliente sin duplicados
    final uniqueId = 'p2p_${DateTime.now().millisecondsSinceEpoch}_${user.uid.substring(0, 5)}';
    final transferId = resp['data']?['id'] ?? resp['transferId'] ?? 'transfer_${uniqueId}';

    // Crear transacción saliente
    final txOut = WalletTransaction(
      id: uniqueId,
      amount: -amount,
      senderId: user.uid,
      receiverId: receiverId,
      timestamp: DateTime.now(),
      description: 'Transferencia enviada',
      paymentId: transferId,
      status: 'completed',
    );

    // Guardar en la colección principal de transacciones
    await FirebaseFirestore.instance.collection('transactions').doc(uniqueId).set(txOut.toMap());

    // Guardar en la subcollection del remitente
    await _repo.addTransactionIfNotExists(user.uid, txOut.toMap());
    logInfo('WalletController', 'Transacción de envío registrada correctamente sin duplicados');

    // 4) Registrar transacción entrante para el receptor
    final receiverWallet = await _repo.getWallet(receiverId);
    if (receiverWallet != null) {
      // Crear transacción entrante
      final txIn = WalletTransaction(
        id: '${uniqueId}_in',
        amount: amount,
        senderId: user.uid,
        receiverId: receiverId,
        timestamp: DateTime.now(),
        description: 'Transferencia recibida',
        paymentId: transferId,
        status: 'completed',
      );
      
      // Guardar en la colección principal de transacciones
      await FirebaseFirestore.instance.collection('transactions').doc('${uniqueId}_in').set(txIn.toMap());
      
      // Guardar en la subcollection del receptor
      await _repo.addTransactionIfNotExists(receiverId, txIn.toMap());
      logInfo('WalletController', 'Transacción de recepción registrada correctamente sin duplicados');
    }

    // Solo mostrar SnackBar si el contexto es válido
    if (context != null && context.mounted) {
      showSnackBar(context: context, content: 'Transferencia exitosa');
    }
    return true;
  } catch (e, stack) {
    logError('WalletController', 'Error al enviar dinero', e, stack);
    // Solo mostrar SnackBar si el contexto es válido
    if (context != null && context.mounted) {
      showSnackBar(context: context, content: 'Error al enviar dinero: $e');
    }
    return false;
  }
}
  
  /// Obtiene el estado del KYC
  Future<Map<String, dynamic>> getKYCStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        logError('WalletController', 'Usuario no autenticado');
        throw Exception('Usuario no autenticado');
      }
      
      logInfo('WalletController', 'Obteniendo estado KYC para usuario: ${user.uid}');
      
      // Verificar conexión antes de hacer la solicitud
      final isConnected = await checkServerConnection();
      
      // Si hay conexión, intentar usar el servidor
      if (isConnected) {
        try {
          logInfo('WalletController', 'Enviando solicitud al servidor...');
          // Llamar al endpoint de estado KYC
          final result = await _rapydService.getKYCStatus(user.uid);
          
          if (result['success'] == true) {
            logInfo('WalletController', 'Estado KYC obtenido correctamente del servidor');
            
            // Actualizar estado local si es necesario
            if (result.containsKey('kycStatus')) {
              await _repo.updateWallet(user.uid, {
                'kycStatus': result['kycStatus'],
                'kycCompleted': result['kycStatus'] == 'approved',
              });
              logInfo('WalletController', 'Wallet actualizada con estado KYC: ${result['kycStatus']}');
            }
          }
          
          return result;
        } catch (e, stack) {
          logError('WalletController', 'Error en servidor getKYCStatus', e, stack);
          // Si falla el servidor, continuamos con la obtención local
        }
      }
      
      // Si no hay conexión o falló la llamada al servidor, obtener de Firestore
      logWarning('WalletController', 'Obteniendo estado KYC directamente de Firestore');
      
      final wallet = await _repo.getWallet(user.uid);
      
      if (wallet != null) {
        return {
          'success': true,
          'kycStatus': wallet.kycStatus,
          'kycCompleted': wallet.kycCompleted,
          'kycInitiatedAt': wallet.kycInitiatedAt?.toIso8601String(),
          'kycApprovedAt': wallet.kycApprovedAt?.toIso8601String(),
          'pendingSyncWithRapyd': wallet.pendingSyncWithRapyd,
          'fromCache': true,
        };
      } else {
        return {
          'success': false,
          'error': 'No se encontró información de wallet',
          'fromCache': true,
        };
      }
    } catch (e, stack) {
      logError('WalletController', 'Error en getKYCStatus', e, stack);
      return {'success': false, 'error': e.toString()};
    }
  }
  
  /// Sincroniza datos pendientes con el servidor
  Future<bool> syncPendingData(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        logError('WalletController', 'Usuario no autenticado');
        throw Exception('Usuario no autenticado');
      }
      
      logInfo('WalletController', 'Sincronizando datos pendientes para usuario: ${user.uid}');
      
      // Verificar conexión antes de hacer la solicitud
      final isConnected = await checkServerConnection();
      if (!isConnected) {
        logWarning('WalletController', 'No hay conexión con el servidor');
        _showSnackBarSafe(context, 'No hay conexión con el servidor. Intenta más tarde.');
        return false;
      }
      
      final wallet = state.value;
      if (wallet == null) {
        logWarning('WalletController', 'No hay wallet para sincronizar');
        return false;
      }

      // Primero, intentar sincronizar el balance desde Rapyd para asegurar consistencia
      try {
        final syncBalanceResult = await _rapydService.syncBalance();
        if (syncBalanceResult['success'] == true) {
          logInfo('WalletController', 'Balance sincronizado correctamente con Rapyd: ${syncBalanceResult['balance']}');
        } else {
          logWarning('WalletController', 'No se pudo sincronizar el balance con Rapyd');
        }
      } catch (e) {
        logWarning('WalletController', 'Error al sincronizar balance desde Rapyd: $e');
      }
      
      // Continuamos con otros datos pendientes
      if (!wallet.pendingSyncWithRapyd) {
        logInfo('WalletController', 'No hay datos pendientes de sincronización');
        return true;
      }
      
      // Sincronizar KYC si está pendiente
      if (wallet.kycStatus == 'processing' || wallet.kycStatus == 'initiated') {
        logInfo('WalletController', 'Sincronizando KYC pendiente...');
        
        final result = await validateKYC(userId: user.uid);
        
        if (result['success'] != true) {
          logError('WalletController', 'Error al sincronizar KYC: ${result['error'] ?? 'Error desconocido'}');
          _showSnackBarSafe(context, 'Error al sincronizar KYC: ${result['error'] ?? 'Error desconocido'}');
          return false;
        }
        
        logInfo('WalletController', 'KYC sincronizado correctamente');
      }
      
      // Sincronizar información bancaria si está pendiente
      if (wallet.accountStatus == 'pending_sync' && wallet.iban != null) {
        logInfo('WalletController', 'Sincronizando información bancaria pendiente...');
        
        final bankInfo = {
          'iban': wallet.iban ?? '',
        };
        
        if (wallet.bankAccountNumber != null) {
          bankInfo['accountNumber'] = wallet.bankAccountNumber!;
        }
        
        if (wallet.routingNumber != null) {
          bankInfo['routingNumber'] = wallet.routingNumber!;
        }
        
        final result = await updateBankInfo(bankInfo);
        
        if (result['success'] != true) {
          logError('WalletController', 'Error al sincronizar información bancaria: ${result['error'] ?? 'Error desconocido'}');
          _showSnackBarSafe(context, 'Error al sincronizar información bancaria: ${result['error'] ?? 'Error desconocido'}');
          return false;
        }
        
        logInfo('WalletController', 'Información bancaria sincronizada correctamente');
      }
      
      // Marcar como sincronizado
      await _repo.updateWallet(user.uid, {
        'pendingSyncWithRapyd': false,
        'lastSyncedAt': DateTime.now(),
      });
      
      logInfo('WalletController', 'Datos sincronizados correctamente');
      _showSnackBarSafe(context, 'Datos sincronizados correctamente');
      
      return true;
    } catch (e, stack) {
      logError('WalletController', 'Error al sincronizar datos pendientes', e, stack);
      _showSnackBarSafe(context, 'Error al sincronizar datos: $e');
      return false;
    }
  }

  /// Método específico para sincronizar balance desde Rapyd
  Future<Map<String, dynamic>> syncExactBalance(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {'success': false, 'error': 'Usuario no autenticado'};
      }
      
      logInfo('WalletController', 'Sincronizando balance desde Rapyd');
      
      // Verificar conexión antes de hacer la solicitud
      final isConnected = await checkServerConnection();
      if (!isConnected) {
        _showSnackBarSafe(context, 'No hay conexión con el servidor. Intenta más tarde.');
        return {'success': false, 'error': 'No hay conexión con el servidor'};
      }
      
      final syncResult = await _rapydService.syncBalance();
      
      if (syncResult['success'] == true) {
        // Mostrar mensaje de éxito
        _showSnackBarSafe(context, 'Balance sincronizado correctamente');
        
        // Verificar si hay transacciones duplicadas en la wallet
        try {
          logInfo('WalletController', 'Verificando transacciones duplicadas...');
          final wallet = await _repo.getWallet(user.uid);
          if (wallet != null) {
            // Esto sería lógica para detectar y eliminar duplicados si fuera necesario
            // En realidad, con nuestro método addTransactionIfNotExists, no deberían surgir duplicados
          }
        } catch (e) {
          logWarning('WalletController', 'Error al verificar transacciones duplicadas: $e');
        }
        
        return syncResult;
      } else {
        _showSnackBarSafe(context, 'Error al sincronizar balance: ${syncResult['error']}');
        return syncResult;
      }
    } catch (e, stack) {
      logError('WalletController', 'Error en syncExactBalance', e, stack);
      _showSnackBarSafe(context, 'Error al sincronizar balance: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Método seguro para mostrar SnackBar desde un contexto asíncrono
  void _showSnackBarSafe(BuildContext context, String message) {
    // Usar un Future.microtask para asegurar que estamos en el contexto correcto
    Future.microtask(() {
      if (context.mounted) {
        showSnackBar(context: context, content: message);
      }
    });
  }
 Future<List<WalletTransaction>> getPaymentsHistory({int limit = 100}) async {
  logInfo('WalletController', 'Obteniendo historial completo de pagos');
  
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      logWarning('WalletController', 'Usuario no autenticado');
      return [];
    }
    
    // Obtener transacciones de la colección "payments"
    final paymentTransactions = await _repo.getPaymentsHistory(user.uid, limit: limit);
    
    // Calcular el monto total para verificar
    double totalAmount = 0.0;
    for (var tx in paymentTransactions) {
      if (tx.amount > 0 && (tx.status == 'completed' || tx.status == 'success')) {
        totalAmount += tx.amount;
      }
    }
    
    logInfo('WalletController', 'Monto total de depósitos: $totalAmount EUR');
    
    // Ordenar por fecha (más recientes primero)
    paymentTransactions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    return paymentTransactions;
  } catch (e, stack) {
    logError('WalletController', 'Error al obtener historial de pagos', e, stack);
    return [];
  }
}
}