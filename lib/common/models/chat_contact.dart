// Ruta: lib/common/models/chat_contact.dart

class ChatContact {
  final String name;
  final String profilePic;
  final String contactId;
  final DateTime timeSent;
  final String lastMessage;
  final String? phoneNumber;
  final bool isGroup;
  final int unreadCount;
  final bool isPinned; // Nueva propiedad para destacados
  final int pinnedOrder; // Para mantener el orden de anclaje

  ChatContact({
    required this.name,
    required this.profilePic,
    required this.contactId,
    required this.timeSent,
    required this.lastMessage,
    this.phoneNumber,
    this.isGroup = false,
    this.unreadCount = 0,
    this.isPinned = false, // Por defecto no está anclado
    this.pinnedOrder = 0, // Por defecto orden 0
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'profilePic': profilePic,
      'contactId': contactId,
      'timeSent': timeSent.millisecondsSinceEpoch,
      'lastMessage': lastMessage,
      'phoneNumber': phoneNumber,
      'isGroup': isGroup,
      'unreadCount': unreadCount,
      'isPinned': isPinned,
      'pinnedOrder': pinnedOrder,
    };
  }

  factory ChatContact.fromMap(Map<String, dynamic> map) {
    return ChatContact(
      name: map['name'] ?? '',
      profilePic: map['profilePic'] ?? '',
      contactId: map['contactId'] ?? '',
      timeSent: DateTime.fromMillisecondsSinceEpoch(map['timeSent']),
      lastMessage: map['lastMessage'] ?? '',
      phoneNumber: map['phoneNumber'],
      isGroup: map['isGroup'] ?? false,
      unreadCount: map['unreadCount'] ?? 0,
      isPinned: map['isPinned'] ?? false,
      pinnedOrder: map['pinnedOrder'] ?? 0,
    );
  }
}