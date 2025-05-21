import 'package:flutter/material.dart';
import 'package:swipe_to/swipe_to.dart';
import 'package:intl/intl.dart';
import 'package:mk_mesenger/common/enums/message_enum.dart';
import 'package:mk_mesenger/common/utils/colors.dart';
import 'package:mk_mesenger/feature/chat/widgets/dsiplay_text_image_gif.dart';

class MyMessageCard extends StatelessWidget {
  final String message;
  final DateTime timeSent;
  final MessageEnum type;
  final VoidCallback onSwipeRight;
  final String repliedText;
  final String repliedBy;
  final MessageEnum repliedType;
  final bool isSeen;

  const MyMessageCard({
    Key? key,
    required this.message,
    required this.timeSent,
    required this.type,
    required this.onSwipeRight,
    required this.repliedText,
    required this.repliedBy,
    required this.repliedType,
    required this.isSeen,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isReplying = repliedText.isNotEmpty;
    final timeString = DateFormat.Hm().format(timeSent);

    return SwipeTo(
      onRightSwipe: (_) => onSwipeRight(),
      child: Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Color(0xFF3E63A8),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(4),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isReplying) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            repliedBy, 
                            style: const TextStyle(
                              fontWeight: FontWeight.bold, 
                              color: Colors.white,
                              fontSize: 12,
                            )
                          ),
                          const SizedBox(height: 4),
                          DisplayTextImageGIF(message: repliedText, type: repliedType),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  DisplayTextImageGIF(message: message, type: type),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeString, 
                        style: TextStyle(
                          fontSize: 11, 
                          color: Colors.white.withOpacity(0.7)
                        )
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        isSeen ? Icons.done_all : Icons.done,
                        size: 14,
                        color: isSeen ? Colors.white : Colors.white.withOpacity(0.5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
