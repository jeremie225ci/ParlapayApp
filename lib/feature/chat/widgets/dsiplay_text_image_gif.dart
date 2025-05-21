import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:mk_mesenger/common/enums/message_enum.dart';

class DisplayTextImageGIF extends StatefulWidget {
  final String message;
  final MessageEnum type;

  const DisplayTextImageGIF({
    super.key,
    required this.message,
    required this.type,
  });

  @override
  State<DisplayTextImageGIF> createState() => _DisplayTextImageGIFState();
}

class _DisplayTextImageGIFState extends State<DisplayTextImageGIF> {
  final AudioPlayer audioPlayer = AudioPlayer();
  bool isPlaying = false;

  @override
  Widget build(BuildContext context) {
    switch (widget.type) {
      case MessageEnum.text:
        return Text(
          widget.message,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
          ),
        );
      case MessageEnum.image:
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            widget.message,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                        : null,
                    color: Color(0xFF3E63A8),
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, color: Colors.red, size: 40),
                    SizedBox(height: 8),
                    Text(
                      'Error al cargar imagen',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      case MessageEnum.audio:
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () async {
                  if (isPlaying) {
                    await audioPlayer.pause();
                  } else {
                    await audioPlayer.play(UrlSource(widget.message));
                  }
                  setState(() => isPlaying = !isPlaying);
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(0xFF3E63A8),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Nota de voz',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    isPlaying ? 'Reproduciendo...' : 'Toca para reproducir',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      case MessageEnum.gif:
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            widget.message,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                        : null,
                    color: Color(0xFF3E63A8),
                  ),
                ),
              );
            },
          ),
        );
      case MessageEnum.video:
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(0xFF3E63A8),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Video',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Toca para reproducir',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      case MessageEnum.money:
        // Extraer el monto de la cadena (formato esperado: "€10.0" o similar)
        final amountMatch = RegExp(r'€(\d+(?:\.\d+)?)').firstMatch(widget.message);
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
                widget.message,
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
                      color: Colors.green,
                    ),
                  ),
                ),
            ],
          ),
        );
      default:
        return Text(
          widget.message,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
          ),
        );
    }
  }
}
