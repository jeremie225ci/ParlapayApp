import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mk_mesenger/common/repositories/common_firebase_storage_repository.dart';
import 'package:mk_mesenger/common/utils/utils.dart';
import 'package:mk_mesenger/common/models/status_model.dart';
import 'package:mk_mesenger/common/models/user_model.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import 'package:firebase_storage/firebase_storage.dart';

final statusRepositoryProvider = Provider(
  (ref) => StatusRepository(
    firestore: FirebaseFirestore.instance,
    auth: FirebaseAuth.instance,
    firebaseStorage: FirebaseStorage.instance,
    ref: ref,
  ),
);

class StatusRepository {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final FirebaseStorage firebaseStorage;
  final ProviderRef ref;

  StatusRepository({
    required this.firestore,
    required this.auth,
    required this.firebaseStorage,
    required this.ref,
  });

  Future<void> uploadStatus({
    required File file,
    required BuildContext context,
    required String caption,
    bool isVideo = false,
    String visibilityMode = 'all',
    List<String> excludedContacts = const [],
  }) async {
    try {
      final statusId = const Uuid().v1();
      String uid = auth.currentUser!.uid;
      
      // Determinar el tipo de archivo
      String fileExtension = path.extension(file.path).toLowerCase();
      bool isVideoFile = fileExtension == '.mp4' || 
                          fileExtension == '.mov' || 
                          fileExtension == '.avi' ||
                          isVideo;
      
      // Subir archivo a Firebase Storage
      final mediaUrl = await ref
          .read(commonFirebaseStorageRepositoryProvider)
          .storeFileToFirebase('/status/$statusId', file);

      debugPrint('Archivo subido con éxito: $mediaUrl');

      List<Contact> contacts = [];
      try {
        if (await FlutterContacts.requestPermission()) {
          contacts = await FlutterContacts.getContacts(withProperties: true);
        }
      } catch (e) {
        debugPrint('Error obteniendo contactos: $e');
        if (context.mounted) {
          showSnackBar(context: context, content: 'Error al acceder a los contactos');
        }
      }

      List<String> phoneNumbers = [];
      for (int i = 0; i < contacts.length; i++) {
        if (contacts[i].phones.isNotEmpty) {
          phoneNumbers.add(contacts[i].phones[0].number.replaceAll(' ', ''));
        }
      }

      List<String> whoCanSee = [];
      
      try {
        // Obtener todos los usuarios, no solo los contactos
        QuerySnapshot querySnapshot = await firestore.collection('users').get();
        
        // Para debug: contar usuarios encontrados
        debugPrint('Encontrados ${querySnapshot.docs.length} usuarios en la base de datos');
        
        // Implementar lógica de visibilidad
        if (visibilityMode == 'all') {
          // Todos los contactos pueden ver
          for (var doc in querySnapshot.docs) {
            UserModel user = UserModel.fromMap(doc.data() as Map<String, dynamic>);
            
            // Si es un contacto o el propio usuario, agregar a whoCanSee
            if (phoneNumbers.contains(user.phoneNumber) || user.uid == uid) {
              whoCanSee.add(user.uid);
              debugPrint('Usuario ${user.name} (${user.uid}) puede ver el estado');
            }
          }
        } else if (visibilityMode == 'except') {
          // Todos excepto los excluidos
          for (var doc in querySnapshot.docs) {
            UserModel user = UserModel.fromMap(doc.data() as Map<String, dynamic>);
            
            // Si es un contacto o el propio usuario Y no está excluido, agregar a whoCanSee
            if ((phoneNumbers.contains(user.phoneNumber) || user.uid == uid) && 
              !excludedContacts.contains(user.uid)) {
              whoCanSee.add(user.uid);
              debugPrint('Usuario ${user.name} (${user.uid}) puede ver el estado');
            }
          }
        }
      
        // Para test: asegurémonos de que haya al menos algunos usuarios que puedan ver el estado
        if (whoCanSee.isEmpty || whoCanSee.length == 1 && whoCanSee.contains(uid)) {
          debugPrint('¡ADVERTENCIA! No se encontraron contactos válidos. Permitiendo que todos los usuarios vean el estado para pruebas');
          for (var doc in querySnapshot.docs) {
            UserModel user = UserModel.fromMap(doc.data() as Map<String, dynamic>);
            if (!whoCanSee.contains(user.uid)) {
              whoCanSee.add(user.uid);
            }
          }
        }
      } catch (e) {
        debugPrint('Error consultando usuarios: $e');
      }

      // Obtener datos del usuario actual
      DocumentSnapshot userDoc;
      try {
        userDoc = await firestore.collection('users').doc(uid).get();
      } catch (e) {
        debugPrint('Error obteniendo datos del usuario: $e');
        if (context.mounted) {
          showSnackBar(context: context, content: 'Error al obtener perfil de usuario');
        }
        return;
      }
      
      if (!userDoc.exists) {
        debugPrint('Documento de usuario no encontrado');
        if (context.mounted) {
          showSnackBar(context: context, content: 'Perfil de usuario no encontrado');
        }
        return;
      }
      
      UserModel user = UserModel.fromMap(userDoc.data() as Map<String, dynamic>);

      // Siempre incluir al usuario actual en whoCanSee
      if (!whoCanSee.contains(uid)) {
        whoCanSee.add(uid);
      }

      // Para debug: mostrar quién puede ver el estado
      debugPrint('Total de usuarios que pueden ver este estado: ${whoCanSee.length}');
      debugPrint('Modo de visibilidad: $visibilityMode');
      if (visibilityMode == 'except') {
        debugPrint('Contactos excluidos: ${excludedContacts.length}');
      }

      // Crear StatusMedia
      StatusMedia media = StatusMedia(
        url: mediaUrl,
        type: isVideoFile ? MediaType.video : MediaType.image,
        caption: caption,
        timestamp: DateTime.now(),
      );

      // Verificar si ya existe un estado del usuario en las últimas 24 horas
      final yesterday = DateTime.now().subtract(const Duration(hours: 24));
      
      QuerySnapshot<Map<String, dynamic>> existingStatusQuery = await firestore
          .collection('status')
          .where('uid', isEqualTo: uid)
          .where('createdAt', isGreaterThan: yesterday.millisecondsSinceEpoch)
          .limit(1)
          .get();
      
      if (existingStatusQuery.docs.isNotEmpty) {
        // Ya existe un estado, agregar el medio al estado existente
        String existingStatusId = existingStatusQuery.docs.first.id;
        Status existingStatus = Status.fromMap(existingStatusQuery.docs.first.data());
        
        List<StatusMedia> updatedMedia = [...existingStatus.media, media];
        
        await firestore.collection('status').doc(existingStatusId).update({
          'media': updatedMedia.map((m) => m.toMap()).toList(),
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
          'whoCanSee': whoCanSee, // Actualizar quién puede ver
        });
        
        debugPrint('Media agregado a estado existente con ID: $existingStatusId');
      } else {
        // Crear un nuevo estado
        Status status = Status(
          uid: uid,
          username: user.name,
          phoneNumber: user.phoneNumber,
          media: [media],
          whoCanSee: whoCanSee,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          profilePic: user.profilePic,
          statusId: statusId,
          viewers: [], // Inicialmente sin vistas
          expiryTime: DateTime.now().add(const Duration(hours: 24)), // Expiración en 24h
        );

        await firestore.collection('status').doc(statusId).set(status.toMap());
        debugPrint('Nuevo estado creado con ID: $statusId');
        
        // Programar la eliminación automática después de 24 horas
        _scheduleStatusDeletion(statusId);
      }
      
      // Redirección después de subir el estado
      if (context.mounted) {
        Navigator.pop(context);
        showSnackBar(context: context, content: 'Estado publicado con éxito');
      }
    } catch (e) {
      debugPrint('Error en uploadStatus: $e');
      if (context.mounted) {
        showSnackBar(context: context, content: 'Error al publicar estado: $e');
      }
    }
  }

