import 'dart:io';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sound_record/flutter_sound_record.dart';
import 'package:mk_mesenger/config/emoji_config.dart';
import 'package:mk_mesenger/feature/chat/controller/chat_controller.dart';
import 'package:mk_mesenger/feature/chat/widgets/message_reply_preview.dart';
import 'package:mk_mesenger/common/enums/message_enum.dart';
import 'package:mk_mesenger/common/providers/message_reply_provider.dart';
import 'package:mk_mesenger/common/utils/utils.dart';
import 'package:mk_mesenger/feature/group/widgets/record_funds_tab.dart';
import 'package:mk_mesenger/feature/group/widgets/marketplace_tabs.dart';
import 'package:mk_mesenger/common/utils/colors.dart';
import 'package:path_provider/path_provider.dart';

// Enumeración para los tipos de pestañas
enum GroupTabType {
  chat,
  events,
  marketplace,
}

class BottomChatFieldGroup extends ConsumerStatefulWidget {
  final String groupId;

  const BottomChatFieldGroup({
    Key? key,
    required this.groupId,
  }) : super(key: key);

  @override
  ConsumerState<BottomChatFieldGroup> createState() => _BottomChatFieldGroupState();
}

class _BottomChatFieldGroupState extends ConsumerState<BottomChatFieldGroup> with SingleTickerProviderStateMixin {
  bool isShowSendButton = false;
  final TextEditingController _messageController = TextEditingController();
  FlutterSoundRecord? _soundRecorder;
  bool isRecorderInit = false;
  bool isShowEmojiContainer = false;
  bool isRecording = false;
  bool isShowAttachments = false;
  FocusNode focusNode = FocusNode();
  late AnimationController _attachmentController;
  late Animation<double> _attachmentAnimation;
  
  // Pestaña activa
  GroupTabType _activeTab = GroupTabType.chat;

  @override
  void initState() {
    super.initState();
    _soundRecorder = FlutterSoundRecord();
    isRecorderInit = true;
    _attachmentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _attachmentAnimation = CurvedAnimation(
      parent: _attachmentController,
      curve: Curves.easeInOut,
    );
    
    // Listener para ajustar altura del campo de texto
    _messageController.addListener(_updateTextFieldHeight);
  }

  void _updateTextFieldHeight() {
    setState(() {
      isShowSendButton = _messageController.text.isNotEmpty;
    });
  }

  Future<void> sendTextMessage() async {
    if (isShowSendButton) {
      ref.read(chatControllerProvider).sendTextMessage(
        context,
        _messageController.text.trim(),
        widget.groupId,
        true, // isGroupChat
      );
      _messageController.clear();
    } else {
      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/flutter_sound.aac';
      if (!isRecorderInit) return;
      if (isRecording) {
        await _soundRecorder!.stop();
        sendFileMessage(File(path), MessageEnum.audio);
      } else {
        await _soundRecorder!.start(path: path);
      }
      setState(() => isRecording = !isRecording);
    }
    setState(() => isShowSendButton = false);
  }

  void sendFileMessage(File file, MessageEnum messageEnum) {
    ref.read(chatControllerProvider).sendFileMessage(
      context,
      file,
      widget.groupId,
      messageEnum,
      true, // isGroupChat
    );
  }

  Future<void> selectImage() async {
    final image = await pickImageFromGallery(context);
    if (image != null) sendFileMessage(image, MessageEnum.image);
  }

  Future<void> selectVideo() async {
    final video = await pickVideoFromGallery(context);
    if (video != null) sendFileMessage(video, MessageEnum.video);
  }

  Future<void> selectGIF() async {
    final gif = await pickGIF(context);
    if (gif != null) {
      final url = gif.images?.original?.url ?? '';
      ref.read(chatControllerProvider).sendGIFMessage(
        context,
        url,
        widget.groupId,
        true, // isGroupChat
      );
    }
  }

  void toggleEmojiKeyboard() {
    if (isShowEmojiContainer) {
      focusNode.requestFocus();
      setState(() => isShowEmojiContainer = false);
    } else {
      focusNode.unfocus();
      setState(() => isShowEmojiContainer = true);
    }
  }

