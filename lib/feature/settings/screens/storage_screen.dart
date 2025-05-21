import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mk_mesenger/common/utils/colors.dart';

class StorageScreen extends ConsumerStatefulWidget {
  static const String routeName = '/storage';

  const StorageScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends ConsumerState<StorageScreen> {
  bool _isLoading = false;
  bool _autoDownloadMedia = true;
  bool _autoDownloadDocuments = false;
  String _networkType = 'wifi';
  
  // Datos simulados de uso de almacenamiento
  final Map<String, dynamic> _storageData = {
    'total': 2.5, // GB
    'categories': [
      {
        'name': 'Imágenes',
        'size': 850, // MB
        'count': 1240,
        'icon': Icons.image,
        'color': Colors.green,
      },
      {
        'name': 'Videos',
        'size': 1200, // MB
        'count': 85,
        'icon': Icons.videocam,
        'color': Colors.red,
      },
      {
        'name': 'Documentos',
        'size': 320, // MB
        'count': 156,
        'icon': Icons.insert_drive_file,
        'color': Colors.blue,
      },
      {
        'name': 'Audio',
        'size': 130, // MB
        'count': 210,
        'icon': Icons.audiotrack,
        'color': Colors.orange,
      },
    ],
  };

  void _clearCache() {
    setState(() {
      _isLoading = true;
    });

    // Simulación de limpieza
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Caché limpiada correctamente'),
          backgroundColor: accentColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Calcular el total de almacenamiento usado
    double totalUsed = 0;
    for (var category in _storageData['categories']) {
      totalUsed += category['size'];
    }
    
    // Convertir a GB para mostrar
    final totalUsedGB = totalUsed / 1024;
    
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        title: const Text(
          'Almacenamiento y datos',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Resumen de almacenamiento
                  _buildSettingsSection(
                    title: 'Uso de almacenamiento',
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            // Gráfico circular de uso
                            SizedBox(
                              height: 180,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Aquí iría un gráfico circular real
                                  // Por ahora, usamos un CircularProgressIndicator como placeholder
                                  SizedBox(
                                    width: 150,
                                    height: 150,
                                    child: CircularProgressIndicator(
                                      value: totalUsedGB / _storageData['total'],
                                      strokeWidth: 12,
                                      backgroundColor: Colors.grey[800],
                                      valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${totalUsedGB.toStringAsFixed(1)} GB',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                        ),
                                      ),
                                      Text(
                                        'de ${_storageData['total']} GB',
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Lista de categorías
                            ...List.generate(
                              _storageData['categories'].length,
                              (index) => _buildStorageItem(
                                _storageData['categories'][index],
                                totalUsed,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Sección de descarga automática
                  _buildSettingsSection(
                    title: 'Descarga automática',
                    children: [
                      SwitchListTile(
                        title: const Text(
                          'Descargar archivos multimedia',
                          style: TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          'Descargar automáticamente fotos y videos',
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        ),
                        value: _autoDownloadMedia,
                        activeColor: accentColor,
                        onChanged: (value) {
                          setState(() {
                            _autoDownloadMedia = value;
                          });
                        },
                      ),
                      SwitchListTile(
                        title: const Text(
                          'Descargar documentos',
                          style: TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          'Descargar automáticamente documentos y archivos',
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        ),
                        value: _autoDownloadDocuments,
                        activeColor: accentColor,
                        onChanged: (value) {
                          setState(() {
                            _autoDownloadDocuments = value;
                          });
                        },
                      ),
                      const Divider(color: Colors.grey),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tipo de red para descarga automática',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildNetworkTypeOption(
                              title: 'Solo Wi-Fi',
                              value: 'wifi',
                              icon: Icons.wifi,
                            ),
                            const SizedBox(height: 8),
                            _buildNetworkTypeOption(
                              title: 'Wi-Fi y datos móviles',
                              value: 'all',
                              icon: Icons.network_cell,
                            ),
                            const SizedBox(height: 8),
                            _buildNetworkTypeOption(
                              title: 'Nunca',
                              value: 'none',
                              icon: Icons.do_not_disturb,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Sección de limpieza
                  _buildSettingsSection(
                    title: 'Limpieza de almacenamiento',
                    children: [
                      ListTile(
                        title: const Text(
                          'Limpiar caché',
                          style: TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          'Liberar espacio eliminando archivos temporales',
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        ),
                        trailing: Text(
                          '45 MB',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                        onTap: _clearCache,
                      ),
                      ListTile(
                        title: const Text(
                          'Administrar almacenamiento',
                          style: TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          'Revisar y eliminar archivos por chat',
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.grey[600],
                          size: 16,
                        ),
                        onTap: () {
                          // Implementar administración de almacenamiento
                        },
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          
          // Overlay de carga
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.7),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: accentColor,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Limpiando caché...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: accentColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildStorageItem(Map<String, dynamic> item, double total) {
    final percentage = (item['size'] / total) * 100;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: item['color'].withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  item['icon'],
                  color: item['color'],
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${item['count']} archivos',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    item['size'] >= 1024
                        ? '${(item['size'] / 1024).toStringAsFixed(1)} GB'
                        : '${item['size']} MB',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: item['size'] / total,
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation<Color>(item['color']),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkTypeOption({
    required String title,
    required String value,
    required IconData icon,
  }) {
    final isSelected = _networkType == value;
    
    return InkWell(
      onTap: () {
        setState(() {
          _networkType = value;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withOpacity(0.2) : inputBackgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? accentColor : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? accentColor.withOpacity(0.3) : Colors.grey[800],
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? accentColor : Colors.grey[400],
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
