// call_history_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mk_mesenger/common/models/call.dart';
import 'package:mk_mesenger/feature/call/controller/call_controller.dart';
import 'package:intl/intl.dart';
import 'package:mk_mesenger/feature/call/screens/call_screen.dart';

class CallHistoryTab extends ConsumerWidget {
  const CallHistoryTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      body: StreamBuilder<List<Call>>(
        stream: ref.watch(callControllerProvider).callHistory,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.call,
                    size: 80,
                    color: Colors.grey[700],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No hay historial de llamadas',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            );
          }
          
          final calls = snapshot.data!;
          
          // Agrupar llamadas por fecha
          final Map<String, List<Call>> callsByDate = {};
          
          for (final call in calls) {
            final date = DateFormat('dd/MM/yyyy').format(
              DateTime.fromMillisecondsSinceEpoch(call.timestamp),
            );
            
            if (!callsByDate.containsKey(date)) {
              callsByDate[date] = [];
            }
            
            callsByDate[date]!.add(call);
          }
          
          // Ordenar las fechas (más recientes primero)
          final sortedDates = callsByDate.keys.toList()
            ..sort((a, b) {
              final dateA = DateFormat('dd/MM/yyyy').parse(a);
              final dateB = DateFormat('dd/MM/yyyy').parse(b);
              return dateB.compareTo(dateA);
            });
          