  void toggleAttachments() {
    setState(() {
      isShowAttachments = !isShowAttachments;
      if (isShowAttachments) {
        _attachmentController.forward();
      } else {
        _attachmentController.reverse();
      }
    });
  }

  void _setActiveTab(GroupTabType tabType) {
    if (_activeTab != tabType) {
      setState(() {
        _activeTab = tabType;
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _soundRecorder?.dispose();
    _attachmentController.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messageReply = ref.watch(messageReplyProvider);

    // Si no estamos en la pestaña de chat, mostrar el contenido correspondiente
    if (_activeTab != GroupTabType.chat) {
      return _buildActiveTabContent();
    }

    return Container(
      decoration: BoxDecoration(
        color: containerColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          if (messageReply != null) const MessageReplyPreview(),
          
          // Contenedor de adjuntos expandible
          SizeTransition(
            sizeFactor: _attachmentAnimation,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: cardColor,
                border: Border(
                  top: BorderSide(color: accentColor, width: 0.5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildAttachmentButton(
                    icon: Icons.image,
                    label: 'Imagen',
                    color: Colors.green,
                    onTap: selectImage,
                  ),
                  _buildAttachmentButton(
                    icon: Icons.videocam,
                    label: 'Video',
                    color: Colors.red,
                    onTap: selectVideo,
                  ),
                  _buildAttachmentButton(
                    icon: Icons.gif,
                    label: 'GIF',
                    color: Colors.purple,
                    onTap: selectGIF,
                  ),
                ],
              ),
            ),
          ),
          
          // Campo de chat principal
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Botón de adjuntos
                Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: IconButton(
                    icon: Icon(
                      isShowAttachments ? Icons.close : Icons.add,
                      color: accentColor,
                    ),
                    onPressed: toggleAttachments,
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Campo de texto expandible
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Row(
                      children: [
                        // Botón de emoji
                        IconButton(
                          icon: Icon(
                            isShowEmojiContainer 
                                ? Icons.keyboard 
                                : Icons.emoji_emotions,
                            color: accentColor,
                          ),
                          onPressed: toggleEmojiKeyboard,
                        ),
                        
                        // Campo de texto
                        Expanded(
                          child: TextField(
                            focusNode: focusNode,
                            controller: _messageController,
                            onChanged: (val) {
                              setState(() => isShowSendButton = val.isNotEmpty);
                            },
                            style: const TextStyle(color: Colors.white),
                            maxLines: 5,
                            minLines: 1,
                            decoration: InputDecoration(
                              hintText: 'Escribe un mensaje...',
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Botón de enviar/micrófono
                Container(
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: IconButton(
                    icon: Icon(
                      isRecording
                          ? Icons.close
                          : isShowSendButton
                              ? Icons.send
                              : Icons.mic,
                      color: Colors.white,
                    ),
                    onPressed: sendTextMessage,
                  ),
                ),
              ],
            ),
          ),
          
          // Barra de navegación (Chat, Evento, Mercado)
      
          
          // Selector de emojis
          if (isShowEmojiContainer)
            SizedBox(
              height: 250,
              child: EmojiPicker(
                onEmojiSelected: ((category, emoji) {
                  _messageController.text = _messageController.text + emoji.emoji;
                  setState(() => isShowSendButton = true);
                }),
                config: EmojiConfig.getConfig(),
              ),
            ),
        ],
      ),
    );
  }

  

  Widget _buildTabButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? accentColor : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isActive ? accentColor : unselectedItemColor,
                size: 20,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? accentColor : unselectedItemColor,
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTabContent() {
    switch (_activeTab) {
      case GroupTabType.events:
        return Container(
          height: 400, // Altura ajustable según necesidades
          child: Column(
            children: [
              // Mantener la barra de navegación
              Expanded(
                child: RecordFundsTab(groupId: widget.groupId),
              ),
            ],
          ),
        );
      case GroupTabType.marketplace:
        return Container(
          height: 400, // Altura ajustable según necesidades
          child: Column(
            children: [
               // Mantener la barra de navegación
              Expanded(
                child: MarketplaceTab(groupId: widget.groupId),
              ),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildAttachmentButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}