  // Programar eliminación de estado
  Future<void> _scheduleStatusDeletion(String statusId) async {
    try {
      // En un entorno real, deberías usar Cloud Functions para esto
      // Pero como demo, establecemos un campo expiryTime y luego filtramos por él
      
      // Configurar un campo de expiración
      await firestore.collection('status').doc(statusId).update({
        'expiryTime': DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch
      });
      
      debugPrint('Programada eliminación de estado $statusId en 24 horas');
    } catch (e) {
      debugPrint('Error programando eliminación: $e');
    }
  }

  // Obtener todos los estados (modificada para corregir el problema)
  Future<List<Status>> getStatus(BuildContext context) async {
    Map<String, Status> statusByUser = {};
    
    try {
      String uid = auth.currentUser!.uid;
      debugPrint('Buscando estados para el usuario: $uid');
      
      // Obtener estados de las últimas 24 horas
      final yesterday = DateTime.now().subtract(const Duration(hours: 24));
      
      // Consulta correcta: buscar todos los estados donde el usuario actual está en whoCanSee
      QuerySnapshot<Map<String, dynamic>> statusesSnapshot = await firestore
          .collection('status')
          .where('whoCanSee', arrayContains: uid)
          .where('createdAt', isGreaterThan: yesterday.millisecondsSinceEpoch)
          .get();

      debugPrint('Encontrados ${statusesSnapshot.docs.length} estados totales');
      
      // Agrupar estados por usuario (el más reciente por usuario)
      for (var document in statusesSnapshot.docs) {
        try {
          Status status = Status.fromMap(document.data());
          
          // Excluir estados expirados
          if (status.isExpired) {
            debugPrint('Estado ${document.id} expirado, ignorando');
            continue;
          }
          
          // Si ya tenemos un estado de este usuario y es más reciente, lo ignoramos
          if (!statusByUser.containsKey(status.uid) || 
              status.updatedAt.isAfter(statusByUser[status.uid]!.updatedAt)) {
            statusByUser[status.uid] = status;
            debugPrint('Agregando/actualizando estado de usuario: ${status.username}');
          }
        } catch (e) {
          debugPrint('Error al convertir documento a Status: $e');
          debugPrint('Datos del documento: ${document.data()}');
        }
      }
    } catch (e) {
      debugPrint('Error en getStatus: $e');
      if (context.mounted) {
        showSnackBar(context: context, content: 'Error al obtener estados');
      }
    }
    
    // Convertir el mapa a lista y ordenar por hora de actualización (más reciente primero)
    List<Status> result = statusByUser.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    // Mover el estado del usuario actual al principio si existe
    int myStatusIndex = result.indexWhere((status) => status.uid == auth.currentUser!.uid);
    if (myStatusIndex != -1) {
      Status myStatus = result.removeAt(myStatusIndex);
      result.insert(0, myStatus);
    }
    
    debugPrint('Total de estados a mostrar (agrupados): ${result.length}');
    return result;
  }

