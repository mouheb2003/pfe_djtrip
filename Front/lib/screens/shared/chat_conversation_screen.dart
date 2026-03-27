import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import '../../services/auth_service.dart';
import '../../services/api_client.dart';
import '../../services/message_service.dart';
import '../../theme/app_theme.dart';
import 'public_organizer_profile_screen.dart';
import 'voice_call_screen.dart';
import 'video_call_screen.dart';
import '../../services/call_sound_service.dart';

class ChatConversationScreen extends StatefulWidget {
  final String partnerId;
  final String partnerName;
  final String? partnerAvatar;
  final bool partnerOnline;

  const ChatConversationScreen({
    super.key,
    required this.partnerId,
    required this.partnerName,
    this.partnerAvatar,
    this.partnerOnline = false,
  });

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen>
    with WidgetsBindingObserver {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _voicePlayer = AudioPlayer();

  bool _loading = true;
  String? _currentUserId;
  List<_UiMessage> _messages = [];
  io.Socket? _socket;
  bool _isRecordingVoice = false;
  Timer? _recordTicker;
  int _recordElapsedSec = 0;
  String _playingMessageId = '';
  String _loadedAudioUrl = '';
  Duration _voicePosition = Duration.zero;
  Duration _voiceDuration = Duration.zero;

  // 🚀 SIMPLIFIED: Simple online status tracking
  bool _partnerOnline = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // 🚀 FIX: Initialize with widget value
    _partnerOnline = widget.partnerOnline;
    
    _initVoicePlayer();
    _loadMessages();
    _initSocket();
  }

  @override
  void dispose() {
    print('🔴 [ChatScreen] DISPOSE: Forcing logout...');
    
    // 🚀 NEW: Force logout before disposing
    _socket?.emit('force_logout');
    
    // Small delay to ensure the event is sent
    Future.delayed(const Duration(milliseconds: 100), () {
      WidgetsBinding.instance.removeObserver(this);
      _socket?.disconnect();
      _socket?.dispose();
      _voicePlayer.stop();
      _voicePlayer.dispose();
      _audioRecorder.dispose();
      _recordTicker?.cancel();
      _msgCtrl.dispose();
      _scrollCtrl.dispose();
      super.dispose();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        print('⏸️ Chat going to background, forcing logout...');
        // 🚀 NEW: Force logout on app background
        _socket?.emit('force_logout');
        
        Future.delayed(const Duration(milliseconds: 100), () {
          _socket?.disconnect();
          _socket?.dispose();
          _socket = null;
        });
        return;
        
      case AppLifecycleState.resumed:
        print('▶️ Chat resumed, reconnecting socket');
        if (_socket == null) {
          _initSocket();
        }
        break;
    }
  }

  void _initVoicePlayer() {
    _voicePlayer.positionStream.listen((p) {
      if (!mounted) return;
      setState(() => _voicePosition = p);
    });

    _voicePlayer.durationStream.listen((d) {
      if (!mounted || d == null) return;
      setState(() => _voiceDuration = d);
    });

    _voicePlayer.playerStateStream.listen((state) {
      if (!mounted) return;
      if (state.processingState == ProcessingState.completed) {
        setState(() {
          _playingMessageId = '';
          _voicePosition = Duration.zero;
        });
      }
    });
  }

  Future<void> _initSocket() async {
    final token = await AuthService.getAccessToken();
    if (token == null || token.isEmpty) return;

    final serverUrl = ApiClient.baseUrl.replaceFirst(RegExp(r'/api(?:/v1)?$'), '');
    final socket = io.io(
      serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    // 🚀 SIMPLIFIED: Clean socket event handling
    socket.on('connect', (_) {
      print('🔗 Chat Socket connected successfully');
    });

    socket.on('disconnect', (reason) {
      print('🔌 Chat Socket disconnected: $reason');
    });

    socket.on('message_sent', (data) {
      _pushSocketMessage(data, forceMine: true);
    });

    socket.on('new_message', (data) {
      _pushSocketMessage(data);
    });

    // 🚀 CRITICAL: Proper user status handling
    socket.on('user_status', (data) {
      print('📡 [ChatScreen] Received user_status: $data');
      if (!mounted) return;
      if (data is! Map) return;

      final userId = (data['userId'] ?? '').toString();
      final isOnline = data['isOnline'] == true;
      final timestamp = data['timestamp'];

      print('🔄 [ChatScreen] Checking partner: widget.partnerId=${widget.partnerId}, received userId=$userId');
      print('🔄 [ChatScreen] Current _partnerOnline=$_partnerOnline, new isOnline=$isOnline');

      if (userId == widget.partnerId) {
        print('✅ [ChatScreen] UPDATING PARTNER STATUS to online=$isOnline at $timestamp');
        setState(() {
          _partnerOnline = isOnline;
        });
        print('✅ [ChatScreen] State updated. New _partnerOnline=$_partnerOnline');
      } else {
        print('❌ [ChatScreen] User ID mismatch, ignoring status update');
      }
    });

    socket.connect();
    _socket = socket;
  }

  void _pushSocketMessage(dynamic data, {bool forceMine = false}) {
    if (!mounted) return;
    if (data is! Map) return;

    final sender = (data['sender_id'] ?? '').toString();
    final receiver = (data['receiver_id'] ?? '').toString();
    final me = _currentUserId ?? '';
    final partner = widget.partnerId;

    final belongsToCurrentChat =
        (sender == partner && receiver == me) ||
        (sender == me && receiver == partner);
    if (!belongsToCurrentChat && !forceMine) return;

    final msg = _UiMessage(
      id: (data['_id'] ?? '').toString(),
      text: (data['content'] ?? '').toString(),
      type: (data['message_type'] ?? 'text').toString(),
      audioUrl: (data['media_url'] ?? '').toString(),
      durationSec: (data['media_duration'] as num?)?.toInt() ?? 0,
      isMine: forceMine || sender == me,
      time: DateTime.tryParse((data['createdAt'] ?? '').toString()) ?? DateTime.now(), // 🚀 FIX: Handle null
      isRead: (data['is_read'] == true),
      readAt: DateTime.tryParse((data['read_at'] ?? '').toString()),
    );

    setState(() {
      if (_messages.any((m) => m.id == msg.id && msg.id.isNotEmpty)) {
        return;
      }
      _messages.add(msg);
    });
    _scrollToBottom();
  }

  Future<void> _loadMessages() async {
    final userId = await AuthService.getUserId();
    final raw = await MessageService.getMessages(widget.partnerId);
    if (!mounted) return;

    final mapped = raw.map((m) {
      final sender = (m['sender_id'] ?? '').toString();
      final createdAt = DateTime.tryParse((m['createdAt'] ?? '').toString());
      final readAtRaw = DateTime.tryParse((m['read_at'] ?? '').toString());
      final readAt = readAtRaw != null && !readAtRaw.isBefore(DateTime(2000))
          ? readAtRaw
          : null;
      return _UiMessage(
        id: (m['_id'] ?? '').toString(),
        text: (m['content'] ?? '').toString(),
        type: (m['message_type'] ?? 'text').toString(),
        audioUrl: (m['media_url'] ?? '').toString(),
        durationSec: (m['media_duration'] as num?)?.toInt() ?? 0,
        isMine: sender == (userId ?? ''),
        time: createdAt ?? DateTime.now(), // 🚀 FIX: Handle null createdAt
        isRead: (m['is_read'] == true),
        readAt: readAt,
      );
    }).toList();

    setState(() {
      _currentUserId = userId;
      _messages = mapped;
      _loading = false;
    });

    _scrollToBottom();
    _socket?.emit('mark_read', {'partnerId': widget.partnerId});
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );

      Future.delayed(const Duration(milliseconds: 180), () {
        if (!_scrollCtrl.hasClients) return;
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      });
    });
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    _msgCtrl.clear();

