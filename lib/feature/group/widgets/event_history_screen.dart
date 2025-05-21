import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mk_mesenger/common/utils/colors.dart';
import 'package:mk_mesenger/common/utils/widgets/loader.dart';
import 'package:mk_mesenger/feature/group/widgets/EventDetailsScreen.dart';
import 'package:mk_mesenger/feature/group/widgets/record_funds_tab.dart';

class EventHistoryScreen extends ConsumerWidget {
  final String groupId;

  const EventHistoryScreen({
    Key? key,
    required this.groupId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completedEventsStream = ref.read(recordFundsControllerProvider).getGroupCompletedEvents(groupId);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        title: const Text(
          'Historial de Eventos',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: completedEventsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Loader();
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.white),
              ),
            );
          }

          final events = snapshot.data;
          if (events == null || events.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: containerColor.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.history,
                      size: 64,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No hay eventos completados',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Los eventos completados aparecerán aquí',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            );
          }

          // Agrupar eventos por mes y año
          final groupedEvents = _groupEventsByMonth(events);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Resumen general
                Card(
                  elevation: 2,
                  color: cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          'Total de eventos completados: ${events.length}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildSummaryItem(
                              icon: Icons.attach_money,
                              title: 'Total recaudado',
                              value: '€${_calculateTotalCollected(events).toStringAsFixed(2)}',
                              color: Colors.green,
                            ),
                            Container(
                              height: 40,
                              width: 1,
                              color: dividerColor,
                            ),
                            _buildSummaryItem(
                              icon: Icons.people,
                              title: 'Participaciones',
                              value: _calculateTotalParticipations(events).toString(),
                              color: accentColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Lista de eventos por mes
                ...groupedEvents.entries.map((entry) {
                  final monthYearStr = entry.key;
                  final monthEvents = entry.value;
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 8),
                        child: Text(
                          monthYearStr,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: accentColor,
                          ),
                        ),
                      ),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: monthEvents.length,
                        itemBuilder: (context, index) {
                          return _buildEventCard(context, monthEvents[index]);
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                }).toList(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[400],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, Map<String, dynamic> event) {
    final title = event['title'] ?? 'Evento sin título';
    final amount = event['amount'] ?? 0.0;
    final totalCollected = event['totalCollected'] ?? 0.0;
    final progress = amount > 0 ? (totalCollected / amount) : 0.0;
    final completedAt = event['completedAt'] as DateTime? ?? DateTime.now();
    final participants = event['participants'] as List<dynamic>? ?? [];
    final recipientId = event['recipientId'] as String?;
    final eventId = event['eventId'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (eventId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EventDetailsScreen(eventId: eventId),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado con título y fecha
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      DateFormat('dd/MM/yyyy').format(completedAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Barra de progreso
              LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: Colors.grey[800],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 8),

              // Detalles de recaudación
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '€${totalCollected.toStringAsFixed(2)} / €${amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: progress >= 1.0 ? Colors.green : accentColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Información adicional
              Divider(color: dividerColor, height: 1),
              const SizedBox(height: 12),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Información del destinatario
                  if (recipientId != null)
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(recipientId)
                          .get(),
                      builder: (context, snapshot) {
                        String recipientName = 'Destinatario';
                        if (snapshot.hasData && snapshot.data != null) {
                          final userData = snapshot.data!.data() as Map<String, dynamic>?;
                          if (userData != null) {
                            recipientName = userData['name'] ?? 'Usuario';
                          }
                        }
                        return Row(
                          children: [
                            const Icon(
                              Icons.person,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              recipientName,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        );
                      },
                    )
                  else
                    const SizedBox(),
                    
                  // Número de participantes
                  Row(
                    children: [
                      const Icon(
                        Icons.people,
                        size: 14,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${participants.length} participantes',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[400],
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

  Map<String, List<Map<String, dynamic>>> _groupEventsByMonth(List<Map<String, dynamic>> events) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    
    for (final event in events) {
      final completedAt = event['completedAt'] as DateTime? ?? DateTime.now();
      final monthYearStr = DateFormat('MMMM yyyy').format(completedAt);
      
      if (!grouped.containsKey(monthYearStr)) {
        grouped[monthYearStr] = [];
      }
      
      grouped[monthYearStr]!.add(event);
    }
    
    // Ordenar las claves por fecha (más reciente primero)
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        final dateA = DateFormat('MMMM yyyy').parse(a);
        final dateB = DateFormat('MMMM yyyy').parse(b);
        return dateB.compareTo(dateA);
      });
    
    // Reconstruir el mapa ordenado
    final orderedGrouped = <String, List<Map<String, dynamic>>>{};
    for (final key in sortedKeys) {
      orderedGrouped[key] = grouped[key]!;
    }
    
    return orderedGrouped;
  }

  double _calculateTotalCollected(List<Map<String, dynamic>> events) {
    double total = 0.0;
    for (final event in events) {
      total += (event['totalCollected'] as num?)?.toDouble() ?? 0.0;
    }
    return total;
  }

  int _calculateTotalParticipations(List<Map<String, dynamic>> events) {
    int total = 0;
    for (final event in events) {
      final participants = event['participants'] as List<dynamic>? ?? [];
      total += participants.length;
    }
    return total;
  }
}