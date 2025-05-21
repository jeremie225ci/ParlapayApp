import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mk_mesenger/common/utils/logger.dart';
import 'package:mk_mesenger/feature/wallet/controller/wallet_controller.dart';
import 'package:mk_mesenger/services/rapyd_service.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:mk_mesenger/restart_wigdet.dart';

class DebugScreen extends ConsumerStatefulWidget {
  static const String routeName = '/debug';

  const DebugScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends ConsumerState<DebugScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _logs = [];
  bool _isServerConnected = false;
  bool _isCheckingConnection = false;
  String _serverStatus = 'No verificado';
  Map<String, dynamic> _walletData = {};
  bool _isExportingLogs = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadLogs();
    _checkServerConnection();
    _loadWalletData();
    
    logInfo('DebugScreen', 'Pantalla de diagnóstico inicializada');
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  void _loadLogs() {
    setState(() {
      _logs.clear();
      _logs.addAll(AppLogger().getRecentLogs(200));
    });
    
    logInfo('DebugScreen', 'Logs cargados: ${_logs.length}');
  }
  
  Future<void> _checkServerConnection() async {
    if (_isCheckingConnection) return;
    
    setState(() {
      _isCheckingConnection = true;
      _serverStatus = 'Verificando...';
    });
    
    try {
      final rapydService = RapydService();
      final isConnected = await rapydService.testConnection();
      
      setState(() {
        _isServerConnected = isConnected;
        _serverStatus = isConnected ? 'Conectado ✅' : 'Sin conexión ❌';
      });
      
      logInfo('DebugScreen', 'Estado de conexión con el servidor: $isConnected');
    } catch (e) {
      setState(() {
        _isServerConnected = false;
        _serverStatus = 'Error: $e';
      });
      
      logError('DebugScreen', 'Error al verificar conexión', e);
    } finally {
      setState(() {
        _isCheckingConnection = false;
      });
    }
  }
  
  Future<void> _loadWalletData() async {
    try {
      final walletState = ref.read(walletControllerProvider);
      
      walletState.whenData((wallet) {
        if (wallet != null) {
          setState(() {
            _walletData = wallet.toMap();
          });
          
          logInfo('DebugScreen', 'Datos de wallet cargados: ${wallet.toMap()}');
        } else {
          logWarning('DebugScreen', 'No se encontró wallet');
        }
      });
    } catch (e) {
      logError('DebugScreen', 'Error al cargar datos de wallet', e);
    }
  }
  
