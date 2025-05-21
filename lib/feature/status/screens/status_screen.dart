import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:story_view/story_view.dart';
import 'package:mk_mesenger/common/models/status_model.dart';
import 'package:mk_mesenger/common/utils/colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mk_mesenger/feature/status/controller/status_controller.dart';

class StatusScreen extends ConsumerStatefulWidget {
  static const String routeName = '/status-screen';
  final Status status;
  final List<Status> allStatuses; // Lista de todos los estados para navegación

  const StatusScreen({
    Key? key,
    required this.status,
    this.allStatuses = const [],
  }) : super(key: key);

  @override
  ConsumerState<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends ConsumerState<StatusScreen> with WidgetsBindingObserver {
  final StoryController controller = StoryController();
  late List<StoryItem> storyItems;
  int currentStatusIndex = 0;
  String currentUserId = '';
  bool isOwnStatus = false;
  bool hasResponded = false;
  List<dynamic> viewers = [];
  
  // Para la siguiente historia
  int currentUserIndex = 0;
  
  // Controlador para el campo de texto de respuesta
  final TextEditingController messageController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    isOwnStatus = widget.status.uid == currentUserId;
    
    // Encontrar el índice del usuario actual en la lista de todos los estados
    if (widget.allStatuses.isNotEmpty) {
      currentUserIndex = widget.allStatuses.indexWhere((s) => s.statusId == widget.status.statusId);
      if (currentUserIndex < 0) currentUserIndex = 0;
    }
    
    initStoryPageItems();
    
    // Cargar viewers inmediatamente para todos los estados
    _loadViewers();
    
    // Registrar vista (si no es mi propio estado)
    if (!isOwnStatus) {
      _registerView();
    }
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pausar videos cuando la app está en segundo plano
    if (state == AppLifecycleState.paused) {
      controller.pause();
    }
  }

