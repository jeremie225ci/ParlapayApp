import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mk_mesenger/common/models/status_model.dart';
import 'package:mk_mesenger/common/utils/colors.dart';
import 'package:mk_mesenger/common/utils/utils.dart';
import 'package:mk_mesenger/feature/status/controller/status_controller.dart';
import 'package:mk_mesenger/feature/status/repository/status_repository.dart';
import 'package:mk_mesenger/feature/status/screens/status_screen.dart';

class StatusContactsScreen extends ConsumerStatefulWidget {
  const StatusContactsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<StatusContactsScreen> createState() => _StatusContactsScreenState();
}

class _StatusContactsScreenState extends ConsumerState<StatusContactsScreen> with WidgetsBindingObserver {
  List<Status> allStatuses = [];
  bool isLoading = true;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStatuses();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Recargar estados cuando la app vuelve a primer plano
    if (state == AppLifecycleState.resumed) {
      _loadStatuses();
    }
  }
  
  Future<void> _loadStatuses() async {
    setState(() {
      isLoading = true;
    });
    
    // Debug: Limpiar estados expirados primero
    await ref.read(statusControllerProvider).cleanExpiredStatuses();
    
    // Obtener estados
    final statuses = await ref.read(statusControllerProvider).getStatus(context);
    
    if (mounted) {
      setState(() {
        allStatuses = statuses;
        isLoading = false;
      });
      
      // Debug: Mostrar información sobre los estados cargados
      debugPrint('Estados cargados: ${allStatuses.length}');
      for (var status in allStatuses) {
        debugPrint('Estado de ${status.username} (${status.uid}) con ${status.media.length} medios');
      }
    }
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadStatuses,
      color: accentColor,
      backgroundColor: Colors.black,
      child: Scaffold(
        backgroundColor: Color(0xFF121212),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Estados en burbujas al estilo WhatsApp
                  _buildStatusCircles(),
                  
                  const SizedBox(height: 16),
                  
                  // Lista vertical de estados
                  Expanded(
                    child: _buildStatusList(),
                  ),
                ],
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            // Mostrar opciones para elegir tipo de medio
            final result = await showMediaPickerDialog(context);
            
            if (result != null && result['file'] != null && mounted) {
              Navigator.pushNamed(
                context,
                '/confirm-status',
                arguments: {
                  'file': result['file'], 
                  'isVideo': result['isVideo'],
                },
              ).then((_) => _loadStatuses());
            }
          },
          backgroundColor: Color(0xFF3E63A8),
          child: const Icon(
            Icons.camera_alt,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
  
  // Burbujas de estados al estilo WhatsApp en la parte superior
  Widget _buildStatusCircles() {
    if (allStatuses.isEmpty) {
      return _buildEmptyStatusCircles();
    }
    
    return Container(
      height: 110,
      margin: const EdgeInsets.only(top: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: allStatuses.length,
        itemBuilder: (context, index) {
          Status status = allStatuses[index];
          
          // El primer ítem siempre será "Mi estado"
          if (index == 0 && status.uid == ref.read(statusRepositoryProvider).auth.currentUser!.uid) {
            return _buildMyStatusCircle(status);
          }
          
          return _buildStatusCircle(status);
        },
      ),
    );
  }
  
  Widget _buildEmptyStatusCircles() {
    return Container(
      height: 110,
      margin: const EdgeInsets.only(top: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _buildMyStatusCircle(null),
        ],
      ),
    );
  }
  
  Widget _buildMyStatusCircle(Status? myStatus) {
    bool hasStatus = myStatus != null && myStatus.media.isNotEmpty;
    
    return GestureDetector(
      onTap: () async {
        if (hasStatus) {
          // Ver mi propio estado
          final allUpdates = await ref.read(statusControllerProvider).getAllStatusUpdates(context);
          if (mounted) {
            Navigator.pushNamed(
              context,
              StatusScreen.routeName,
              arguments: {
                'status': myStatus,
                'allStatuses': allUpdates,
              },
            ).then((_) => _loadStatuses());
          }
        } else {
          // Crear nuevo estado
          final result = await showMediaPickerDialog(context);
          
          if (result != null && result['file'] != null && mounted) {
            Navigator.pushNamed(
              context,
              '/confirm-status',
              arguments: {
                'file': result['file'], 
                'isVideo': result['isVideo'],
              },
            ).then((_) => _loadStatuses());
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  height: 68,
                  width: 68,
                  padding: hasStatus ? const EdgeInsets.all(2) : EdgeInsets.zero,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: hasStatus
                        ? Border.all(
                            color: Color(0xFF3E63A8),
                            width: 2,
                          )
                        : null,
                  ),
                  child: CircleAvatar(
                    backgroundColor: Color.fromARGB(51, 62, 99, 168), // 20% de opacidad
                    radius: 32,
                    backgroundImage: hasStatus && myStatus!.profilePic.isNotEmpty
                        ? NetworkImage(myStatus.profilePic)
                        : null,
                    child: !hasStatus
                        ? const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 40,
                          )
                        : null,
                  ),
                ),
                if (!hasStatus)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3E63A8),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF121212),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                if (hasStatus && myStatus!.isLastVideo)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Mi estado',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (hasStatus)
              Text(
                _getTimeAgo(myStatus!.updatedAt),
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 10,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCircle(Status status) {
    return GestureDetector(
      onTap: () async {
        // Ver el estado
        final allUpdates = await ref.read(statusControllerProvider).getAllStatusUpdates(context);
        
        if (mounted) {
          Navigator.pushNamed(
            context,
            StatusScreen.routeName,
            arguments: {
              'status': status,
              'allStatuses': allUpdates,
            },
          ).then((_) => _loadStatuses());
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  height: 68,
                  width: 68,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Color(0xFF3E63A8),
                      width: 2,
                    ),
                  ),
                  child: status.profilePic.isNotEmpty
                      ? CircleAvatar(
                          backgroundImage: NetworkImage(status.profilePic),
                          radius: 32,
                        )
                      : CircleAvatar(
                          backgroundColor: Color.fromARGB(51, 62, 99, 168),
                          radius: 32,
                          child: Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                ),
                if (status.isLastVideo)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              status.username.length > 8 
                  ? '${status.username.substring(0, 8)}...' 
                  : status.username,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              _getTimeAgo(status.updatedAt),
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Lista vertical de estados
  Widget _buildStatusList() {
    if (allStatuses.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_camera_outlined,
              size: 70,
              color: Colors.grey[700],
            ),
            const SizedBox(height: 16),
            Text(
              'No hay estados recientes',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tus contactos aún no han compartido estados',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }
    
    // Filtrar el estado propio de la lista vertical
    List<Status> filteredStatuses = allStatuses
        .where((status) => status.uid != ref.read(statusRepositoryProvider).auth.currentUser!.uid)
        .toList();
    
    if (filteredStatuses.isEmpty) {
      // Solo tengo mi propio estado y no hay otros
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16.0, bottom: 16.0),
              child: Text(
                'Estados recientes',
                style: TextStyle(
                  color: Color(0xFF3E63A8),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'No hay otros estados recientes',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tus contactos aún no han compartido estados',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    // Hay estados de otros usuarios
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 32.0, bottom: 16.0),
          child: Text(
            'Estados recientes',
            style: TextStyle(
              color: Color(0xFF3E63A8),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filteredStatuses.length,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemBuilder: (context, index) {
              var statusData = filteredStatuses[index];
              return _buildStatusTile(statusData);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatusTile(Status status) {
    return InkWell(
      onTap: () async {
        // Ver el estado
        final allUpdates = await ref.read(statusControllerProvider).getAllStatusUpdates(context);
        
        if (mounted) {
          Navigator.pushNamed(
            context,
            StatusScreen.routeName,
            arguments: {
              'status': status,
              'allStatuses': allUpdates,
            },
          ).then((_) => _loadStatuses());
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Color(0xFF3E63A8),
                  width: 2,
                ),
              ),
              child: status.profilePic.isNotEmpty
                  ? CircleAvatar(
                      backgroundImage: NetworkImage(status.profilePic),
                      radius: 26,
                    )
                  : CircleAvatar(
                      backgroundColor: Color.fromARGB(51, 62, 99, 168),
                      radius: 26,
                      child: Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status.username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Hace ${_getTimeAgo(status.updatedAt)}',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                      if (status.media.length > 1)
                        Text(
                          ' · ${status.media.length} actualizaciones',
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
            Stack(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Color.fromARGB(51, 62, 99, 168),
                    image: status.thumbnailUrl.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(status.thumbnailUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: status.thumbnailUrl.isEmpty
                      ? Icon(
                          Icons.image_not_supported,
                          color: Colors.white,
                          size: 20,
                        )
                      : null,
                ),
                if (status.isLastVideo)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    
    if (difference.inSeconds < 60) {
      return '${difference.inSeconds} seg';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} h';
    } else {
      return '${difference.inDays} d';
    }
  }
 

void showSnackBar({required BuildContext context, required String content}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(content)),
  );
}

Future<File?> pickImageFromGallery(BuildContext context) async {
  File? image;
  try {
    final pickedImage = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedImage != null) {
      image = File(pickedImage.path);
    }
  } catch (e) {
    showSnackBar(context: context, content: e.toString());
  }
  return image;
}

Future<File?> pickVideoFromGallery(BuildContext context) async {
  File? video;
  try {
    final pickedVideo = await ImagePicker().pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 30),
    );

    if (pickedVideo != null) {
      video = File(pickedVideo.path);
    }
  } catch (e) {
    showSnackBar(context: context, content: e.toString());
  }
  return video;
}

Future<File?> pickCameraImage(BuildContext context) async {
  File? image;
  try {
    final pickedImage = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );

    if (pickedImage != null) {
      image = File(pickedImage.path);
    }
  } catch (e) {
    showSnackBar(context: context, content: e.toString());
  }
  return image;
}

Future<File?> pickCameraVideo(BuildContext context) async {
  File? video;
  try {
    final pickedVideo = await ImagePicker().pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(seconds: 30),
    );

    if (pickedVideo != null) {
      video = File(pickedVideo.path);
    }
  } catch (e) {
    showSnackBar(context: context, content: e.toString());
  }
  return video;
}

// Función para mostrar diálogo de selección de medios
Future<Map<String, dynamic>?> showMediaPickerDialog(BuildContext context) async {
  return await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: Color(0xFF2A2A2A),
        title: Text(
          'Añadir a tu estado',
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_library, color: Colors.blue),
                title: Text('Imagen de galería', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  File? file = await pickImageFromGallery(context);
                  if (file != null && context.mounted) {
                    Navigator.of(context).pop({
                      'file': file,
                      'isVideo': false,
                    });
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.video_library, color: Colors.red),
                title: Text('Video de galería', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  File? file = await pickVideoFromGallery(context);
                  if (file != null && context.mounted) {
                    Navigator.of(context).pop({
                      'file': file,
                      'isVideo': true,
                    });
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt, color: Colors.green),
                title: Text('Tomar foto', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  File? file = await pickCameraImage(context);
                  if (file != null && context.mounted) {
                    Navigator.of(context).pop({
                      'file': file,
                      'isVideo': false,
                    });
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.videocam, color: Colors.amber),
                title: Text('Grabar video', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  File? file = await pickCameraVideo(context);
                  if (file != null && context.mounted) {
                    Navigator.of(context).pop({
                      'file': file,
                      'isVideo': true,
                    });
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: Text('Cancelar', style: TextStyle(color: Colors.grey)),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}
}