import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:mk_mesenger/common/enums/message_enum.dart';
import 'package:mk_mesenger/feature/chat/widgets/Video_payer_item.dart';
import 'package:mk_mesenger/feature/group/widgets/EventDetailsScreen.dart';

/// Versión específica para grupos del widget DisplayTextImageGIF
/// No requiere el parámetro isSender
class DisplayTextImageGIFGroup extends StatelessWidget {
  final String message;
  final MessageEnum type;
  
  const DisplayTextImageGIFGroup({
    Key? key,
    required this.message,
    required this.type,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case MessageEnum.text:
        return Text(
          message,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white, // Cambiado a blanco para el tema oscuro
          ),
        );
      
      case MessageEnum.image:
        return CachedNetworkImage(
          imageUrl: message,
        );
      
      case MessageEnum.video:
        return VideoPlayerItem(
          videoUrl: message,
        );
      
      case MessageEnum.gif:
        return CachedNetworkImage(
          imageUrl: message,
        );
      
      case MessageEnum.audio:
        return _buildAudioMessage();
      
      case MessageEnum.money:
        return _buildMoneyMessage();
        
      case MessageEnum.eventNotification:
        return _buildEventNotification(context);
        
      case MessageEnum.eventContribution:
        return _buildEventContribution(context);
        
      case MessageEnum.eventCompleted:
        return _buildEventCompleted(context);
        
      case MessageEnum.marketplaceNotification:
        return _buildMarketplaceNotification();
      
      default:
        return Text(
          message,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
          ),
        );
    }
  }

  Widget _buildAudioMessage() {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              final player = AudioPlayer();
              player.play(UrlSource(message));
            },
            icon: const Icon(Icons.play_arrow),
            color: Colors.white,
          ),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: 8),
              child: Text(
                'Audio Message',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoneyMessage() {
    // Extraer el monto de la cadena (formato esperado: "€10.0" o similar)
    final amountMatch = RegExp(r'€(\d+(?:\.\d+)?)').firstMatch(message);
    final amount = amountMatch != null ? amountMatch.group(1) : '';
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.payments_outlined,
                color: Colors.green,
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                'Transferencia',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.white,
            ),
          ),
          if (amount != null && amount.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '€$amount',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[300],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEventNotification(BuildContext context) {
    // Extraer ID del evento del mensaje
    final eventIdMatch = RegExp(r'eventId:([a-f0-9-]+)').firstMatch(message);
    final eventId = eventIdMatch?.group(1);
    
    return GestureDetector(
      onTap: eventId != null ? () => _navigateToEvent(context, eventId) : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.event,
                  color: Colors.blue,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Evento',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              // Limpiar el eventId del mensaje mostrado
              eventId != null 
                  ? message.replaceAll(' - eventId:$eventId', '')
                  : message,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.white,
              ),
            ),
            if (eventId != null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Toca para ver detalles',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.blue,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventContribution(BuildContext context) {
    // Extraer ID del evento del mensaje
    final eventIdMatch = RegExp(r'eventId:([a-f0-9-]+)').firstMatch(message);
    final eventId = eventIdMatch?.group(1);
    
    return GestureDetector(
      onTap: eventId != null ? () => _navigateToEvent(context, eventId) : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.purple.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.purple.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.volunteer_activism,
                  color: Colors.purple,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Contribución',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              // Limpiar el eventId del mensaje mostrado
              eventId != null 
                  ? message.replaceAll(' - eventId:$eventId', '')
                  : message,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.white,
              ),
            ),
            if (eventId != null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Toca para ver detalles',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.purple,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCompleted(BuildContext context) {
    // Extraer ID del evento del mensaje
    final eventIdMatch = RegExp(r'eventId:([a-f0-9-]+)').firstMatch(message);
    final eventId = eventIdMatch?.group(1);
    
    return GestureDetector(
      onTap: eventId != null ? () => _navigateToEvent(context, eventId) : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Evento completado',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              // Limpiar el eventId del mensaje mostrado
              eventId != null 
                  ? message.replaceAll(' - eventId:$eventId', '')
                  : message,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.white,
              ),
            ),
            if (eventId != null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Toca para ver detalles',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.green,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketplaceNotification() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.shopping_bag,
                color: Colors.orange,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Mercado',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
  
  // Método para navegar a la pantalla de detalles del evento
  void _navigateToEvent(BuildContext context, String eventId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventDetailsScreen(eventId: eventId),
      ),
    );
  }
}