  void initStoryPageItems() {
    storyItems = [];
    
    for (var media in widget.status.media) {
      if (media.type == MediaType.video) {
        // Crear un StoryItem para video
        storyItems.add(
          StoryItem.pageVideo(
            media.url,
            caption: media.caption.isNotEmpty 
                ? Text(
                    media.caption,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 2,
                          color: Colors.black,
                        ),
                      ],
                    ),
                  )
                : null,
            controller: controller,
          ),
        );
      } else {
        // Crear un StoryItem para imagen
        storyItems.add(
          StoryItem.pageImage(
            url: media.url,
            controller: controller,
            caption: media.caption.isNotEmpty 
                ? Text(
                    media.caption,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 2,
                          color: Colors.black,
                        ),
                      ],
                    ),
                  )
                : null,
          ),
        );
      }
    }
  }
  
  Future<void> _registerView() async {
    if (isOwnStatus) return; // No registrar vista si es mi propio estado
    
    try {
      // Usar el controlador para registrar la vista
      await ref.read(statusControllerProvider).registerStatusView(widget.status.statusId);
      debugPrint('Vista registrada para el estado: ${widget.status.statusId}');
    } catch (e) {
      debugPrint('Error al registrar vista: $e');
    }
  }
  
  Future<void> _loadViewers() async {
    try {
      final statusDoc = await FirebaseFirestore.instance
          .collection('status')
          .doc(widget.status.statusId)
          .get();
        
    if (statusDoc.exists && statusDoc.data() != null) {
      if (mounted) {
        setState(() {
          viewers = statusDoc.data()!['viewers'] ?? [];
          debugPrint('Cargados ${viewers.length} viewers para el estado ${widget.status.statusId}');
        });
      }
    }
  } catch (e) {
    debugPrint('Error al cargar viewers: $e');
  }
}
  
  void _sendResponse(String response) async {
    if (response.trim().isEmpty) return;
    
    try {
      // Enviar respuesta
      final statusCreatorId = widget.status.uid;
      
      // Aquí deberías enviar un mensaje al creador del estado
      // usando tu sistema de mensajería existente
      
      setState(() {
        hasResponded = true;
      });
      
      // Detener la reproducción
      controller.pause();
      
      // Mostrar confirmación
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Respuesta enviada')),
        );
      
        // Cerrar la pantalla después de un breve retraso
        Future.delayed(Duration(seconds: 1), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      }
    } catch (e) {
      debugPrint('Error al enviar respuesta: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar: $e')),
        );
      }
    }
  }
  
  void _navigateToNextStatus() {
    if (widget.allStatuses.isEmpty || currentUserIndex >= widget.allStatuses.length - 1) {
      // No hay más estados, cerrar la pantalla
      Navigator.pop(context);
      return;
    }
    
    // Navegar al siguiente estado
    final nextStatus = widget.allStatuses[currentUserIndex + 1];
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => StatusScreen(
            status: nextStatus,
            allStatuses: widget.allStatuses,
          ),
        ),
      );
    }
  }
  
  void _showViewers() {
    if (!isOwnStatus || viewers.isEmpty) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Visto por ${viewers.length}',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: viewers.length,
                itemBuilder: (context, index) {
                  final viewer = viewers[index];
                  return FutureBuilder(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(viewer['uid'])
                        .get(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.grey[800],
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          title: Text(
                            'Cargando...',
                            style: TextStyle(color: Colors.white),
                          ),
                        );
                      }
                      
                      final userData = snapshot.data!.data() as Map<String, dynamic>?;
                      final userName = userData?['name'] ?? 'Usuario';
                      final profilePic = userData?['profilePic'] ?? '';
                      
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: profilePic.isNotEmpty 
                              ? NetworkImage(profilePic)
                              : null,
                          backgroundColor: Colors.grey[800],
                          child: profilePic.isEmpty
                              ? Icon(Icons.person, color: Colors.white)
                              : null,
                        ),
                        title: Text(
                          userName,
                          style: TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          _getTimeAgo(DateTime.fromMillisecondsSinceEpoch(viewer['timestamp'])),
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Story view
          storyItems.isEmpty
              ? Center(
                  child: Text(
                    'No hay contenido disponible',
                    style: TextStyle(color: Colors.white),
                  ),
                )
              : StoryView(
                  storyItems: storyItems,
                  controller: controller,
                  onVerticalSwipeComplete: (direction) {
                    if (direction == Direction.down) {
                      Navigator.pop(context);
                    }
                  },
                  onComplete: () {
                    _navigateToNextStatus();
                  },
                  progressPosition: ProgressPosition.top,
                  repeat: false,
                  inline: false,
                ),
          
          // Header info
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: accentColor,
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      backgroundImage: widget.status.profilePic.isNotEmpty
                          ? NetworkImage(widget.status.profilePic)
                          : null,
                      backgroundColor: Colors.grey[800],
                      radius: 20,
                      child: widget.status.profilePic.isEmpty
                          ? Icon(Icons.person, color: Colors.white)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.status.username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                offset: Offset(0, 1),
                                blurRadius: 3,
                                color: Colors.black,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _getTimeAgo(widget.status.updatedAt),
                          style: TextStyle(
                            color: Colors.white.withAlpha(204), // 0.8 * 255 = 204
                            fontSize: 12,
                            shadows: const [
                              Shadow(
                                offset: Offset(0, 1),
                                blurRadius: 2,
                                color: Colors.black,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Mostrar conteo de vistas solo para estado propio
                  if (isOwnStatus)
                    GestureDetector(
                      onTap: _showViewers,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.remove_red_eye,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              viewers.length.toString(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(
                      Icons.more_vert,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      // Opciones adicionales
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Color(0xFF1A1A1A),
                        builder: (context) => Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isOwnStatus)
                              ListTile(
                                leading: Icon(Icons.delete, color: Colors.red),
                                title: Text(
                                  'Eliminar estado',
                                  style: TextStyle(color: Colors.white),
                                ),
                                onTap: () {
                                  // Implementar eliminación de estado
                                  Navigator.pop(context);
                                  Navigator.pop(context);
                                },
                              ),
                            if (!isOwnStatus)
                              ListTile(
                                leading: Icon(Icons.report, color: Colors.amber),
                                title: Text(
                                  'Reportar estado',
                                  style: TextStyle(color: Colors.white),
                                ),
                                onTap: () {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Estado reportado')),
                                  );
                                },
                              ),
                            ListTile(
                              leading: Icon(Icons.close, color: Colors.white),
                              title: Text(
                                'Cerrar',
                                style: TextStyle(color: Colors.white),
                              ),
                              onTap: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          
          // Reply input at bottom (solo mostrar si no es mi propio estado)
          if (!isOwnStatus && !hasResponded)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Color.fromARGB(178, 0, 0, 0), // 0.7 * 255 = 178
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Color.fromARGB(51, 255, 255, 255), // 0.2 * 255 = 51
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: messageController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Responder a ${widget.status.username}...',
                            hintStyle: TextStyle(
                              color: Color.fromARGB(178, 255, 255, 255), // 0.7 * 255 = 178
                            ),
                            border: InputBorder.none,
                          ),
                          onSubmitted: _sendResponse,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        // Implementar reacción
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Color.fromARGB(51, 255, 255, 255), // 0.2 * 255 = 51
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.favorite,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        // Usar el TextEditingController para obtener el texto
                        final text = messageController.text.trim();
                        if (text.isNotEmpty) {
                          _sendResponse(text);
                          messageController.clear();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: accentColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.send,
                          color: Colors.white,
                          size: 20,
                        ),
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

  String _getTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    
    if (difference.inSeconds < 60) {
      return 'Hace ${difference.inSeconds} segundos';
    } else if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes} minutos';
    } else if (difference.inHours < 24) {
      return 'Hace ${difference.inHours} horas';
    } else {
      return 'Hace ${difference.inDays} días';
    }
  }

  @override
  void dispose() {
    controller.dispose();
    messageController.dispose(); // Liberar el controller de texto
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
