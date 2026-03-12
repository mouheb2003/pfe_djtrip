import 'dart:async';
import 'package:flutter/material.dart';
import '../models/message.dart';
import '../services/message_service.dart';
import '../theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  final String partnerId;
  final String partnerName;
  final String? partnerAvatar;
  final bool partnerIsOnline;

  const ChatScreen({
    super.key,
    required this.partnerId,
    required this.partnerName,
    this.partnerAvatar,
    this.partnerIsOnline = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  List<Message> _messages = [];
  bool _loading = true;
  String? _error;
  bool _sending = false;
  bool _partnerTyping = false;
  Timer? _typingDebounce;

  @override
  void initState() {
    super.initState();
    MessageService.connect();
    _load();

    MessageService.onMessage(_onMessage);
    MessageService.onMessageSent(_onMessageSent);
    MessageService.onPartnerTyping(_onPartnerTyping);
    MessageService.onPartnerTypingStop(_onPartnerTypingStop);

    _input.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    MessageService.emitTypingStop(widget.partnerId);
    MessageService.offMessage(_onMessage);
    MessageService.offMessageSent(_onMessageSent);
    MessageService.offPartnerTyping(_onPartnerTyping);
    MessageService.offPartnerTypingStop(_onPartnerTypingStop);
    _input.removeListener(_onInputChanged);
    super.dispose();
  }

  void _onPartnerTyping(String partnerId) {
    if (partnerId != widget.partnerId) return;
    if (mounted) setState(() => _partnerTyping = true);
  }

  void _onPartnerTypingStop(String partnerId) {
    if (partnerId != widget.partnerId) return;
    if (mounted) setState(() => _partnerTyping = false);
  }

  void _onInputChanged() {
    if (_input.text.trim().isEmpty) {
      MessageService.emitTypingStop(widget.partnerId);
      return;
    }
    MessageService.emitTyping(widget.partnerId);
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(seconds: 2), () {
      MessageService.emitTypingStop(widget.partnerId);
    });
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final msgs = await MessageService.getMessages(widget.partnerId);
      if (!mounted) return;
      setState(() {
        _messages = msgs;
        _loading = false;
      });
      MessageService.markAsRead(widget.partnerId);
      Future.delayed(const Duration(milliseconds: 200), _scrollBottom);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _onMessage(Message msg) {
    if (msg.senderId != widget.partnerId) return;
    if (!mounted) return;
    if (msg.id.isNotEmpty && _messages.any((m) => m.id == msg.id)) return;

    setState(() {
      _messages.add(msg);
    });

    _scrollBottom();
  }

  void _onMessageSent(Message msg) {
    if (msg.receiverId != widget.partnerId) return;
    if (!mounted) return;
    if (msg.id.isNotEmpty && _messages.any((m) => m.id == msg.id)) return;

    setState(() {
      _messages.add(msg);
    });

    _scrollBottom();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;

    _input.clear();
    setState(() => _sending = true);

    try {
      await MessageService.sendMessage(
        receiverId: widget.partnerId,
        content: text,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Envoi échoué: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _input.text = text;
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollBottom() {
    if (!_scroll.hasClients) return;

    _scroll.animateTo(
      _scroll.position.maxScrollExtent + 80,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.accent,
                  backgroundImage: widget.partnerAvatar != null && widget.partnerAvatar!.isNotEmpty
                      ? NetworkImage(widget.partnerAvatar!)
                      : null,
                  child: widget.partnerAvatar == null || widget.partnerAvatar!.isEmpty
                      ? Text(
                          widget.partnerName.isNotEmpty ? widget.partnerName[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                if (widget.partnerIsOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.online,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.partnerName,
                    style: AppTextStyles.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.partnerIsOnline)
                    Text(
                      _partnerTyping ? 'En train d\'écrire...' : 'En ligne',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: _partnerTyping ? AppColors.primary : AppColors.online,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _error != null
                    ? _buildError()
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = msg.senderId != widget.partnerId;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Align(
                              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.78,
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isMe ? AppColors.bubbleMe : AppColors.bubbleOther,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                                    bottomRight: Radius.circular(isMe ? 4 : 16),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  msg.content,
                                  style: TextStyle(
                                    color: isMe ? AppColors.onPrimary : AppColors.onSurface,
                                    fontSize: 15,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          Container(
            color: AppColors.card,
            padding: EdgeInsets.only(
              left: 12,
              right: 8,
              top: 8,
              bottom: 8 + MediaQuery.of(context).padding.bottom,
            ),
            child: SafeArea(
              top: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                        child: TextField(
                          controller: _input,
                          maxLines: 4,
                          minLines: 1,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: 'Écrire un message...',
                            hintStyle: AppTextStyles.bodyMedium.copyWith(color: Colors.grey),
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                  ),
                  const SizedBox(width: 6),
                  Material(
                    color: _sending ? Colors.grey : AppColors.primary,
                    borderRadius: BorderRadius.circular(24),
                    child: IconButton(
                      icon: _sending
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white),
                      onPressed: _sending ? null : _send,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Impossible de charger la conversation',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
