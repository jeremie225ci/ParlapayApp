// call.dart (modificaciones)
import 'dart:convert';

class Call {
  final String callerId;
  final String callerName;
  final String callerPic;
  final String receiverId;
  final String receiverName;
  final String receiverPic;
  final String callId;
  final bool hasDialled;
  final int timestamp;
  final bool isGroupCall;
  final String callType; // 'video' o 'audio'
  final String callStatus; // 'ongoing', 'ended', 'missed', 'rejected', 'error'
  final int callTime; // Duración en segundos

  Call({
    required this.callerId,
    required this.callerName,
    required this.callerPic,
    required this.receiverId,
    required this.receiverName,
    required this.receiverPic,
    required this.callId,
    required this.hasDialled,
    required this.timestamp,
    required this.isGroupCall,
    required this.callType,
    required this.callStatus,
    required this.callTime,
  });

  // Resto de métodos sin cambios


  Map<String, dynamic> toMap() {
    return {
      'callerId': callerId,
      'callerName': callerName,
      'callerPic': callerPic,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverPic': receiverPic,
      'callId': callId,
      'hasDialled': hasDialled,
      'timestamp': timestamp,
      'isGroupCall': isGroupCall,
      'callType': callType,
      'callStatus': callStatus,
      'callTime': callTime,
    };
  }

  factory Call.fromMap(Map<String, dynamic> map) {
    return Call(
      callerId: map['callerId'] ?? '',
      callerName: map['callerName'] ?? '',
      callerPic: map['callerPic'] ?? '',
      receiverId: map['receiverId'] ?? '',
      receiverName: map['receiverName'] ?? '',
      receiverPic: map['receiverPic'] ?? '',
      callId: map['callId'] ?? '',
      hasDialled: map['hasDialled'] ?? false,
      timestamp: map['timestamp'] ?? 0,
      isGroupCall: map['isGroupCall'] ?? false,
      callType: map['callType'] ?? 'video',
      callStatus: map['callStatus'] ?? 'ongoing',
      callTime: map['callTime'] ?? 0,
    );
  }
  
  // Añadir método para convertir a JSON
  String toJson() {
    return jsonEncode(toMap());
  }

  // Añadir método para crear desde JSON
  static Call fromJson(String jsonStr) {
    try {
      final Map<String, dynamic> map = jsonDecode(jsonStr);
      
      return Call(
        callerId: map['callerId'] ?? '',
        callerName: map['callerName'] ?? '',
        callerPic: map['callerPic'] ?? '',
        receiverId: map['receiverId'] ?? '',
        receiverName: map['receiverName'] ?? '',
        receiverPic: map['receiverPic'] ?? '',
        callId: map['callId'] ?? '',
        hasDialled: map['hasDialled'] == true,
        // Manejar casos donde timestamp puede ser string o int
        timestamp: map['timestamp'] is String 
            ? int.tryParse(map['timestamp']) ?? 0 
            : (map['timestamp'] ?? 0),
        isGroupCall: map['isGroupCall'] == true,
        callType: map['callType'] ?? 'audio',
        callStatus: map['callStatus'] ?? 'missed',
        // Manejar casos donde callTime puede ser string o int
        callTime: map['callTime'] is String 
            ? int.tryParse(map['callTime']) ?? 0 
            : (map['callTime'] ?? 0),
      );
    } catch (e) {
      print('Error parseando JSON de llamada: $e');
      // Retornar una llamada vacía en caso de error de parseo
      return Call(
        callerId: '',
        callerName: '',
        callerPic: '',
        receiverId: '',
        receiverName: '',
        receiverPic: '',
        callId: '',
        hasDialled: false,
        timestamp: 0,
        isGroupCall: false,
        callType: 'audio',
        callStatus: 'error',
        callTime: 0,
      );
    }
  }
}