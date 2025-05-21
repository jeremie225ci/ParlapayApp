// lib/common/models/group.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Group {
  final String senderId;
  final String name;
  final String groupId;
  final String lastMessage;
  final String groupPic;
  final List<String> membersUid;
  final DateTime timeSent;
  final String admin;
  final String? groupDescription;

  Group({
    required this.senderId,
    required this.name,
    required this.groupId,
    required this.lastMessage,
    required this.groupPic,
    required this.membersUid,
    required this.timeSent,
    required this.admin,
    this.groupDescription,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'name': name,
      'groupId': groupId,
      'lastMessage': lastMessage,
      'groupPic': groupPic,
      'membersUid': membersUid,
      'timeSent': timeSent.millisecondsSinceEpoch,
      'admin': admin,
      'groupDescription': groupDescription,
    };
  }

  factory Group.fromMap(Map<String, dynamic> map) {
    // Obtener el último mensaje
    String lastMessage = map['lastMessage'] ?? '';
    
    // Filtrar mensajes de notificación
    if (lastMessage.contains('eventId:') || 
        lastMessage.contains('Nuevo evento') || 
        lastMessage.contains('Objetivo:') ||
        lastMessage.contains('ha contribuido') ||
        lastMessage.startsWith('€') ||
        lastMessage.contains('comprado el producto') ||
        lastMessage.contains('completado') ||
        lastMessage.contains('recaudado') ||
        (lastMessage.contains('evento') && lastMessage.contains('finalizado'))) {
      // Reemplazar con cadena vacía o un texto genérico
      lastMessage = "";
    }
    
    return Group(
      senderId: map['senderId'] ?? '',
      name: map['name'] ?? '',
      groupId: map['groupId'] ?? '',
      lastMessage: lastMessage, // Usar el mensaje filtrado
      groupPic: map['groupPic'] ?? '',
      membersUid: List<String>.from(map['membersUid']),
      timeSent: DateTime.fromMillisecondsSinceEpoch(map['timeSent']),
      admin: map['admin'] ?? '',
      groupDescription: map['groupDescription'],
    );
  }

  factory Group.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Documento no existe o no contiene datos');
    }
    return Group.fromMap(data);
  }

  Group copyWith({
    String? senderId,
    String? name,
    String? groupId,
    String? lastMessage,
    String? groupPic,
    List<String>? membersUid,
    DateTime? timeSent,
    String? admin,
    String? groupDescription,
  }) {
    return Group(
      senderId: senderId ?? this.senderId,
      name: name ?? this.name,
      groupId: groupId ?? this.groupId,
      lastMessage: lastMessage ?? this.lastMessage,
      groupPic: groupPic ?? this.groupPic,
      membersUid: membersUid ?? this.membersUid,
      timeSent: timeSent ?? this.timeSent,
      admin: admin ?? this.admin,
      groupDescription: groupDescription ?? this.groupDescription,
    );
  }
}