    final response = await MessageService.sendMessage(
      partnerId: widget.partnerId,
      content: text,
    );

    if (!mounted) return;

    if (response['success'] == true) {
      final payload = response['message'] as Map<String, dynamic>;
      _pushSocketMessage(payload, forceMine: true);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          (response['messageText'] ?? 'Unable to send message')
              .toString(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    print('🔄 [ChatScreen] BUILD: _partnerOnline=$_partnerOnline, widget.partnerName=${widget.partnerName}');
    
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: cs.surfaceVariant,
              backgroundImage: widget.partnerAvatar != null
                  ? NetworkImage(widget.partnerAvatar!)
                  : null,
              child: widget.partnerAvatar == null
                  ? Icon(Icons.person, color: cs.onSurfaceVariant, size: 16)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.partnerName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  // 🚀 CRITICAL: Simple online status display
                  Text(
                    _partnerOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                      fontSize: 12,
                      color: _partnerOnline
                          ? const Color(0xFF22C55E) // Green for online
                          : const Color(0xFF94A3B8), // Gray for offline
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              if (!_partnerOnline) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${widget.partnerName} is offline')),
                );
                return;
              }
              // Voice call logic here
            },
            icon: Icon(Icons.call, color: cs.primary),
          ),
          IconButton(
            onPressed: () {
              if (!_partnerOnline) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${widget.partnerName} is offline')),
                );
                return;
              }
              // Video call logic here
            },
            icon: Icon(Icons.videocam, color: cs.primary),
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return _MessageBubble(msg: msg);
                    },
                  ),
          ),
          // Input area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(top: BorderSide(color: cs.outline)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.attach_file, color: cs.primary),
                  onPressed: () {
                    // Attachment logic here
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: cs.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: cs.primary),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send, color: cs.primary),
                  onPressed: _send,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _UiMessage msg;

  const _MessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isMe = msg.isMine; // 🚀 FIX: Use msg.isMe instead of msg.isMe
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? cs.primary : cs.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  color: isMe ? cs.onPrimary : cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _UiMessage {
  final String id;
  final String text;
  final String type;
  final String audioUrl;
  final int durationSec;
  final bool isMine; // 🚀 FIX: Make sure this property exists
  final DateTime time;
  final bool isRead;
  final DateTime? readAt;

  _UiMessage({
    required this.id,
    required this.text,
    required this.type,
    required this.audioUrl,
    required this.durationSec,
    required this.isMine, // 🚀 FIX: Required parameter
    required this.time,
    required this.isRead,
    this.readAt,
  });
}