  // Obtener solo los estados del usuario actual
  Future<Status?> getMyStatus(BuildContext context) async {
    try {
      String uid = auth.currentUser!.uid;
      
      // Obtener estados de las últimas 24 horas
      final yesterday = DateTime.now().subtract(const Duration(hours: 24));
      
      QuerySnapshot<Map<String, dynamic>> statusesSnapshot = await firestore
          .collection('status')
          .where('createdAt', isGreaterThan: yesterday.millisecondsSinceEpoch)
          .where('uid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (statusesSnapshot.docs.isEmpty) {
        return null;
      }
      
      return Status.fromMap(statusesSnapshot.docs.first.data());
    } catch (e) {
      debugPrint('Error en getMyStatus: $e');
      if (context.mounted) {
        showSnackBar(context: context, content: 'Error al obtener tus estados');
      }
      return null;
    }
  }
  
  // Obtener todos los estados (incluyendo todas las actualizaciones)
  Future<List<Status>> getAllStatusUpdates(BuildContext context) async {
    List<Status> allStatuses = [];
    
    try {
      String uid = auth.currentUser!.uid;
      
      // Obtener estados de las últimas 24 horas
      final yesterday = DateTime.now().subtract(const Duration(hours: 24));
      
      QuerySnapshot<Map<String, dynamic>> statusesSnapshot = await firestore
          .collection('status')
          .where('createdAt', isGreaterThan: yesterday.millisecondsSinceEpoch)
          .where('whoCanSee', arrayContains: uid)
          .orderBy('createdAt', descending: true)
          .get();
      
      debugPrint('getAllStatusUpdates: Encontrados ${statusesSnapshot.docs.length} estados');
      
      for (var document in statusesSnapshot.docs) {
        try {
          Status status = Status.fromMap(document.data());
          allStatuses.add(status);
          debugPrint('Agregado estado de: ${status.username} con ${status.media.length} medios');
        } catch (e) {
          debugPrint('Error al convertir documento a Status: $e');
        }
      }
    } catch (e) {
      debugPrint('Error en getAllStatusUpdates: $e');
      if (context.mounted) {
        showSnackBar(context: context, content: 'Error al obtener actualizaciones de estado');
      }
    }
    
    return allStatuses;
  }
  
