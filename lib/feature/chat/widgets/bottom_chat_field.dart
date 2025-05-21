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
import 'package:mk_mesenger/feature/wallet/controller/wallet_controller.dart';
import 'package:mk_mesenger/feature/wallet/screens/simple_kyc_screen.dart';
import 'package:path_provider/path_provider.dart';

class BottomChatField extends ConsumerStatefulWidget {
  final String recieverUserId;
  final bool isGroupChat;

  const BottomChatField({
    Key? key,
    required this.recieverUserId,
    required this.isGroupChat,
  }) : super(key: key);

  @override
  ConsumerState<BottomChatField> createState() => _BottomChatFieldState();
}

class _BottomChatFieldState extends ConsumerState<BottomChatField> with SingleTickerProviderStateMixin {
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
      // El estado cambia cuando el texto cambia, lo que hace que el TextField se redibuje
      isShowSendButton = _messageController.text.isNotEmpty;
    });
  }

  Future<void> handleSendMoney() async {
    try {
      final walletState = ref.read(walletControllerProvider);
      
      // Esperamos a que el estado asíncrono se resuelva
      if (walletState is AsyncLoading) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cargando información de wallet...'))
        );
        return;
      }
      
      // Manejamos error o wallet null
      if (walletState is AsyncError || walletState.value == null) {
        if (!mounted) return;
        Navigator.pushNamed(context, KYCScreen.routeName);
        return;
      }
      
      // Si todo está bien, mostramos el diálogo
      _showSendMoneyDialog();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'))
      );
    }
  }

  void _showSendMoneyDialog() {
    final amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Enviar Dinero', 
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold
          )
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Monto en €',
                hintStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: const Color(0xFF252A3F),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.euro, color: Color(0xFF3E63A8)),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3E63A8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () {
              final amount = double.tryParse(amountController.text) ?? 0;
              if (amount > 0) {
                ref.read(chatControllerProvider).sendMoneyMessage(
                      context,
                      amount,
                      widget.recieverUserId,
                      widget.isGroupChat,
                    );
              }
              Navigator.pop(dialogCtx);
            },
            child: const Text('Enviar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> sendTextMessage() async {
    if (isShowSendButton) {
      ref.read(chatControllerProvider).sendTextMessage(
            context,
            _messageController.text.trim(),
            widget.recieverUserId,
            widget.isGroupChat,
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
          widget.recieverUserId,
          messageEnum,
          widget.isGroupChat,
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
            widget.recieverUserId,
            widget.isGroupChat,
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

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1E2E),
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
              decoration: const BoxDecoration(
                color: Color(0xFF252A3F),
                border: Border(
                  top: BorderSide(color: Color(0xFF3E63A8), width: 0.5),
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
                  _buildAttachmentButton(
                    icon: Icons.attach_money,
                    label: 'Dinero',
                    color: Colors.amber,
                    onTap: handleSendMoney,
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
                    color: const Color(0xFF252A3F),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: IconButton(
                    icon: Icon(
                      isShowAttachments ? Icons.close : Icons.add,
                      color: const Color(0xFF3E63A8),
                    ),
                    onPressed: toggleAttachments,
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Campo de texto expandible
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF252A3F),
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
                            color: const Color(0xFF3E63A8),
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
                              hintText: '...',
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ),
                        ),
                        
                        // Botón de enviar dinero (siempre visible)
                        IconButton(
                          icon: const Icon(Icons.attach_money, color: Color(0xFF3E63A8)),
                          onPressed: handleSendMoney,
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Botón de enviar/micrófono
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF3E63A8),
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