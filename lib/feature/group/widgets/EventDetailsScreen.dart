import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart'; // Para kDebugMode
import 'package:mk_mesenger/common/enums/message_enum.dart';
import 'package:mk_mesenger/feature/group/providers.dart';
import 'package:mk_mesenger/common/utils/utils.dart';
import 'package:mk_mesenger/common/utils/colors.dart';
import 'package:mk_mesenger/feature/group/widgets/record_funds_tab.dart';
import 'package:mk_mesenger/feature/wallet/controller/wallet_controller.dart';
import 'package:uuid/uuid.dart';

class EventDetailsScreen extends ConsumerWidget {
  final String eventId;
  
  const EventDetailsScreen({
    Key? key,
    required this.eventId,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: ref.read(recordFundsControllerProvider).getEventDetails(eventId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: const Color(0xFF121212),
            body: const Center(child: CircularProgressIndicator(color: Color(0xFF3E63A8))),
          );
        }
        
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return Scaffold(
            backgroundColor: const Color(0xFF121212),
            appBar: AppBar(
              backgroundColor: const Color(0xFF1A1A1A),
              title: const Text('Detalles del evento', style: TextStyle(color: Colors.white)),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 80, color: errorColor.withOpacity(0.7)),
                  const SizedBox(height: 16),
                  const Text(
                    'No se pudo cargar el evento',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Error: ${snapshot.error ?? "Evento no encontrado"}',
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }
        
        final eventData = snapshot.data!;
        final groupId = eventData['groupId'] as String;

        final title = eventData['title'] as String? ?? 'Evento sin título';
        final amount = eventData['amount'] as double? ?? 0.0;
        final purpose = eventData['purpose'] as String? ?? '';
        final totalCollected = eventData['totalCollected'] as double? ?? 0.0;
        final status = eventData['status'] as String? ?? 'active';
        final List<dynamic> participants = eventData['participants'] ?? [];
        final recipientId = eventData['recipientId'] as String? ?? '';
        final creatorId = eventData['creatorId'] as String? ?? '';
        final createdAt = eventData['createdAt'] as DateTime? ?? DateTime.now();
        final completedAt = eventData['completedAt'] as DateTime?;
        final deadline = eventData['deadline'] as DateTime?;
        final progress = amount > 0 ? (totalCollected / amount) : 0.0;
        
        // Check if current user is the creator
        final currentUser = FirebaseAuth.instance.currentUser;
        final isCreator = currentUser != null && currentUser.uid == creatorId;
        
        // Check if current user has already participated
        final hasParticipated = currentUser != null && participants.any(
          (p) => p['userId'] == currentUser.uid
        );
        
        // Estado de la wallet del usuario
        final walletState = ref.watch(walletControllerProvider);
        
        return Scaffold(
          backgroundColor: const Color(0xFF121212),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1A1A1A),
            title: Text(
              title, 
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            actions: [
              if (kDebugMode) // Solo mostrar en modo debug
                IconButton(
                  icon: const Icon(Icons.bug_report, color: Colors.white),
                  tooltip: 'Menú de diagnóstico',
                  onPressed: () => _showDebugMenu(context, ref, eventData),
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Event card with progress
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: const Color(0xFF1A1A1A),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          purpose,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[300],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Objetivo:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[400],
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '€${amount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                height: 40,
                                width: 1,
                                color: dividerColor,
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Recaudado:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[400],
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '€${totalCollected.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: progress >= 1.0 ? Colors.green : const Color(0xFF3E63A8),
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            backgroundColor: Colors.grey[800],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              progress >= 1.0 ? Colors.green : const Color(0xFF3E63A8),
                            ),
                            minHeight: 10,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(progress * 100).toStringAsFixed(1)}% completado',
                          style: TextStyle(
                            color: progress >= 1.0 ? Colors.green : const Color(0xFF3E63A8),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(
                              'Creado: ${DateFormat('dd/MM/yyyy').format(createdAt)}',
                              style: TextStyle(color: Colors.grey[400]),
                            ),
                          ],
                        ),
                        if (deadline != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.timer, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text(
                                'Fecha límite: ${DateFormat('dd/MM/yyyy HH:mm').format(deadline)}',
                                style: TextStyle(
                                  color: DateTime.now().isAfter(deadline)
                                      ? errorColor
                                      : Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (completedAt != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.check_circle, size: 16, color: Colors.green),
                              const SizedBox(width: 8),
                              Text(
                                'Completado: ${DateFormat('dd/MM/yyyy HH:mm').format(completedAt)}',
                                style: const TextStyle(color: Colors.green),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.person, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(recipientId)
                                  .get(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const Text(
                                    'Cargando destinatario...',
                                    style: TextStyle(color: Colors.grey),
                                  );
                                }
                                
                                final userData = snapshot.data!.data() as Map<String, dynamic>?;
                                final name = userData?['name'] ?? 'Usuario';
                                
                                return Text(
                                  'Destinatario: $name',
                                  style: TextStyle(color: Colors.grey[400]),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: status == 'active'
                                ? Colors.green.withOpacity(0.2)
                                : Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                status == 'active'
                                    ? Icons.check_circle
                                    : Icons.flag,
                                color: status == 'active'
                                    ? Colors.green
                                    : Colors.grey,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                status == 'active'
                                    ? 'Activo'
                                    : 'Finalizado',
                                style: TextStyle(
                                  color: status == 'active'
                                      ? Colors.green
                                      : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Mostrar estado de la wallet del usuario
                walletState.when(
                  data: (wallet) {
                    if (wallet == null) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: errorColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: errorColor.withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: errorColor),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Necesitas crear una wallet para participar en eventos',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      );
                    } else {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.account_balance_wallet, color: const Color(0xFF3E63A8)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Saldo disponible: €${wallet.balance.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  loading: () => Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Cargando información de wallet...',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  error: (_, __) => Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: errorColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: errorColor.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: errorColor),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Error al cargar información de wallet',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Action buttons
                if (status == 'active') ...[
                  if (!hasParticipated)
                    ElevatedButton.icon(
                      onPressed: () => _showContributeDialog(context, ref, eventId, groupId),
                      icon: const Icon(Icons.attach_money),
                      label: const Text('CONTRIBUIR'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3E63A8),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  
                  if (isCreator)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: OutlinedButton.icon(
                        onPressed: () => _showFinalizeDialog(context, ref, eventId),
                        icon: const Icon(Icons.check_circle),
                        label: const Text('FINALIZAR EVENTO'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white),
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                ],
                
                const SizedBox(height: 24),
                
                // Participants
                const Text(
                  'Participantes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                if (participants.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 48,
                          color: Colors.grey[700],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Aún no hay participantes',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                else
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: const Color(0xFF1A1A1A),
                    child: Column(
                      children: [
                        // Cabecera de la tabla
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          child: Row(
                            children: [
                              const Expanded(
                                flex: 3,
                                child: Text(
                                  'Participante',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Contribución',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Separador
                        Divider(color: dividerColor, height: 1),
                        
                        // Lista de participantes
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: participants.length,
                          itemBuilder: (context, index) {
                            final participant = participants[index];
                            final userId = participant['userId'];
                            final contribution = participant['contribution'] ?? 0.0;
                            final timestamp = participant['timestamp'];
                            
                            // Formatear fecha si está disponible
                            String dateStr = '';
                            if (timestamp != null) {
                              final date = timestamp is Timestamp 
                                  ? timestamp.toDate() 
                                  : (timestamp is DateTime ? timestamp : null);
                              
                              if (date != null) {
                                dateStr = DateFormat('dd/MM/yyyy HH:mm').format(date);
                              }
                            }
                            
                            return FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(userId)
                                  .get(),
                              builder: (context, snapshot) {
                                String name = 'Cargando...';
                                String profilePic = '';
                                
                                if (snapshot.hasData && snapshot.data != null) {
                                  final userData = snapshot.data!.data() as Map<String, dynamic>?;
                                  if (userData != null) {
                                    name = userData['name'] ?? 'Usuario';
                                    profilePic = userData['profilePic'] as String? ?? '';
                                  }
                                }
                                
                                return Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12, 
                                        horizontal: 16,
                                      ),
                                      child: Row(
                                        children: [
                                          // Avatar
                                          CircleAvatar(
                                            backgroundImage: profilePic.isNotEmpty
                                                ? NetworkImage(profilePic)
                                                : null,
                                            radius: 20,
                                            backgroundColor: profilePic.isEmpty
                                                ? const Color(0xFF3E63A8).withOpacity(0.7)
                                                : null,
                                            child: profilePic.isEmpty
                                                ? Text(
                                                    name[0].toUpperCase(),
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(width: 12),
                                          
                                          // Información del participante
                                          Expanded(
                                            flex: 3,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  name,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                if (dateStr.isNotEmpty) ...[
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    dateStr,
                                                    style: TextStyle(
                                                      color: Colors.grey[500],
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          
                                          // Contribución
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              '€${contribution.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                color: Color(0xFF3E63A8),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                              textAlign: TextAlign.right,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    // Separador (excepto en el último elemento)
                                    if (index < participants.length - 1)
                                      Divider(color: dividerColor, height: 1),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                        
                        // Resumen
                        Divider(color: dividerColor, height: 1),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total recaudado:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '€${totalCollected.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Color(0xFF3E63A8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                // Botón de debug en modo desarrollo
                if (kDebugMode)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.bug_report, size: 16),
                      label: const Text('Menú de Diagnóstico'),
                      onPressed: () => _showDebugMenu(context, ref, eventData),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey[400]!),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  // Método de contribución con integración a wallet
  void _showContributeDialog(
    BuildContext context,
    WidgetRef ref,
    String eventId,
    String groupId,
  ) {
    final amountController = TextEditingController();
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Contribuir al Evento',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Ingresa el monto con el que deseas contribuir:',
                  style: TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: containerColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: dividerColor),
                  ),
                  child: TextField(
                    controller: amountController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Monto (€)',
                      labelStyle: TextStyle(color: Colors.grey[400]),
                      border: InputBorder.none,
                      prefixIcon: Icon(
                        Icons.euro,
                        color: const Color(0xFF3E63A8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    enabled: !isProcessing,
                  ),
                ),
                if (isProcessing) ...[
                  const SizedBox(height: 16),
                  const Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 8),
                        Text(
                          'Procesando contribución...',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: isProcessing ? null : () => Navigator.pop(dialogContext), 
                      child: Text(
                        'Cancelar',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: isProcessing ? null : () async {
                        final amount = double.tryParse(amountController.text.trim().replaceAll(',', '.')) ?? 0;
                        if (amount <= 0) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                              content: Text('Ingresa un monto válido'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }
                        
                        setState(() => isProcessing = true);
                        
                        // Verificar si el usuario tiene suficiente saldo
                        final walletState = ref.read(walletControllerProvider);
                        if (walletState is AsyncData) {
                          final wallet = walletState.value;
                          if (wallet == null) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(
                                  content: Text('No tienes una wallet activa'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                            setState(() => isProcessing = false);
                            return;
                          }
                          
                          if (wallet.balance < amount) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(
                                  content: Text('Saldo insuficiente'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                            setState(() => isProcessing = false);
                            return;
                          }
                        }
                        
                        try {
                          final success = await ref.read(recordFundsControllerProvider).participateInEvent(
                            context: dialogContext,
                            groupId: groupId,
                            eventId: eventId,
                            contribution: amount,
                          );
                          
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          
                          if (success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Has contribuido €${amount.toStringAsFixed(2)} al evento'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('No se pudo completar la contribución'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } catch (e) {
                          print('Error al contribuir: $e');
                          setState(() => isProcessing = false);
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3E63A8),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Contribuir'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  void _showFinalizeDialog(BuildContext context, WidgetRef ref, String eventId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Finalizar Evento',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          '¿Estás seguro de que deseas finalizar este evento? Esta acción marcará el evento como completado y no podrá deshacerse.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3E63A8),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              
              final success = await ref.read(recordFundsControllerProvider).finalizeEvent(
                context: context,
                eventId: eventId,
              );
              
              if (success) {
                Navigator.pop(context); // Close event details page
              }
            },
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
  }
  
  // Método para añadir fondos de debug
  Future<void> _addDebugFunds(BuildContext context, String userId) async {
    try {
      // Verificar si la wallet existe
      final walletDoc = await FirebaseFirestore.instance.collection('wallets').doc(userId).get();
                    
      if (!walletDoc.exists) {
        // Crear wallet si no existe
        await FirebaseFirestore.instance.collection('wallets').doc(userId).set({
          'userId': userId,
          'balance': 50.0,
          'kycCompleted': false,
          'kycStatus': 'pending',
          'accountStatus': 'pending',
          'transactions': [
            {
              'id': const Uuid().v1(),
              'amount': 50.0,
              'senderId': 'debug_add',
              'receiverId': userId,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
              'type': 'debug_add',
            }
          ],
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Actualizar wallet existente
        await FirebaseFirestore.instance.collection('wallets').doc(userId).update({
          'balance': FieldValue.increment(50.0),
          'transactions': FieldValue.arrayUnion([
            {
              'id': const Uuid().v1(),
              'amount': 50.0,
              'senderId': 'debug_add',
              'receiverId': userId,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
              'type': 'debug_add',
            }
          ]),
        });
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Se han añadido €50 a tu wallet'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error al añadir fondos de debug: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: errorColor,
        ),
      );
    }
  }
  
  // Menú de diagnóstico
  void _showDebugMenu(BuildContext context, WidgetRef ref, Map<String, dynamic> eventData) {
    final recipientId = eventData['recipientId'] as String? ?? '';
    final creatorId = eventData['creatorId'] as String? ?? '';
    final List<dynamic> participants = eventData['participants'] ?? [];
    final currentUser = FirebaseAuth.instance.currentUser;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Menú de Diagnóstico',
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Este menú te permite diagnosticar y solucionar problemas con las wallets y transacciones.', 
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              
              const Text(
                'Verificar Wallets:', 
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              
              // Opción para verificar la wallet del creador
              _buildDebugOption(
                context: context,
                icon: Icons.person_outline,
                title: 'Verificar wallet del creador',
                subtitle: 'ID: ${_truncateId(creatorId)}',
                onTap: () {
                  Navigator.pop(context);
                  ref.read(recordFundsControllerProvider).checkAndCreateWallet(
                    context: context,
                    userId: creatorId,
                  );
                },
              ),
              
              // Opción para verificar la wallet del destinatario
              _buildDebugOption(
                context: context,
                icon: Icons.person,
                title: 'Verificar wallet del destinatario',
                subtitle: 'ID: ${_truncateId(recipientId)}',
                onTap: () {
                  Navigator.pop(context);
                  ref.read(recordFundsControllerProvider).checkAndCreateWallet(
                    context: context,
                    userId: recipientId,
                  );
                },
              ),
              
              // Opción para verificar mi wallet
              if (currentUser != null)
                _buildDebugOption(
                  context: context,
                  icon: Icons.account_circle,
                  title: 'Verificar mi wallet',
                  subtitle: 'ID: ${_truncateId(currentUser.uid)}',
                  onTap: () {
                    Navigator.pop(context);
                    ref.read(recordFundsControllerProvider).checkAndCreateWallet(
                      context: context,
                      userId: currentUser.uid,
                    );
                  },
                ),
              
              const Divider(height: 30, color: dividerColor),
              
              const Text(
                'Acciones Avanzadas:', 
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              
              // Opción para verificar todas las wallets del evento
              _buildDebugOption(
                context: context,
                icon: Icons.group_work,
                title: 'Verificar todas las wallets del evento',
                subtitle: 'Crea wallets faltantes si es necesario',
                onTap: () {
                  Navigator.pop(context);
                  ref.read(recordFundsControllerProvider).checkEventWallets(
                    context: context,
                    eventId: eventData['eventId'],
                  );
                },
              ),
              
              // Opción para añadir €50 a mi wallet (debug)
              if (currentUser != null)
                _buildDebugOption(
                  context: context,
                  icon: Icons.attach_money,
                  title: 'Añadir €50 a mi wallet (Debug)',
                  subtitle: 'Para pruebas de contribución',
                  onTap: () async {
                    Navigator.pop(context);
                    await _addDebugFunds(context, currentUser.uid);
                  },
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Helper para construir las opciones del menú
  Widget _buildDebugOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF3E63A8), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title, 
                    style: const TextStyle(
                      fontWeight: FontWeight.w500, 
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    subtitle, 
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // Helper para truncar IDs largos
  String _truncateId(String id) {
    if (id.length <= 10) return id;
    return '${id.substring(0, 5)}...${id.substring(id.length - 5)}';
  }
}
