import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mk_mesenger/common/repositories/common_firebase_storage_repository.dart';
import 'package:mk_mesenger/common/utils/utils.dart';
import 'package:mk_mesenger/common/models/group.dart' as model;

final groupRepositoryProvider = Provider(
  (ref) => GroupRepository(
    firestore: FirebaseFirestore.instance,
    auth: FirebaseAuth.instance,
    ref: ref,
  ),
);

const String _defaultGroupPicUrl = 'https://png.pngitem.com/pimgs/s/649-6490124_katie-notopoulos-katienotopoulos-i-write-about-tech-round.png';

class GroupRepository {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final Ref ref;

  GroupRepository({
    required this.firestore,
    required this.auth,
    required this.ref,
  });

  /// Crea un grupo en Firestore con un ID predefinido
  Future<void> createGroup(
    BuildContext context,
    String groupId,
    String name,
    File? profilePic,
    List<String> memberIds,
  ) async {
    try {
      // Obtener URL de imagen o por defecto
      String picUrl = _defaultGroupPicUrl;
      if (profilePic != null) {
        picUrl = await ref
            .read(commonFirebaseStorageRepositoryProvider)
            .storeFileToFirebase('group/$groupId', profilePic);
      }

      // Construir modelo y guardar
      final group = model.Group(
        senderId: auth.currentUser!.uid,
        name: name,
        groupId: groupId,
        lastMessage: '',
        groupPic: picUrl,
        membersUid: [auth.currentUser!.uid, ...memberIds],
        timeSent: DateTime.now(),
        admin: auth.currentUser!.uid,
        groupDescription: 'Grupo creado el ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
      );

      await firestore.collection('groups').doc(groupId).set(group.toMap());
      
      // Actualizar los grupos de cada miembro
      for (var memberId in [auth.currentUser!.uid, ...memberIds]) {
        await firestore.collection('users').doc(memberId).update({
          'groupId': FieldValue.arrayUnion([groupId]),
        });
      }
      
      showSnackBar(context: context, content: "Grupo '$name' creado con éxito");
    } catch (e) {
      showSnackBar(context: context, content: e.toString());
    }
  }
  
  /// Obtiene todos los grupos del usuario actual
  Stream<List<model.Group>> getChatGroups() {
    return firestore.collection('groups')
      .where('membersUid', arrayContains: auth.currentUser!.uid)
      .snapshots()
      .map((event) {
        List<model.Group> groups = [];
        for (var document in event.docs) {
          var group = model.Group.fromMap(document.data());
          groups.add(group);
        }
        return groups;
      });
  }
  
  /// Obtiene un grupo específico por su ID
  Stream<model.Group> getGroupById(String groupId) {
    return firestore.collection('groups')
      .doc(groupId)
      .snapshots()
      .map((event) => model.Group.fromMap(event.data()!));
  }
  
  /// Permite a un usuario abandonar un grupo
  Future<void> leaveGroup(
    BuildContext context,
    String groupId,
    String userId,
  ) async {
    try {
      // Eliminar al usuario de la lista de miembros del grupo
      await firestore.collection('groups').doc(groupId).update({
        'membersUid': FieldValue.arrayRemove([userId]),
      });
      
      // Eliminar el grupo de la lista de grupos del usuario
      await firestore.collection('users').doc(userId).update({
        'groupId': FieldValue.arrayRemove([groupId]),
      });
      
      showSnackBar(context: context, content: "Has abandonado el grupo");
    } catch (e) {
      showSnackBar(context: context, content: e.toString());
    }
  }
  
  /// Actualiza la información de un grupo
  Future<void> updateGroupInfo(
    BuildContext context,
    String groupId,
    String name,
    String description,
    File? profilePic,
  ) async {
    try {
      Map<String, dynamic> updateData = {
        'name': name,
        'groupDescription': description,
      };
      
      if (profilePic != null) {
        String picUrl = await ref
            .read(commonFirebaseStorageRepositoryProvider)
            .storeFileToFirebase('group/$groupId', profilePic);
        updateData['groupPic'] = picUrl;
      }
      
      await firestore.collection('groups').doc(groupId).update(updateData);
      
      showSnackBar(context: context, content: "Información del grupo actualizada");
    } catch (e) {
      showSnackBar(context: context, content: e.toString());
    }
  }
}
