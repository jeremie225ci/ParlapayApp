import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mk_mesenger/common/utils/logger.dart';
import 'package:mk_mesenger/common/utils/widgets/loader.dart';
import 'package:mk_mesenger/common/utils/widgets/snackbar.dart';
import 'package:mk_mesenger/feature/wallet/controller/wallet_controller.dart';
import 'package:intl/intl.dart';
import 'package:mk_mesenger/common/models/wallet.dart';
import 'package:mk_mesenger/common/utils/colors.dart';

class WalletScreen extends ConsumerStatefulWidget {
  static const String routeName = '/wallet';

  const WalletScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  final TextEditingController _amountController = TextEditingController();
  bool _isAddingFunds = false;
  bool _isSyncing = false;
  bool _isLoadingTransactions = false;

  @override
  void initState() {
    super.initState();
    logInfo('WalletScreen', 'Inicializando WalletScreen');
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verificarKyc();
    });
    
    _checkServerConnection();
  }

  void _verificarKyc() {
    logInfo('WalletScreen', 'Verificación EXTRA de KYC en WalletScreen');
    
    try {
      final wallet = ref.read(walletControllerProvider).value;
      
      logInfo('WalletScreen', '======= VERIFICACIÓN KYC EXTRA =======');
      logInfo('WalletScreen', 'Wallet es null: ${wallet == null}');
      if (wallet != null) {
        logInfo('WalletScreen', 'kycCompleted: ${wallet.kycCompleted}');
        logInfo('WalletScreen', 'kycStatus: ${wallet.kycStatus}');
      }
      
      bool needsKyc = true;
      
      if (wallet != null && 
          wallet.kycCompleted == true && 
          wallet.kycStatus == 'approved') {
        needsKyc = false;
      }
      
      logInfo('WalletScreen', 'Necesita KYC: $needsKyc');
      logInfo('WalletScreen', '====================================');
      
      if (needsKyc && mounted) {
        logInfo('WalletScreen', '🔴 REDIRECCIÓN DE EMERGENCIA A KYC 🔴');
        
        Navigator.pushReplacementNamed(context, '/kyc');
      }
    } catch (e, stack) {
      logError('WalletScreen', 'Error crítico verificando KYC', e, stack);
      
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/kyc');
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _checkServerConnection() async {
    logInfo('WalletScreen', 'Verificando conexión con el servidor...');
    final isConnected = await ref.read(walletControllerProvider.notifier).checkServerConnection();
    logInfo('WalletScreen', 'Conexión con el servidor: ${isConnected ? 'OK' : 'Fallida'}');
    
    if (!isConnected && mounted) {
      showSnackBar(
        context: context,
        content: 'No hay conexión con el servidor de pagos. Algunas funciones pueden no estar disponibles.',
      );
    }
  }

  Future<void> _addFunds() async {
    // Esta función mantiene la lógica original
    if (_amountController.text.isEmpty) {
      logWarning('WalletScreen', 'Monto vacío');
      showSnackBar(context: context, content: 'Por favor ingresa un monto');
      return;
    }

    double amount;
    try {
      amount = double.parse(_amountController.text.replaceAll(',', '.'));
      logInfo('WalletScreen', 'Monto a añadir: $amount');
      
      if (amount <= 0) {
        logWarning('WalletScreen', 'Monto inválido: $amount');
        showSnackBar(context: context, content: 'El monto debe ser mayor a 0');
        return;
      }
    } catch (e) {
      logError('WalletScreen', 'Error al convertir monto', e);
      showSnackBar(context: context, content: 'Monto inválido');
      return;
    }

    setState(() {
      _isAddingFunds = true;
    });

    try {
      logInfo('WalletScreen', 'Añadiendo fondos...');
      
      final success = await ref.read(walletControllerProvider.notifier).addFunds(
        amount,
        context,
      );
      
      logInfo('WalletScreen', 'Resultado de addFunds: $success');

      if (success && mounted) {
        logInfo('WalletScreen', 'Fondos añadidos correctamente');
        _amountController.clear();
        showSnackBar(
          context: context,
          content: 'Fondos añadidos correctamente',
        );
      }
    } catch (e) {
      logError('WalletScreen', 'Error en _addFunds', e);
      if (mounted) {
        showSnackBar(
          context: context,
          content: 'Error al añadir fondos: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAddingFunds = false;
        });
      }
    }
  }

  Future<void> _syncPendingData() async {
    // Esta función mantiene la lógica original
    setState(() {
      _isSyncing = true;
    });

    try {
      logInfo('WalletScreen', 'Sincronizando datos pendientes...');
      
      final success = await ref.read(walletControllerProvider.notifier).syncPendingData(context);
      
      logInfo('WalletScreen', 'Resultado de sincronización: $success');
      
      setState(() {
        _isLoadingTransactions = true;
      });
      
      await Future.delayed(const Duration(seconds: 1));
      
      setState(() {
        _isLoadingTransactions = false;
      });
      
    } catch (e) {
      logError('WalletScreen', 'Error en _syncPendingData', e);
      if (mounted) {
        showSnackBar(
          context: context,
          content: 'Error al sincronizar datos: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  void _navigateToKYC() {
    logInfo('WalletScreen', 'Navegando a pantalla KYC');
    Navigator.pushNamed(context, '/kyc');
  }
  
  void _navigateToWithdraw() {
    logInfo('WalletScreen', 'Navegando a pantalla de retiro de fondos');
    Navigator.pushNamed(context, '/withdraw');
  }
  
  void _navigateToDebug() {
    logInfo('WalletScreen', 'Navegando a pantalla de diagnóstico');
    Navigator.pushNamed(context, '/debug');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(
        title: const Text(
          'Mi Billetera', 
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          )
        ),
        backgroundColor: Color(0xFF1A1A1A),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _isSyncing ? null : _syncPendingData,
            tooltip: 'Sincronizar',
          ),
          IconButton(
            icon: const Icon(Icons.bug_report, color: Colors.white),
            onPressed: _navigateToDebug,
            tooltip: 'Diagnóstico',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF121212),
          image: DecorationImage(
            image: AssetImage('assets/images/chat_bg.png'),
            fit: BoxFit.cover,
            opacity: 0.03,
          ),
        ),
        child: ref.watch(walletControllerProvider).when(
          data: (wallet) {
            if (wallet == null) {
              logWarning('WalletScreen', 'No hay wallet disponible');
              return const Center(
                child: Text(
                  'No se pudo cargar la información de la billetera',
                  style: TextStyle(color: Colors.white),
                ),
              );
            }

            logInfo('WalletScreen', 'Estado KYC: ${wallet.kycStatus}');
            logInfo('WalletScreen', 'Balance: ${wallet.balance}');
            
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tarjeta de saldo
                  Container(
                    decoration: BoxDecoration(
                      color: Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Saldo Disponible',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '€${wallet.balance.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3E63A8),
                          ),
                        ),
                        if (wallet.pendingSyncWithRapyd) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.sync, size: 16, color: Colors.orange[700]),
                              const SizedBox(width: 4),
                              Text(
                                'Sincronización pendiente',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange[700],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Estado de KYC
                  if (!wallet.kycCompleted)
                    Container(
                      decoration: BoxDecoration(
                        color: Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber, width: 1),
                      ),
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.amber),
                              SizedBox(width: 8),
                              Text(
                                'Verificación Pendiente',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Para enviar y recibir pagos, necesitas completar la verificación de identidad.',
                            style: TextStyle(color: Colors.grey[300]),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _navigateToKYC,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF3E63A8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                            ),
                            child: const Text(
                              'Completar Verificación', 
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Añadir fondos (solo si KYC está completo)
                  if (wallet.kycCompleted) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Icon(Icons.add_circle_outline, color: Color(0xFF3E63A8)),
                        SizedBox(width: 8),
                        Text(
                          'Añadir Fondos',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Color(0xFF333333)),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Monto (EUR)',
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.euro, color: Colors.grey[400]),
                          hintText: '0.00',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isAddingFunds ? null : _addFunds,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF3E63A8),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: _isAddingFunds
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2, 
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Añadir Fondos',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: wallet.balance > 0 ? _navigateToWithdraw : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF1E1E1E),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Retirar',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Historial de transacciones
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.history, color: Color(0xFF3E63A8)),
                          SizedBox(width: 8),
                          Text(
                            'Historial de Transacciones',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      if (_isSyncing)
                        const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF3E63A8),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Historial de pagos con FutureBuilder (mantiene la lógica original)
                  FutureBuilder<List<WalletTransaction>>(
                    future: ref.read(walletControllerProvider.notifier).getPaymentsHistory(),
                    builder: (context, snapshot) {
                      if (_isLoadingTransactions || snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(
                              color: Color(0xFF3E63A8),
                            ),
                          ),
                        );
                      }
                      
                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'Error al cargar transacciones: ${snapshot.error}',
                              style: TextStyle(color: Colors.red[300]),
                            ),
                          ),
                        );
                      }
                      
                      final transactions = snapshot.data ?? [];
                      
                      if (transactions.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.account_balance_wallet_outlined,
                                  size: 60,
                                  color: Colors.grey[700],
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No hay transacciones recientes',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: transactions.length,
                        itemBuilder: (context, index) {
                          final tx = transactions[index];
                          final isIncoming = tx.amount > 0;
                          
                          // Personalizar color y mensaje según el estado si está disponible
                          Color statusColor = isIncoming ? Colors.green : Colors.red;
                          IconData statusIcon = isIncoming ? Icons.arrow_downward : Icons.arrow_upward;
                          
                          if (tx.status == 'pending') {
                            statusColor = Colors.orange;
                            statusIcon = Icons.hourglass_empty;
                          } else if (tx.status == 'failed') {
                            statusColor = Colors.red;
                            statusIcon = Icons.error_outline;
                          }
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: statusColor.withOpacity(0.2),
                                child: Icon(
                                  statusIcon,
                                  color: statusColor,
                                ),
                              ),
                              title: Text(
                                tx.description ?? (isIncoming
                                    ? 'Recibido de ${tx.senderId}'
                                    : 'Enviado a ${tx.receiverId}'),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DateFormat('dd/MM/yyyy HH:mm').format(tx.timestamp),
                                    style: TextStyle(color: Colors.grey[400]),
                                  ),
                                  if (tx.status == 'pending')
                                    const Text(
                                      'Pendiente',
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    )
                                  else if (tx.status == 'failed')
                                    const Text(
                                      'Fallido',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Text(
                                '${isIncoming ? '+' : '-'}€${tx.amount.abs().toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF3E63A8),
            ),
          ),
          error: (error, stack) {
            logError('WalletScreen', 'Error en WalletScreen', error, stack);
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error: $error',
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _navigateToDebug,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF3E63A8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Ver Diagnóstico',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}