import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mk_mesenger/common/models/group.dart';
import 'package:mk_mesenger/feature/group/repository/group_repository.dart';

/// Provider para el controlador de grupos
final groupControllerProvider = Provider((ref) {
  return GroupController(
    groupRepository: ref.read(groupRepositoryProvider),
    ref: ref,
  );
});

class GroupController {
  final GroupRepository groupRepository;
  final Ref ref;

  GroupController({
    required this.groupRepository,
    required this.ref,
  });

  /// Crea un grupo usando un ID proporcionado
  void createGroup(
    BuildContext context,
    String groupId,
    String name,
    File? profilePic,
    List<String> selectedUserIds,
  ) {
    groupRepository.createGroup(context, groupId, name, profilePic, selectedUserIds);
  }
  
  /// Obtiene todos los grupos del usuario actual
  Stream<List<Group>> chatGroups() {
    return groupRepository.getChatGroups();
  }
  
  /// Obtiene un grupo específico por su ID
  Stream<Group> getGroupById(String groupId) {
    return groupRepository.getGroupById(groupId);
  }
  
  /// Permite a un usuario abandonar un grupo
  Future<void> leaveGroup(
    BuildContext context,
    String groupId,
    String userId,
  ) async {
    await groupRepository.leaveGroup(context, groupId, userId);
  }
  
  /// Actualiza la información de un grupo
  Future<void> updateGroupInfo(
    BuildContext context,
    String groupId,
    String name,
    String description,
    File? profilePic,
  ) async {
    await groupRepository.updateGroupInfo(
      context,
      groupId,
      name,
      description,
      profilePic,
    );
  }
}