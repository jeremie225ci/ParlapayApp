import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mk_mesenger/common/models/status_model.dart';
import 'package:mk_mesenger/feature/status/repository/status_repository.dart';

final statusControllerProvider = Provider((ref) {
  final statusRepository = ref.watch(statusRepositoryProvider);
  return StatusController(
    statusRepository: statusRepository,
    ref: ref,
  );
});

class StatusController {
  final StatusRepository statusRepository;
  final ProviderRef ref;

  StatusController({
    required this.statusRepository,
    required this.ref,
  });

  // Agregar un estado
  void addStatus({
    required File file,
    required BuildContext context,
    required String caption,
    bool isVideo = false,
    String visibilityMode = 'all',
    List<String> excludedContacts = const [],
  }) async {
    try {
      await statusRepository.uploadStatus(
        file: file,
        context: context,
        caption: caption,
        isVideo: isVideo,
        visibilityMode: visibilityMode,
        excludedContacts: excludedContacts,
      );
    } catch (e) {
      debugPrint('Error en StatusController.addStatus: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al publicar el estado: $e')),
        );
      }
    }
  }

  // Obtener estados agrupados por usuario
  Future<List<Status>> getStatus(BuildContext context) async {
    try {
      // Primero, limpiar estados expirados
      await statusRepository.cleanExpiredStatuses();
      
      // Luego obtener estados válidos
      List<Status> statuses = await statusRepository.getStatus(context);
      
      // Verificar si se obtuvieron estados
      if (statuses.isEmpty) {
        debugPrint('No se encontraron estados para mostrar');
      } else {
        debugPrint('Se encontraron ${statuses.length} estados para mostrar');
      }
      
      return statuses;
    } catch (e) {
      debugPrint('Error en StatusController.getStatus: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar estados: $e')),
        );
      }
      return [];
    }
  }

  // Obtener solo mi estado
  Future<Status?> getMyStatus(BuildContext context) async {
    try {
      return await statusRepository.getMyStatus(context);
    } catch (e) {
      debugPrint('Error en StatusController.getMyStatus: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar tus estados: $e')),
        );
      }
      return null;
    }
  }
  
  // Obtener todos los estados para navegación
  Future<List<Status>> getAllStatusUpdates(BuildContext context) async {
    try {
      return await statusRepository.getAllStatusUpdates(context);
    } catch (e) {
      debugPrint('Error en StatusController.getAllStatusUpdates: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar actualizaciones: $e')),
        );
      }
      return [];
    }
  }
  
  // Registrar vista de estado
  Future<void> registerStatusView(String statusId) async {
    try {
      await statusRepository.registerStatusView(statusId);
      debugPrint('Vista registrada correctamente para el estado: $statusId');
    } catch (e) {
      debugPrint('Error en StatusController.registerStatusView: $e');
    }
  }
  
  // Eliminar un estado
  Future<void> deleteStatus(String statusId, BuildContext context) async {
    try {
      await statusRepository.deleteStatus(statusId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Estado eliminado')),
        );
      }
    } catch (e) {
      debugPrint('Error en StatusController.deleteStatus: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar el estado: $e')),
        );
      }
    }
  }
  
  // Limpiar estados expirados
  Future<void> cleanExpiredStatuses() async {
    try {
      await statusRepository.cleanExpiredStatuses();
    } catch (e) {
      debugPrint('Error en StatusController.cleanExpiredStatuses: $e');
    }
  }
}
