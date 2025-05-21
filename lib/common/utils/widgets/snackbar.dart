// lib/common/utils/widgets/snackbar.dart
import 'package:flutter/material.dart';

/// Muestra un SnackBar con estilo estándar
void showSnackBar({
  required BuildContext context,
  required String content,
  Duration duration = const Duration(seconds: 3),
}) {
  final snackBar = SnackBar(
    content: Text(content),
    duration: duration,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  );
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}