          return ListView.builder(
            itemCount: sortedDates.length,
            itemBuilder: (context, index) {
              final date = sortedDates[index];
              final callsForDate = callsByDate[date]!;
              
              // Transformar fecha para mostrar
              final DateTime dateTime = DateFormat('dd/MM/yyyy').parse(date);
              final bool isToday = _isToday(dateTime);
              final bool isYesterday = _isYesterday(dateTime);
              
              final String dateLabel = isToday 
                  ? 'Hoy' 
                  : (isYesterday 
                      ? 'Ayer' 
                      : date);
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Encabezado de fecha
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Text(
                      dateLabel,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  
                  // Lista de llamadas para esta fecha
                  ...callsForDate.map((call) => _buildCallItem(context, ref, call)).toList(),
                ],
              );
            },
          );
        },
      ),
    );
  }
  
  // Comprobar si una fecha es hoy
  bool _isToday(DateTime date) {
    final today = DateTime.now();
    return date.year == today.year && 
           date.month == today.month && 
           date.day == today.day;
  }
  
  // Comprobar si una fecha es ayer
  bool _isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(Duration(days: 1));
    return date.year == yesterday.year && 
           date.month == yesterday.month && 
           date.day == yesterday.day;
  }
  
  // Construir elemento de llamada
  Widget _buildCallItem(BuildContext context, WidgetRef ref, Call call) {
    final currentUserId = ref.read(callControllerProvider).auth.currentUser!.uid;
    final bool isOutgoing = call.callerId == currentUserId;
    
    // Determinar nombre y foto a mostrar
    final String name = isOutgoing ? call.receiverName : call.callerName;
    final String profilePic = isOutgoing ? call.receiverPic : call.callerPic;
    final String contactId = isOutgoing ? call.receiverId : call.callerId;
    
    // Determinar tipo y estado de llamada
    IconData typeIcon;
    Color typeColor;
    
    if (call.callType == 'video') {
      typeIcon = Icons.videocam;
    } else {
      typeIcon = Icons.call;
    }
    
    if (call.callStatus == 'missed' || call.callStatus == 'rejected') {
      typeColor = Colors.red;
    } else if (call.callStatus == 'error') {
      typeColor = Colors.orange;
    } else {
      typeColor = Colors.green;
    }
    
    // Determinar flecha de dirección
    IconData directionIcon = isOutgoing 
        ? Icons.call_made 
        : Icons.call_received;
    
    Color directionColor = isOutgoing
        ? Colors.green
        : (call.callStatus == 'missed' ? Colors.red : Colors.blue);

    // Diseño del elemento de llamada
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Mostrar opciones al pulsar
          _showCallOptions(context, ref, call, isOutgoing, contactId, name, profilePic);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundImage: profilePic.isNotEmpty 
                    ? NetworkImage(profilePic) 
                    : null,
                backgroundColor: profilePic.isEmpty ? Color(0xFF3E63A8) : null,
                child: profilePic.isEmpty 
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white, 
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ) 
                    : null,
              ),
              SizedBox(width: 12),
              
              // Información central (nombre, estado, etc)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          directionIcon,
                          size: 14,
                          color: directionColor,
                        ),
                        SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _getCallStatusText(call, isOutgoing),
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Información de tiempo y tipo en columna
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Fecha/hora
                  Text(
                    _getFormattedDate(call.timestamp),
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        typeIcon,
                        color: typeColor,
                        size: 16,
                      ),
                      SizedBox(width: 4),
                      if (call.callTime > 0)
                        Text(
                          _formatCallDuration(call.callTime),
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Obtener texto de estado de llamada
  String _getCallStatusText(Call call, bool isOutgoing) {
    if (call.callStatus == 'missed') {
      return isOutgoing ? 'No contestada' : 'Perdida';
    } else if (call.callStatus == 'rejected') {
      return isOutgoing ? 'Rechazada' : 'Rechazada';
    } else if (call.callStatus == 'error') {
      return 'Error de conexión';
    } else if (call.callTime > 0) {
      return _formatCallDuration(call.callTime);
    } else {
      return isOutgoing ? 'Saliente' : 'Entrante';
    }
  }
  
  // Formatear duración de llamada
  String _formatCallDuration(int seconds) {
    if (seconds < 60) {
      return '$seconds seg';
    } else if (seconds < 3600) {
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      return '$minutes:${remainingSeconds.toString().padLeft(2, '0')} min';
    } else {
      final hours = seconds ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      return '$hours:${minutes.toString().padLeft(2, '0')} h';
    }
  }
  
  // Formatear fecha de llamada
  String _getFormattedDate(int timestamp) {
    final DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final DateTime now = DateTime.now();
    
    // Si es hoy, mostrar solo la hora
    if (dateTime.year == now.year && 
        dateTime.month == now.month && 
        dateTime.day == now.day) {
      return DateFormat('HH:mm').format(dateTime);
    }
    
    // Si es ayer, mostrar "Ayer"
    final DateTime yesterday = now.subtract(Duration(days: 1));
    if (dateTime.year == yesterday.year && 
        dateTime.month == yesterday.month && 
        dateTime.day == yesterday.day) {
      return 'Ayer ${DateFormat('HH:mm').format(dateTime)}';
    }
    
    // Si es esta semana, mostrar día
    if (now.difference(dateTime).inDays < 7) {
      return DateFormat('E HH:mm').format(dateTime);
    }
    
    // Para el resto, mostrar fecha completa
    return DateFormat('dd/MM HH:mm').format(dateTime);
  }
  
  // Mostrar opciones de llamada
  void _showCallOptions(
    BuildContext context, 
    WidgetRef ref, 
    Call call,
    bool isOutgoing,
    String contactId,
    String name,
    String profilePic,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Encabezado con nombre de contacto
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                name,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Divider(color: Colors.grey[800]),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.call, color: Colors.green),
              ),
              title: Text(
                'Llamada de voz',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _makeCall(context, ref, contactId, name, profilePic, false, 'audio');
              },
            ),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.videocam, color: Colors.blue),
              ),
              title: Text(
                'Videollamada',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _makeCall(context, ref, contactId, name, profilePic, false, 'video');
              },
            ),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.info_outline, color: Colors.orange),
              ),
              title: Text(
                'Ver detalles',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _showCallDetails(context, call, isOutgoing);
              },
            ),
          ],
        ),
      ),
    );
  }
  
  // Hacer una llamada desde el historial
  void _makeCall(
    BuildContext context,
    WidgetRef ref,
    String receiverId,
    String receiverName,
    String receiverProfilePic,
    bool isGroupChat,
    String callType,
  ) {
    // Mostrar indicador de "llamando..."
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(callType == 'video' 
          ? 'Iniciando videollamada...' 
          : 'Iniciando llamada de voz...'),
        duration: const Duration(seconds: 2),
      ),
    );

    // Crear la llamada
    Call call = ref.read(callControllerProvider).makeCall(
      context,
      receiverName,
      receiverId,
      receiverProfilePic,
      isGroupChat,
      callType: callType,
    );

    // Navegar a CallScreen
    if (call.callStatus != 'error') {
      Navigator.pushNamed(
        context,
        CallScreen.routeName,
        arguments: {
          'channelId': call.callId,
          'call': call,
          'isGroupChat': isGroupChat,
        },
      );
    } else {
      // Mostrar mensaje de error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(callType == 'video' 
            ? 'Error al iniciar videollamada. Intente nuevamente.' 
            : 'Error al iniciar llamada de voz. Intente nuevamente.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Mostrar detalles de llamada
  void _showCallDetails(BuildContext context, Call call, bool isOutgoing) {
    final DateTime callTime = DateTime.fromMillisecondsSinceEpoch(call.timestamp);
    final String formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(callTime);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF2A2A2A),
        title: Text(
          'Detalles de la llamada',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(
              'Tipo:',
              call.callType == 'video' ? 'Videollamada' : 'Llamada de voz'
            ),
            _buildDetailRow(
              'Estado:',
              _getStatusText(call.callStatus)
            ),
            _buildDetailRow(
              'Dirección:',
              isOutgoing ? 'Saliente' : 'Entrante'
            ),
            _buildDetailRow(
              'Fecha y hora:',
              formattedDate
            ),
            _buildDetailRow(
              'Duración:',
              _formatCallDuration(call.callTime)
            ),
            _buildDetailRow(
              isOutgoing ? 'Destinatario:' : 'Remitente:',
              isOutgoing ? call.receiverName : call.callerName
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cerrar',
              style: TextStyle(color: Color(0xFF3E63A8)),
            ),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
  
  // Construir fila de detalles
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[400],
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Obtener texto de estado
  String _getStatusText(String status) {
    switch (status) {
      case 'missed':
        return 'Perdida';
      case 'rejected':
        return 'Rechazada';
      case 'error':
        return 'Error';
      case 'ended':
        return 'Finalizada';
      default:
        return 'Desconocido';
    }
  }
}