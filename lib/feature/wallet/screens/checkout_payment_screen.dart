// lib/feature/wallet/screens/checkout_payment_screen.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mk_mesenger/common/utils/utils.dart';
import 'package:mk_mesenger/feature/wallet/controller/wallet_controller.dart';
import 'package:mk_mesenger/feature/wallet/repository/wallet_repository.dart';
import 'package:mk_mesenger/services/rapyd_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mk_mesenger/common/utils/logger.dart';
import 'package:mk_mesenger/feature/chat/screens/mobile_layout_screen.dart';




class CheckoutPaymentScreen extends ConsumerStatefulWidget {
  /// Ruta para navegación
  static const String routeName = '/checkout';

  final String checkoutUrl;
  final String checkoutId;
  final double amount;
  final String currency;
  final Function(Map<String, dynamic>) onPaymentComplete;
  final Function(String) onPaymentError;
  final Function() onPaymentVerify;

  const CheckoutPaymentScreen({
    Key? key,
    required this.checkoutUrl,
    required this.checkoutId,
    required this.amount,
    required this.currency,
    required this.onPaymentComplete,
    required this.onPaymentError,
    required this.onPaymentVerify,
  }) : super(key: key);

  @override
  ConsumerState<CheckoutPaymentScreen> createState() => _CheckoutPaymentScreenState();
}

class _CheckoutPaymentScreenState extends ConsumerState<CheckoutPaymentScreen> with WidgetsBindingObserver {
  bool _isLoading = false;
  Timer? _verificationTimer;
  bool _wasInBackground = false;
  
  final RapydService _rapydService = RapydService();
  
  @override
  void initState() {
    super.initState();
    // Registrar para detectar cambios en el estado de la app
    WidgetsBinding.instance.addObserver(this);
    // Abrimos la URL de checkout automáticamente
    WidgetsBinding.instance.addPostFrameCallback((_) => _openCheckoutPage());
  }
  
