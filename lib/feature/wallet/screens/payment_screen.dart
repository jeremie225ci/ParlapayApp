import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mk_mesenger/common/utils/widgets/loader.dart';
import 'package:mk_mesenger/common/utils/widgets/snackbar.dart';
import 'package:mk_mesenger/feature/wallet/controller/wallet_controller.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  static const String routeName = '/payment';
  
  final String receiverId;
  final String receiverName;

  const PaymentScreen({
    Key? key,
    required this.receiverId,
    required this.receiverName,
  }) : super(key: key);

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  final TextEditingController _amountController = TextEditingController();
  bool _isLoading = false;
  double _currentBalance = 0.0;

  @override
  void initState() {
    super.initState();
    debugPrint('🏗️ Inicializando PaymentScreen para receptor: ${widget.receiverId}');
    _loadWalletData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _loadWalletData() {
    debugPrint('🔄 Cargando datos de wallet en PaymentScreen');
    final walletState = ref.read(walletControllerProvider);
    
    walletState.whenData((wallet) {
      if (wallet != null) {
        debugPrint('💰 Balance actual: ${wallet.balance}');
        setState(() {
          _currentBalance = wallet.balance;
        });
      } else {
        debugPrint('⚠️ No se encontraron datos de wallet');
      }
    });
  }

  Future<void> _sendPayment() async {
    // Validar entrada
    if (_amountController.text.isEmpty) {
      debugPrint('❌ Monto vacío');
      showSnackBar(context: context, content: 'Por favor ingresa un monto');
      return;
    }

    double amount;
    try {
      // Convertir y validar el monto
      amount = double.parse(_amountController.text.replaceAll(',', '.'));
      debugPrint('💰 Monto a enviar: $amount');
      
      if (amount <= 0) {
        debugPrint('❌ Monto inválido: $amount');
        showSnackBar(context: context, content: 'El monto debe ser mayor a 0');
        return;
      }
      
      if (amount > _currentBalance) {
        debugPrint('❌ Saldo insuficiente: $amount > $_currentBalance');
        showSnackBar(context: context, content: 'Saldo insuficiente');
        return;
      }
    } catch (e) {
      debugPrint('❌ Error al convertir monto: $e');
      showSnackBar(context: context, content: 'Monto inválido');
      return;
    }

    // Verificar conexión con el servidor
    final isConnected = await ref.read(walletControllerProvider.notifier).checkServerConnection();
    debugPrint('🌐 Conexión con el servidor: ${isConnected ? 'OK' : 'Fallida'}');
    
    if (!isConnected) {
      if (mounted) {
        showSnackBar(
          context: context,
          content: 'No hay conexión con el servidor. Intenta más tarde.',
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('🔄 Enviando pago a ${widget.receiverId}...');
      
      final success = await ref.read(walletControllerProvider.notifier).sendMoney(
        widget.receiverId,
        amount,
        context,
      );
      
      debugPrint('📊 Resultado de sendMoney: $success');

      if (success && mounted) {
        debugPrint('✅ Pago enviado correctamente');
        showSnackBar(
          context: context,
          content: 'Pago enviado correctamente',
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('🔴 Error en _sendPayment: $e');
      if (mounted) {
        showSnackBar(
          context: context,
          content: 'Error al enviar pago: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enviar Pago'),
      ),
      body: _isLoading
          ? const Loader()
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Información del receptor
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Enviar pago a:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.receiverName,
                            style: const TextStyle(fontSize: 18),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ID: ${widget.receiverId}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Saldo actual
                  Text(
                    'Saldo disponible: €${_currentBalance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Campo de monto
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Monto (EUR)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.euro),
                      hintText: '0.00',
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Botón de envío
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _sendPayment,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Enviar Pago',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
