// Ruta: lib/common/models/search_result.dart

import 'package:mk_mesenger/common/enums/message_enum.dart';

class SearchResult {
  final String contactId;
  final String messageId;
  final String text;
  final String snippet;
  final int matchIndex;
  final int matchLength;
  final bool isSentByMe;
  final DateTime timeSent;
  final String contactName;
  final String contactProfilePic;
  final bool isGroup;
  final MessageEnum messageType;
  final String? phoneNumber; // Añadido para poder mostrar el número cuando no está en contactos

  SearchResult({
    required this.contactId,
    required this.messageId,
    required this.text,
    required this.snippet,
    required this.matchIndex,
    required this.matchLength,
    required this.isSentByMe,
    required this.timeSent,
    required this.contactName,
    required this.contactProfilePic,
    required this.isGroup,
    required this.messageType,
    this.phoneNumber,
  });
}