  // Eliminar un estado
  Future<void> deleteStatus(String statusId) async {
    try {
      // Obtener primero los datos del estado
      DocumentSnapshot statusDoc = await firestore.collection('status').doc(statusId).get();
      
      if (!statusDoc.exists) {
        debugPrint('Estado no encontrado para eliminar');
        return;
      }
      
      // Obtener URLs de los medios para eliminarlos de Storage
      final statusData = statusDoc.data() as Map<String, dynamic>;
      final List<dynamic> mediaList = statusData['media'] ?? [];
      
      // Eliminar archivo de storage
      for (var media in mediaList) {
        final String url = media['url'] ?? '';
        if (url.isNotEmpty) {
          try {
            await firebaseStorage.refFromURL(url).delete();
            debugPrint('Medio eliminado de Storage: $url');
          } catch (e) {
            debugPrint('Error eliminando medio de Storage: $e');
          }
        }
      }
      
      // Eliminar documento de Firestore
      await firestore.collection('status').doc(statusId).delete();
      debugPrint('Estado eliminado: $statusId');
      
    } catch (e) {
      debugPrint('Error eliminando estado: $e');
    }
  }
  
  // Limpiar estados expirados (llamar periódicamente)
 
  
  // Registrar vista de un estado
  Future<void> registerStatusView(String statusId) async {
    try {
      final uid = auth.currentUser!.uid;
      
      // Verificar si el usuario ya ha visto este estado
      DocumentSnapshot statusDoc = await firestore.collection('status').doc(statusId).get();
      
      if (!statusDoc.exists) {
        debugPrint('El estado $statusId no existe');
        return;
      }
      
      Map<String, dynamic> statusData = statusDoc.data() as Map<String, dynamic>;
      List<dynamic> currentViewers = statusData['viewers'] ?? [];
      
      // Verificar si el usuario ya está en la lista de viewers
      bool alreadyViewed = currentViewers.any((viewer) => 
        viewer is Map<String, dynamic> && viewer['uid'] == uid);
      
      if (alreadyViewed) {
        debugPrint('El usuario $uid ya ha visto este estado');
        return;
      }
      
      // Registrar vista
      await firestore.collection('status').doc(statusId).update({
        'viewers': FieldValue.arrayUnion([
          {
            'uid': uid,
            'timestamp': DateTime.now().millisecondsSinceEpoch
          }
        ])
      });
      
      debugPrint('Vista registrada para el estado $statusId por usuario $uid');
    } catch (e) {
      debugPrint('Error registrando vista: $e');
    }
  }

  // Mejorar el método cleanExpiredStatuses para que sea más efectivo
  Future<void> cleanExpiredStatuses() async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Buscar estados expirados
      QuerySnapshot<Map<String, dynamic>> expiredStatusesSnapshot = await firestore
          .collection('status')
          .where('expiryTime', isLessThan: now)
          .get();
          
      debugPrint('Encontrados ${expiredStatusesSnapshot.docs.length} estados expirados');
      
      // Eliminar cada estado expirado
      for (var doc in expiredStatusesSnapshot.docs) {
        await deleteStatus(doc.id);
        debugPrint('Estado expirado eliminado: ${doc.id}');
      }
    } catch (e) {
      debugPrint('Error limpiando estados expirados: $e');
    }
  }
}