  Future<void> _exportLogs() async {
    if (_isExportingLogs) return;
    
    setState(() {
      _isExportingLogs = true;
    });
    
    try {
      final jsonData = await AppLogger().exportLogsToJson();
      
      // Guardar en archivo temporal
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${directory.path}/parlapay_logs_$timestamp.json';
      final file = File(path);
      await file.writeAsString(jsonData);
      
      // Compartir archivo usando un método seguro
      final result = await Share.shareXFiles(
        [XFile(path)],
        text: 'Logs de ParlaPay',
      );
      
      logInfo('DebugScreen', 'Logs exportados y compartidos: $result');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logs exportados correctamente')),
        );
      }
    } catch (e) {
      logError('DebugScreen', 'Error al exportar logs', e);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar logs: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExportingLogs = false;
        });
      }
    }
  }
  
  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copiado al portapapeles')),
      );
    }
    
    logInfo('DebugScreen', 'Texto copiado al portapapeles');
  }
  
  void _restartApp() {
    logInfo('DebugScreen', 'Reiniciando aplicación...');
    RestartWidget.restartApp(context);
  }
  
  Future<void> _clearLogs() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpiar logs'),
        content: const Text('¿Estás seguro de que quieres limpiar los logs? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              AppLogger().clearLogs();
              _loadLogs();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logs limpiados correctamente')),
              );
            },
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );
  }
  
  // Método seguro para mostrar SnackBar en contexto asíncrono
  void _showSnackBar(String message) {
    if (!mounted) return;
    
    // Usar un Future.microtask para asegurar que estamos en el contexto correcto
    Future.microtask(() {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnóstico'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Logs'),
            Tab(text: 'Conexión'),
            Tab(text: 'Wallet'),
            Tab(text: 'Herramientas'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadLogs();
              _checkServerConnection();
              _loadWalletData();
              
              _showSnackBar('Información actualizada');
            },
          ),
          IconButton(
            icon: _isExportingLogs 
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.share),
            onPressed: _isExportingLogs ? null : _exportLogs,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Pestaña de Logs
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    const Text('Logs recientes:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.copy),
                      label: const Text('Copiar'),
                      onPressed: () => _copyToClipboard(_logs.join('\n')),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.delete),
                      label: const Text('Limpiar'),
                      onPressed: _clearLogs,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _logs.isEmpty
                    ? const Center(child: Text('No hay logs disponibles'))
                    : ListView.builder(
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          final log = _logs[_logs.length - 1 - index]; // Mostrar más recientes primero
                          
                          Color? textColor;
                          if (log.contains('❌') || log.contains('🔴')) {
                            textColor = Colors.red;
                          } else if (log.contains('⚠️')) {
                            textColor = Colors.orange;
                          } else if (log.contains('✅')) {
                            textColor = Colors.green;
                          }
                          
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 8.0),
                            child: Text(
                              log,
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                                color: textColor,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          
          // Resto de pestañas igual que antes...
          // Pestaña de Conexión, Wallet y Herramientas
          // (Omitido por brevedad)
          
          // Pestaña de Conexión
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Estado del Servidor',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Text('Estado:'),
                            const SizedBox(width: 8),
                            Text(
                              _serverStatus,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _isServerConnected ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isCheckingConnection ? null : _checkServerConnection,
                            child: _isCheckingConnection
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Verificar Conexión'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Información de Red',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text('URL del Servidor:'),
                        const SizedBox(height: 4),
                        Text(
                          'https://us-central1-mk-mensenger.cloudfunctions.net/g2',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Pestaña de Wallet
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Datos de Wallet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ..._walletData.entries.map((entry) {
                          // Filtrar campos sensibles o complejos
                          if (entry.key == 'transactions') {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'transactions:',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '[${(entry.value as List?)?.length ?? 0} transacciones]',
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${entry.key}:',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    entry.value?.toString() ?? 'null',
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _copyToClipboard(_walletData.toString()),
                            child: const Text('Copiar Datos'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Estado KYC',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Text('Estado:'),
                            const SizedBox(width: 8),
                            Text(
                              _walletData['kycStatus']?.toString() ?? 'No iniciado',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _walletData['kycCompleted'] == true
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('Completado:'),
                            const SizedBox(width: 8),
                            Text(
                              _walletData['kycCompleted'] == true ? 'Sí' : 'No',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _walletData['kycCompleted'] == true
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Pestaña de Herramientas
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Herramientas de Diagnóstico',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          leading: const Icon(Icons.refresh),
                          title: const Text('Reiniciar Aplicación'),
                          subtitle: const Text('Reinicia la aplicación completamente'),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Reiniciar Aplicación'),
                                content: const Text('¿Estás seguro de que quieres reiniciar la aplicación?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancelar'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _restartApp();
                                    },
                                    child: const Text('Reiniciar'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.delete),
                          title: const Text('Limpiar Logs'),
                          subtitle: const Text('Elimina todos los logs almacenados'),
                          onTap: _clearLogs,
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.share),
                          title: const Text('Exportar Logs'),
                          subtitle: const Text('Comparte los logs para análisis'),
                          onTap: _exportLogs,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Información del Sistema',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text('Versión de la Aplicación:'),
                        const SizedBox(height: 4),
                        Text(
                          '1.0.0 (MangoPay Integration)',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text('Fecha y Hora:'),
                        const SizedBox(height: 4),
                        Text(
                          DateTime.now().toString(),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
