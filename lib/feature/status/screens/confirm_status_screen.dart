import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mk_mesenger/common/models/user_model.dart';
import 'package:mk_mesenger/common/utils/colors.dart';
import 'package:mk_mesenger/feature/status/controller/status_controller.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ConfirmStatusScreen extends ConsumerStatefulWidget {
  static const String routeName = '/confirm-status';
  final Map<String, dynamic> statusData;

  const ConfirmStatusScreen({
    Key? key,
    required this.statusData,
  }) : super(key: key);

  @override
  ConsumerState<ConfirmStatusScreen> createState() => _ConfirmStatusScreenState();
}

class _ConfirmStatusScreenState extends ConsumerState<ConfirmStatusScreen> {
  final TextEditingController captionController = TextEditingController();
  bool isLoading = false;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  
  // Nuevas variables para manejar la visibilidad
  String _visibilityMode = "all"; // "all" o "except"
  List<String> _excludedContacts = [];
  List<UserModel> _allContacts = [];
  bool _loadingContacts = false;

  @override
  void initState() {
    super.initState();
    if (widget.statusData['isVideo']) {
      _videoController = VideoPlayerController.file(widget.statusData['file'])
        ..initialize().then((_) {
          setState(() {
            _isVideoInitialized = true;
          });
          _videoController!.setLooping(true);
          _videoController!.play();
        });
    }
    // Cargar contactos al iniciar
    _loadContacts();
  }

  // Método para cargar contactos
  Future<void> _loadContacts() async {
    setState(() {
      _loadingContacts = true;
    });
    
    try {
      // Obtener contactos del dispositivo
      List<Contact> deviceContacts = [];
      if (await FlutterContacts.requestPermission()) {
        deviceContacts = await FlutterContacts.getContacts(withProperties: true);
      }
      
      // Extraer números de teléfono
      List<String> phoneNumbers = [];
      for (var contact in deviceContacts) {
        if (contact.phones.isNotEmpty) {
          phoneNumbers.add(contact.phones[0].number.replaceAll(' ', ''));
        }
      }
      
      // Obtener usuarios de Firestore que coincidan con los contactos
      final firestore = FirebaseFirestore.instance;
      final querySnapshot = await firestore.collection('users').get();
      
      List<UserModel> contacts = [];
      for (var doc in querySnapshot.docs) {
        UserModel user = UserModel.fromMap(doc.data() as Map<String, dynamic>);
        if (phoneNumbers.contains(user.phoneNumber)) {
          contacts.add(user);
        }
      }
      
      setState(() {
        _allContacts = contacts;
        _loadingContacts = false;
      });
      
      debugPrint('Contactos cargados: ${contacts.length}');
    } catch (e) {
      debugPrint('Error cargando contactos: $e');
      setState(() {
        _loadingContacts = false;
      });
    }
  }

  // Método para mostrar el diálogo de visibilidad
  void _showVisibilityDialog() {
    showDialog(
      context: context,
      builder: (context) => Theme(
        data: ThemeData.dark().copyWith(
          dialogBackgroundColor: const Color(0xFF121212),
        ),
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF121212),
              title: const Text(
                'Visibilidad del estado',
                style: TextStyle(color: Colors.white),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Opción "Todos los contactos"
                    RadioListTile<String>(
                      title: const Text(
                        'Todos los contactos',
                        style: TextStyle(color: Colors.white),
                      ),
                      value: 'all',
                      groupValue: _visibilityMode,
                      onChanged: (value) {
                        setDialogState(() {
                          _visibilityMode = value!;
                        });
                      },
                      activeColor: accentColor,
                    ),
                    // Opción "Mis contactos excepto..."
                    RadioListTile<String>(
                      title: const Text(
                        'Mis contactos excepto...',
                        style: TextStyle(color: Colors.white),
                      ),
                      value: 'except',
                      groupValue: _visibilityMode,
                      onChanged: (value) {
                        setDialogState(() {
                          _visibilityMode = value!;
                        });
                      },
                      activeColor: accentColor,
                    ),
                    
                    if (_visibilityMode == 'except') ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Selecciona los contactos a excluir:',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 8),
                      
                      // Lista de contactos para excluir
                      if (_loadingContacts)
                        const Center(child: CircularProgressIndicator())
                      else if (_allContacts.isEmpty)
                        const Text(
                          'No se encontraron contactos',
                          style: TextStyle(color: Colors.white70),
                        )
                      else
                        SizedBox(
                          height: 200,
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _allContacts.length,
                            itemBuilder: (context, index) {
                              final contact = _allContacts[index];
                              final isExcluded = _excludedContacts.contains(contact.uid);
                              
                              return CheckboxListTile(
                                title: Text(
                                  contact.name,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: Text(
                                  contact.phoneNumber,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                value: isExcluded,
                                onChanged: (value) {
                                  setDialogState(() {
                                    if (value!) {
                                      _excludedContacts.add(contact.uid);
                                    } else {
                                      _excludedContacts.remove(contact.uid);
                                    }
                                  });
                                },
                                activeColor: accentColor,
                              );
                            },
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      // Actualizar el estado local con la selección
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Aplicar'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // Método modificado para añadir estado con la visibilidad seleccionada
  void addStatus() {
    setState(() => isLoading = true);
    
    // Pasar la configuración de visibilidad al controlador
    ref.read(statusControllerProvider).addStatus(
          file: widget.statusData['file'],
          caption: captionController.text,
          context: context,
          isVideo: widget.statusData['isVideo'],
          visibilityMode: _visibilityMode,
          excludedContacts: _excludedContacts,
        );
  }

  @override
  void dispose() {
    captionController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Fondo negro
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        title: const Text(
          'Compartir estado',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Contenido multimedia
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.black,
              ),
              child: widget.statusData['isVideo']
                  ? _buildVideoPreview()
                  : _buildImagePreview(),
            ),
          ),
          
          // Controles inferiores
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título
                const Text(
                  'Añadir una descripción',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Campo de texto para la descripción
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: inputBackgroundColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: inputBorderColor),
                  ),
                  child: TextField(
                    controller: captionController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Escribe algo...',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Botón de visibilidad (modificado para abrir el diálogo)
                InkWell(
                  onTap: _showVisibilityDialog,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: inputBackgroundColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: inputBorderColor),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.visibility,
                          color: Colors.grey[400],
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Visibilidad',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _visibilityMode == 'all' 
                                    ? 'Todos los contactos' 
                                    : 'Mis contactos excepto ${_excludedContacts.length}',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.grey[400],
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Botón de compartir
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : addStatus,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Compartir',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
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

  Widget _buildImagePreview() {
    return Image.file(
      widget.statusData['file'],
      fit: BoxFit.contain,
    );
  }

  Widget _buildVideoPreview() {
    if (!_isVideoInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    return AspectRatio(
      aspectRatio: _videoController!.value.aspectRatio,
      child: VideoPlayer(_videoController!),
    );
  }
}
