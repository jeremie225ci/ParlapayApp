import 'package:flutter/material.dart';

/// Color palette aligned with the ParlaPay logo (black & white)

/// Background of most screens
const Color backgroundColor = Color(0xFF1A1E2E);

/// Primary text and icons
const Color textColor = Colors.white;

/// AppBar and BottomNavigation backgrounds
const Color appBarColor = Color(0xFF252A3F);
const Color bottomNavColor = Color(0xFF252A3F);

/// Selected / unselected item colors in BottomNavigation
const Color selectedItemColor = Color(0xFF3E63A8);
const Color unselectedItemColor = Colors.grey;

/// Accent for FAB, buttons, highlights
const Color accentColor = Color(0xFF3E63A8);

/// Message bubbles
/// Outgoing messages (me)
const Color senderMessageColor = Color(0xFF3E63A8);
/// Incoming messages (others)
const Color receiverMessageColor = Color(0xFF252A3F);

/// Default bubble backgrounds (with slight tint)
const Color senderBubbleColor = Color(0xFF3E63A8);
const Color receiverBubbleColor = Color(0xFF252A3F);

/// TextField / chat input container
const Color chatBoxColor = Color(0xFF252A3F);

/// Dividers, borders
const Color dividerColor = Color(0xFF3E63A8);

/// Example additional colors
const Color errorColor = Colors.red;
const Color successColor = Colors.green;

/// Gradient colors
const List<Color> backgroundGradient = [
  Color(0xFF0F1729),
  Color(0xFF1A2540),
];

/// Card and container backgrounds
const Color cardColor = Color(0xFF252A3F);
const Color containerColor = Color(0xFF1E2235);

/// Input field background
const Color inputBackgroundColor = Color(0xFF252A3F);
const Color inputBorderColor = Color(0xFF3A4366);

/// Status colors
const Color onlineStatusColor = Colors.green;
const Color offlineStatusColor = Colors.grey;

/// Money transfer colors
const Color moneyTransferColor = Color(0xFF4CAF50);
const Color moneyReceiveColor = Color(0xFF3E63A8);

/// Attachment menu colors
const Map<String, Color> attachmentColors = {
  'image': Color(0xFF4CAF50),
  'video': Color(0xFFF44336),
  'gif': Color(0xFF9C27B0),
  'money': Color(0xFF3E63A8),
  'file': Color(0xFFFF9800),
  'location': Color(0xFF2196F3),
};
