// lib/config/emoji_config.dart

import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as emoji_picker;

class EmojiConfig {
  /// Devuelve una configuración completa para EmojiPicker.
  static emoji_picker.Config getConfig() => emoji_picker.Config(
        // Configuración del grid de emojis
        emojiViewConfig: const emoji_picker.EmojiViewConfig(
          columns: 8,
          emojiSizeMax: 28.0,
          backgroundColor: Color(0xFF121212),
          verticalSpacing: 0,
          horizontalSpacing: 0,
          recentsLimit: 28,
          noRecents: Text(
            'No Recents',
            style: TextStyle(fontSize: 20, color: Colors.white),
            textAlign: TextAlign.center,
          ),
          loadingIndicator: SizedBox.shrink(),
          buttonMode: emoji_picker.ButtonMode.MATERIAL,
        ),

        // Configuración de la barra de categorías
        categoryViewConfig: emoji_picker.CategoryViewConfig(
          initCategory: emoji_picker.Category.RECENT,
          tabIndicatorAnimDuration: kTabScrollDuration,
          backgroundColor: const Color(0xFF121212),
          indicatorColor: const Color(0xFF3E63A8),
          iconColor: Colors.grey,
          iconColorSelected: const Color(0xFF3E63A8),
          backspaceColor: const Color(0xFF3E63A8),
          categoryIcons: const emoji_picker.CategoryIcons(),
        ),

        // Configuración de tonos de piel
        skinToneConfig: const emoji_picker.SkinToneConfig(
          enabled: true,
          dialogBackgroundColor: Color(0xFF2A2A2F),
          indicatorColor: Colors.white,
        ),

        // Botones de la barra inferior (backspace y búsqueda)
        bottomActionBarConfig: const emoji_picker.BottomActionBarConfig(
          showBackspaceButton: true,
          showSearchViewButton: true,
          backgroundColor: Color(0xFF121212),
          buttonIconColor: Colors.white,
        ),

        // Configuración de la vista de búsqueda
        searchViewConfig: const emoji_picker.SearchViewConfig(),
      );
}