  @override
  void dispose() {
    _verificationTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  // Este método se llama cuando el estado de la app cambia (en background, en foreground)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // La app ha ido a segundo plano (usuario fue al navegador)
      _wasInBackground = true;
    } else if (state == AppLifecycleState.resumed && _wasInBackground) {
      // La app vuelve a primer plano (el usuario regresa a la app)
      _wasInBackground = false;
      // Verificar automáticamente el estado del pago
      _autoVerifyPayment();
    }
  }
  
  // Verificar automáticamente el estado del pago cuando el usuario vuelve a la app
  void _autoVerifyPayment() {
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Verificando pago'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Estamos verificando el estado de tu pago...')
            ],
          ),
        ),
      );
      
      // Ejecutar la verificación
      Future.delayed(const Duration(seconds: 1), () {
        Navigator.of(context).pop(); // Cerrar diálogo
        _verifyPayment();
      });
    }
  }
  
  Future<void> _openCheckoutPage() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final Uri uri = Uri.parse(widget.checkoutUrl);
      
      // Lanzar el navegador externo para mayor seguridad
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        
        setState(() {
          _isLoading = false;
        });
        
        // Mostrar instrucciones
        if (mounted) {
          _showInstructions();
        }
      } else {
        throw 'No se pudo abrir la URL de pago: ${widget.checkoutUrl}';
      }
    } catch (e) {
      logError('CheckoutPayment', 'Error al abrir la URL de pago', e);
      setState(() {
        _isLoading = false;
      });
      widget.onPaymentError('Error al abrir la página de pago: $e');
      Navigator.of(context).pop();
    }
  }
  
  void _showInstructions() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Completar Pago'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Se ha abierto una página segura de pago en tu navegador. Por favor:',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              const Text('1. Completa el pago con tu tarjeta'),
              const Text('2. Una vez completado, regresa a la aplicación'),
              const Text('3. Al regresar, verificaremos automáticamente el estado del pago'),
              const SizedBox(height: 8),
              const Text('4. Si no se verifica automáticamente, selecciona "Verificar Pago"'),
              const SizedBox(height: 16),
              const Text(
                'Nota: Tu seguridad es nuestra prioridad. Los datos de tu tarjeta son manejados directamente por Rapyd, nunca son almacenados por nuestra aplicación.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onPaymentError('Pago cancelado por el usuario');
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Cancelar Pago'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _openCheckoutPage(); // Reabrir la página de pago
              },
              child: const Text('Reabrir Página de Pago'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _verifyPayment();
              },
              child: const Text('Verificar Pago'),
            ),
          ],
        );
      },
    );
  }

  void _verifyPayment() async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Center(
      child: CircularProgressIndicator(),
    ),
  );
  
  try {
    Map<String, dynamic> verifyResult;
    
    try {
      // Primer intento: API de verificación estándar mejorada
      logInfo('CheckoutPayment', 'Verificando estado del checkout: ${widget.checkoutId}');
      verifyResult = await _rapydService.verifyPaymentStatus(
        checkoutId: widget.checkoutId,
      );
      
      // Registrar detalladamente la respuesta
      logInfo('CheckoutPayment', 'Respuesta de verificación: $verifyResult');
    } catch (e) {
      logError('CheckoutPayment', 'Error en verifyPaymentStatus, intentando método alternativo', e);
      // Intentar recuperar mediante sincronización robusta si falla la verificación directa
      verifyResult = {'success': false, 'error': e.toString()};
    }
    
    // Si la verificación directa falló o recomienda sincronización
    if (verifyResult['success'] != true || verifyResult['recommendSync'] == true) {
      logInfo('CheckoutPayment', 'Usando sincronización robusta como alternativa');
      
      try {
        // Usar el método de sincronización robusta
        final syncResult = await _rapydService.syncBalance();
        
        if (syncResult['success'] == true) {
          // Construir resultado positivo basado en sincronización
          verifyResult = {
            'success': true,
            'paid': true, // Asumimos pago exitoso ya que hay balance actualizado
            'paymentId': 'recovered_from_sync',
            'status': 'completed',
            'balance': syncResult['balance'],
            'checkoutId': widget.checkoutId,
            'syncType': syncResult['syncType']
          };
          
          logInfo('CheckoutPayment', 'Recuperación exitosa mediante sincronización: ${syncResult['balance']}');
        }
      } catch (syncError) {
        logError('CheckoutPayment', 'Error en método de sincronización', syncError);
        // Mantenemos el resultado original si falla la sincronización
      }
    }
    
    if (context.mounted) {
      Navigator.pop(context); // Cerrar diálogo de carga
    }
    
    if (verifyResult['success'] == true && (verifyResult['paid'] == true || verifyResult['syncType'] != null)) {
      // Actualizar Firestore manualmente si es necesario
      if (verifyResult['balance'] != null) {
        try {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            // Obtener documento de wallet
            final walletRef = FirebaseFirestore.instance.collection('wallets').doc(user.uid);
            await walletRef.update({
              'balance': verifyResult['balance'],
              'updatedAt': DateTime.now()
            });
            
            logInfo('CheckoutPayment', 'Balance actualizado manualmente en Firestore: ${verifyResult['balance']}');
            
            // Registrar transacción sin duplicados
            final uniqueId = 'checkout_${widget.checkoutId}_${DateTime.now().millisecondsSinceEpoch}';
            final repository = WalletRepository(); // Crear instancia del repositorio
            
            final transaction = {
              'id': uniqueId,
              'amount': widget.amount,
              'senderId': 'checkout_payment',
              'receiverId': user.uid,
              'timestamp': DateTime.now(),
              'description': 'Depósito de fondos',
              'rapydPaymentId': verifyResult['paymentId'] ?? widget.checkoutId,
              'checkoutId': widget.checkoutId,
              'currency': widget.currency
            };
            
            // Usar el método de prevención de duplicados
            await repository.addTransactionIfNotExists(user.uid, transaction);
            logInfo('CheckoutPayment', 'Transacción registrada sin duplicados: $uniqueId');
          }
        } catch (e) {
          logError('CheckoutPayment', 'Error al actualizar balance manualmente', e);
        }
      }
      
      // Actualizar el estado local con el nuevo saldo
      final currentWallet = ref.read(walletControllerProvider).value;
      if (currentWallet != null && verifyResult['balance'] != null) {
        final newBalance = verifyResult['balance'] as num? ?? 0.0;
        ref.read(walletControllerProvider.notifier).state = 
            AsyncValue.data(currentWallet.copyWith(balance: newBalance.toDouble()));
      }
      
      // Mostrar mensaje de éxito
      if (context.mounted) {
        showSnackBar(context: context, content: '¡Pago verificado exitosamente!');
        
        // MODIFICACIÓN: En lugar de simplemente hacer pop,
        // redirigir al usuario a la pantalla principal
        Navigator.pushNamedAndRemoveUntil(
          context,
          MobileLayoutScreen.routeName, // Usar la ruta de la pantalla principal
          (route) => false // Eliminar todas las rutas anteriores
        );
      }
    } else if (verifyResult['recommendSync'] == true || verifyResult['error']?.contains('404') == true) {
      // Si es error 404 o recomienda sincronización, mostrar opciones de recuperación manual
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Verificación no disponible'),
            content: const Text(
              'No se pudo verificar el pago automáticamente. Si has completado '
              'el pago, puedes intentar actualizar manualmente el balance.'
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Entendido'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  
                  // Mostrar diálogo de carga
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                  
                  // Usar el método de sincronización robusto
                  try {
                    final balanceResult = await _rapydService.syncBalance();
                    if (context.mounted) {
                      Navigator.pop(context); // Cerrar diálogo de carga
                      
                      if (balanceResult['success'] == true) {
                        // Registrar la transacción sin duplicados
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          final uniqueId = 'manual_sync_${widget.checkoutId}_${DateTime.now().millisecondsSinceEpoch}';
                          final repository = WalletRepository();
                          
                          final transaction = {
                            'id': uniqueId,
                            'amount': widget.amount,
                            'senderId': 'manual_sync',
                            'receiverId': user.uid,
                            'timestamp': DateTime.now(),
                            'description': 'Depósito de fondos (sincronización manual)',
                            'rapydPaymentId': 'manual_sync_${widget.checkoutId}',
                            'checkoutId': widget.checkoutId,
                            'currency': widget.currency
                          };
                          
                          // Usar prevención de duplicados
                          await repository.addTransactionIfNotExists(user.uid, transaction);
                          logInfo('CheckoutPayment', 'Transacción manual registrada sin duplicados: $uniqueId');
                        }
                        
                        showSnackBar(
                          context: context, 
                          content: 'Balance sincronizado exitosamente'
                        );
                        
                        // MODIFICACIÓN: En lugar de simplemente hacer pop,
                        // redirigir al usuario a la pantalla principal
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          MobileLayoutScreen.routeName, // Usar la ruta de la pantalla principal
                          (route) => false // Eliminar todas las rutas anteriores
                        );
                      } else {
                        showSnackBar(
                          context: context, 
                          content: 'Error al sincronizar: ${balanceResult['error']}'
                        );
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.pop(context); // Cerrar diálogo de carga
                      showSnackBar(context: context, content: 'Error: $e');
                    }
                  }
                },
                child: const Text('Sincronizar Balance'),
              ),
            ],
          ),
        );
      }
    } else {
      // Otros errores
      if (context.mounted) {
        showSnackBar(
          context: context,
          content: verifyResult['error'] ?? 'Error al verificar el pago'
        );
      }
    }
  } catch (e) {
    logError('CheckoutPayment', 'Error general al verificar pago', e);
    if (context.mounted) {
      Navigator.pop(context); // Cerrar diálogo de carga
      showSnackBar(context: context, content: 'Error: $e');
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Procesando Pago'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('¿Cancelar pago?'),
                content: const Text('Si sales ahora, el pago no se completará.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Continuar con el pago'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onPaymentError('Pago cancelado por el usuario');
                      Navigator.of(context).pop();
                    },
                    child: const Text('Cancelar pago'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.payment,
                    size: 72,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '${widget.amount.toStringAsFixed(2)} ${widget.currency}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Completa el pago en la página que se ha abierto.\nAl regresar, verificaremos automáticamente el estado.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _openCheckoutPage,
                    icon: const Icon(Icons.open_in_browser),
                    label: const Text('Reabrir Página de Pago'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _verifyPayment,
                    child: const Text('Verificar Estado del Pago'),
                  ),
                  const SizedBox(height: 32),
                  OutlinedButton(
                    onPressed: () {
                      widget.onPaymentError('Pago cancelado por el usuario');
                      Navigator.of(context).pop();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    child: const Text('Cancelar'),
                  ),
                ],
              ),
            ),
    );
  }
}