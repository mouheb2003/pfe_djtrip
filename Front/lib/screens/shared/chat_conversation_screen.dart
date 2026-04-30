import 'dart:ui' as ui;

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
import '../../services/navigation_service.dart';
import '../../theme/app_theme.dart';
import 'public_profile_screen.dart';
import 'voice_call_screen.dart';
import 'video_call_screen.dart';
import '../organizer/map_picker_screen.dart';

class ChatConversationScreen extends StatefulWidget {
  final String partnerId;
  final String partnerName;
  final String? partnerAvatar;
  final String? partnerType;
  final bool partnerOnline;
  final bool isSupportChat;

  const ChatConversationScreen({
    super.key,
    required this.partnerId,
    required this.partnerName,
    this.partnerAvatar,
    this.partnerType,
    this.partnerOnline = false,
    this.isSupportChat = false,
  });

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen>
    with WidgetsBindingObserver {
  // 🔧 FIX: Support chat uses socket only, normal chat: longer interval to reduce flickering
  late Duration _refreshInterval;

  final TextEditingController _msgCtrl = TextEditingController();
  final FocusNode _msgFocus = FocusNode();
  final ScrollController _scrollCtrl = ScrollController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _voicePlayer = AudioPlayer();

  bool _loading = true;
  String? _currentUserId;
  List<_UiMessage> _messages = [];
  io.Socket? _socket;
  bool _isRecordingVoice = false;
  bool _isRecordingPaused = false;
  bool _isUploadingImage = false;
  Timer? _recordTicker;
  int _recordElapsedSec = 0;
  String _playingMessageId = '';
  String _loadedAudioUrl = '';
  Duration _voicePosition = Duration.zero;
  Duration _voiceDuration = Duration.zero;
  String _editingMessageId = '';
  String _replacingMessageId = '';
  Timer? _autoRefreshTimer;
  bool _hasInitialLoadCompleted = false;

  // 🚀 SIMPLIFIED: Simple online status tracking
  bool _partnerOnline = false;
  Timer? _statusUpdateDebounce;

  // 🚀 Typing indicator
  bool _isPartnerTyping = false;
  Timer? _typingIndicatorTimer;

  // 🚀 Scroll tracking for down arrow button
  bool _isAtBottom = true;

  // 🚀 Block/Mute status tracking
  bool _isPartnerBlocked = false;
  bool _isBlockedByPartner = false;
  bool _isConversationMuted = false;

  Future<void> _checkBlockMuteStatus() async {
    try {
      final result = await MessageService.getBlockedUsers();
      if (!mounted) return;
      
      print('DEBUG: Block check result: $result');
      
      if (result['success'] == true) {
        final blockedUsers = result['blockedUsers'] as List<dynamic>;
        final mutedPartners = result['mutedConversationPartners'] as List<dynamic>;
        final blockedByUsers = result['blockedByUsers'] as List<dynamic>;
        
        print('DEBUG: Blocked users: $blockedUsers');
        print('DEBUG: Blocked by users: $blockedByUsers');
        print('DEBUG: Partner ID: ${widget.partnerId}');
        print('DEBUG: Is partner blocked: ${blockedUsers.any((id) => id.toString() == widget.partnerId)}');
        print('DEBUG: Is current user blocked by partner: ${blockedByUsers.any((id) => id.toString() == widget.partnerId)}');
        
        setState(() {
          _isPartnerBlocked = blockedUsers.any((id) => id.toString() == widget.partnerId);
          _isBlockedByPartner = blockedByUsers.any((id) => id.toString() == widget.partnerId);
          _isConversationMuted = mutedPartners.any((id) => id.toString() == widget.partnerId);
        });
        
        print('DEBUG: _isPartnerBlocked set to: $_isPartnerBlocked');
        print('DEBUG: _isBlockedByPartner set to: $_isBlockedByPartner');
      }
    } catch (e) {
      // Silently fail - block/mute status is not critical
      print('Error checking block/mute status: $e');
    }
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final maxScroll = _scrollCtrl.position.maxScrollExtent;
    final currentScroll = _scrollCtrl.position.pixels;
    const threshold = 50.0; // pixels from bottom to consider "at bottom"

    final wasAtBottom = _isAtBottom;
    _isAtBottom = (maxScroll - currentScroll) <= threshold;

    if (wasAtBottom != _isAtBottom && mounted) {
      setState(() {});
    }
  }

  // ✅ ADDED
  void _disposeSocket() {
    _socket?.off('connect');
    _socket?.off('disconnect');
    _socket?.off('message_sent');
    _socket?.off('new_message');
    _socket?.off('user_status');
    _socket?.off('account_restricted');
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void _startAutoRefresh() {
    // 🚀 Disable auto-refresh - socket handles real-time updates
    // Auto-refresh was causing scroll position issues
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  void _stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 🚀 FIX: Initialize with widget value
    _partnerOnline = widget.partnerOnline;

    // 🔧 OPTIMIZE: Support chat uses socket only (longer fallback interval)
    // Regular chats use moderate interval to handle offline scenarios
    _refreshInterval = widget.isSupportChat
        ? Duration(
            seconds: 15,
          ) // Support: socket is primary, refresh is fallback
        : Duration(seconds: 6); // Normal: moderate refresh to reduce flickering

    _initVoicePlayer();
    _checkBlockMuteStatus();
    _loadMessages();
    _initSocket();
    _startAutoRefresh();

    // 🚀 Add scroll listener to track scroll position
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _disposeSocket();
    WidgetsBinding.instance.removeObserver(this);
    _voicePlayer.stop();
    _voicePlayer.dispose();
    _audioRecorder.dispose();
    _recordTicker?.cancel();
    _stopAutoRefresh();
    _statusUpdateDebounce?.cancel();
    _msgCtrl.dispose();
    _msgFocus.dispose();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  bool _canEditMessage(_UiMessage msg) {
    return msg.isMine &&
        msg.type == 'text' &&
        msg.text.trim().isNotEmpty &&
        msg.id.isNotEmpty;
  }

  void _startEditingMessage(_UiMessage msg) {
    if (!_canEditMessage(msg)) return;
    setState(() {
      _editingMessageId = msg.id;
      _msgCtrl.text = msg.text;
    });
    _msgFocus.requestFocus();
  }

  void _cancelEditingMessage() {
    if (_editingMessageId.isEmpty) return;
    setState(() {
      _editingMessageId = '';
      _msgCtrl.clear();
    });
  }

  void _cancelReplacingMessage() {
    if (_replacingMessageId.isEmpty) return;
    setState(() {
      _replacingMessageId = '';
    });
  }

  bool _isWarningType(String type) => type.trim().toLowerCase() == 'warning';

  bool get _isWarningInboxMode => _isDjTripAdminThread && !widget.isSupportChat;

  bool get _isReplyLocked => _messages.any(
    (message) =>
        _isWarningInboxMode && _isWarningType(message.type) && !message.isMine,
  );

  bool get _isConversationBlocked => _isPartnerBlocked || _isBlockedByPartner;

  Future<void> _finalizeReplacement(Map<String, dynamic> payload) async {
    final replacingId = _replacingMessageId;
    _pushSocketMessage(payload, forceMine: true);

    if (replacingId.isEmpty) return;

    final ok = await MessageService.deleteMessage(replacingId);
    if (!mounted) return;

    setState(() {
      if (ok) {
        _messages.removeWhere((m) => m.id == replacingId);
      }
      _replacingMessageId = '';
    });

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New message sent, old message not deleted.'),
        ),
      );
    }
  }

  Future<void> _updateMessage() async {
    final text = _msgCtrl.text.trim();
    if (_editingMessageId.isEmpty || text.isEmpty) return;

    final editingId = _editingMessageId;
    final response = await MessageService.editMessage(
      messageId: editingId,
      content: text,
    );

    if (!mounted) return;
    if (response['success'] == true) {
      final msg = response['message'] as Map<String, dynamic>?;
      final editedAt = DateTime.tryParse((msg?['edited_at'] ?? '').toString());
      setState(() {
        final index = _messages.indexWhere((m) => m.id == editingId);
        if (index >= 0) {
          final old = _messages[index];
          _messages[index] = old.copyWith(
            text: text,
            isEdited: true,
            editedAt: editedAt ?? DateTime.now(),
          );
        }
        _editingMessageId = '';
        _msgCtrl.clear();
      });
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          (response['messageText'] ?? 'Unable to update message').toString(),
        ),
      ),
    );
  }

  Future<bool> _showDeleteMessageDialog() async {
    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierLabel: 'Delete message',
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.26),
      pageBuilder: (dialogContext, _, __) {
        return BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F9FD),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Delete message?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF13213F),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Are you sure you want to delete this message?\nThis action cannot be undone.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        color: Color(0xFF5D6D8B),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF3E4D6D),
                              side: const BorderSide(color: Color(0xFFD3DBEA)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFE63946),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            child: const Text('Delete'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    return confirmed == true;
  }

  Future<void> _deleteMessageFlow(_UiMessage msg) async {
    if (msg.id.isEmpty) return;
    final confirmed = await _showDeleteMessageDialog();
    if (!confirmed || !mounted) return;

    final ok = await MessageService.deleteMessage(msg.id);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _messages.removeWhere((m) => m.id == msg.id);
        if (_editingMessageId == msg.id) {
          _editingMessageId = '';
          _msgCtrl.clear();
        }
        if (_replacingMessageId == msg.id) {
          _replacingMessageId = '';
        }
      });
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Unable to delete message.')));
  }

  Future<void> _openMessageActions(_UiMessage msg) async {
    if (!msg.isMine) return;

    if (!_canEditMessage(msg)) {
      await _deleteMessageFlow(msg);
      return;
    }

    final action = await showGeneralDialog<String>(
      context: context,
      barrierLabel: 'Message actions',
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.22),
      pageBuilder: (dialogContext, _, __) {
        return BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF9FBFF),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(26),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD8E0EF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'MESSAGE OPTIONS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                          color: Color(0xFF9AA6BF),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _MessageOptionRow(
                        icon: Icons.edit_rounded,
                        iconBg: const Color(0xFFE7EDFF),
                        iconColor: AppColors.primary,
                        label: 'Edit Message',
                        labelColor: const Color(0xFF2E3A58),
                        onTap: () => Navigator.pop(dialogContext, 'edit'),
                      ),
                      const SizedBox(height: 12),
                      _MessageOptionRow(
                        icon: Icons.delete_outline_rounded,
                        iconBg: const Color(0xFFFDE3E5),
                        iconColor: const Color(0xFFE63946),
                        label: 'Delete Message',
                        labelColor: const Color(0xFFE63946),
                        onTap: () => Navigator.pop(dialogContext, 'delete'),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Color(0xFF7C8AA6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) return;
    if (action == 'edit') {
      _startEditingMessage(msg);
      return;
    }
    if (action == 'delete') {
      await _deleteMessageFlow(msg);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _stopAutoRefresh();
        _disposeSocket();
        return;

      case AppLifecycleState.resumed:
        print('▶️ Chat resumed, reconnecting socket');
        if (_socket == null) {
          _initSocket();
        }
        _startAutoRefresh();
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
    _disposeSocket();

    final token = await AuthService.getAccessToken();
    if (token == null || token.isEmpty) return;

    final serverUrl = ApiClient.baseUrl.replaceFirst(
      RegExp(r'/api(?:/v1)?$'),
      '',
    );
    final socket = io.io(
      serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableReconnection()
          .setReconnectionAttempts(20)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(8000)
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    socket.off('connect');
    socket.off('disconnect');
    socket.off('message_sent');
    socket.off('new_message');
    socket.off('user_status');
    socket.off('account_restricted');

    // 🚀 SIMPLIFIED: Clean socket event handling
    socket.on('connect', (_) {
      print('🔗 Chat Socket connected successfully');
      print('🔗 Current userId: $_currentUserId');
      print('🔗 Partner ID: ${widget.partnerId}');
    });

    socket.on('disconnect', (reason) {
      print('🔌 Chat Socket disconnected: $reason');
    });

    socket.on('message_sent', (data) {
      _pushSocketMessage(data, forceMine: true);
    });

    socket.on('new_message', (data) {
      print('📨 [ChatScreen] Received new_message event: $data');
      _pushSocketMessage(data);
    });

    socket.on('typing', (data) {
      if (!mounted) return;
      if (data is! Map) return;
      final userId = (data['userId'] ?? '').toString();
      if (userId == widget.partnerId) {
        setState(() {
          _isPartnerTyping = true;
        });
        _typingIndicatorTimer?.cancel();
        _typingIndicatorTimer = Timer(const Duration(seconds: 3), () {
          if (!mounted) return;
          setState(() {
            _isPartnerTyping = false;
          });
        });
      }
    });

    // 🚀 CRITICAL: Proper user status handling with debounce
    socket.on('user_status', (data) {
      print('📡 [ChatScreen] Received user_status: $data');
      if (!mounted) return;
      if (data is! Map) return;

      final userId = (data['userId'] ?? '').toString();
      final isOnline = data['isOnline'] == true;
      final timestamp = data['timestamp'];

      print(
        '🔄 [ChatScreen] Checking partner: widget.partnerId=${widget.partnerId}, received userId=$userId',
      );
      print(
        '🔄 [ChatScreen] Current _partnerOnline=$_partnerOnline, new isOnline=$isOnline',
      );

      if (userId == widget.partnerId) {
        print(
          '✅ [ChatScreen] UPDATING PARTNER STATUS to online=$isOnline at $timestamp',
        );
        
        // 🚀 FIX: Debounce status updates to prevent excessive setState calls
        _statusUpdateDebounce?.cancel();
        _statusUpdateDebounce = Timer(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          setState(() {
            _partnerOnline = isOnline;
          });
          print(
            '✅ [ChatScreen] State updated. New _partnerOnline=$_partnerOnline',
          );
        });
      } else {
        print('❌ [ChatScreen] User ID mismatch, ignoring status update');
      }
    });

    socket.on('account_restricted', (data) async {
      if (!mounted) return;

      String message = 'Votre compte a été restreint.';
      final restriction = <String, dynamic>{};
      if (data is Map && data['message'] != null) {
        message = data['message'].toString();

        final type = data['type']?.toString().trim() ?? '';
        final reason = data['reason']?.toString().trim() ?? '';
        final suspendedUntil = data['suspendedUntil'];

        if (type.isNotEmpty) restriction['type'] = type;
        if (reason.isNotEmpty) restriction['reason'] = reason;
        if (suspendedUntil != null) {
          restriction['suspendedUntil'] = suspendedUntil.toString();
        }
      }

      restriction['message'] = message;
      await AuthService.clearLocalSession();
      NavigationService.forceLogoutToLogin(
        message: message,
        restriction: restriction,
      );
    });

    socket.connect();
    _socket = socket;
  }

  void _pushSocketMessage(dynamic data, {bool forceMine = false}) {
    print('📨 [ChatScreen] _pushSocketMessage called with data: $data');
    print('📨 [ChatScreen] forceMine: $forceMine');
    print('📨 [ChatScreen] mounted: $mounted');

    if (!mounted) {
      print('❌ [ChatScreen] Widget not mounted, returning');
      return;
    }
    if (data is! Map) {
      print('❌ [ChatScreen] Data is not a Map, returning');
      return;
    }

    final sender = (data['sender_id'] ?? '').toString();
    final receiver = (data['receiver_id'] ?? '').toString();
    final messageType = (data['message_type'] ?? 'text')
        .toString()
        .trim()
        .toLowerCase();
    final me = _currentUserId ?? '';
    final partner = widget.partnerId;
    final warningModeActive = _isWarningInboxMode;

    print('📨 [ChatScreen] sender: $sender, receiver: $receiver');
    print('📨 [ChatScreen] me: $me, partner: $partner');
    print('📨 [ChatScreen] messageType: $messageType');

    // Warnings must be shown only to the warned side (receiver).
    final isWarningSentByMe = _isWarningType(messageType) && sender == me;
    if (_isWarningInboxMode && isWarningSentByMe) {
      print('❌ [ChatScreen] Warning sent by me in warning inbox mode, returning');
      return;
    }

    if (widget.isSupportChat && _isWarningType(messageType)) {
      print('❌ [ChatScreen] Warning in support chat, returning');
      return;
    }

    // In warning mode, keep only warning messages visible.
    if (warningModeActive && !_isWarningType(messageType)) {
      print('❌ [ChatScreen] Warning mode active but not warning message, returning');
      return;
    }

    final belongsToCurrentChat =
        (sender == partner && receiver == me) ||
        (sender == me && receiver == partner);
    print('📨 [ChatScreen] belongsToCurrentChat: $belongsToCurrentChat');

    if (!belongsToCurrentChat && !forceMine) {
      print('❌ [ChatScreen] Message does not belong to current chat, returning');
      return;
    }

    final msg = _UiMessage(
      id: (data['_id'] ?? '').toString(),
      text: (data['content'] ?? '').toString(),
      type: messageType,
      audioUrl: (data['media_url'] ?? '').toString(),
      durationSec: (data['media_duration'] as num?)?.toInt() ?? 0,
      isMine: forceMine || sender == me,
      time:
          DateTime.tryParse((data['createdAt'] ?? '').toString()) ??
          DateTime.now(), // 🚀 FIX: Handle null
      isEdited: data['is_edited'] == true,
      editedAt: DateTime.tryParse((data['edited_at'] ?? '').toString()),
      isRead: (data['is_read'] == true),
      readAt: DateTime.tryParse((data['read_at'] ?? '').toString()),
    );

    print('📨 [ChatScreen] Created message: id=${msg.id}, text=${msg.text}, isMine=${msg.isMine}');

    setState(() {
      if (_messages.any((m) => m.id == msg.id && msg.id.isNotEmpty)) {
        print('❌ [ChatScreen] Message already exists in list, not adding');
        return;
      }
      print('✅ [ChatScreen] Adding message to list');
      _messages.add(msg);
      // 🚀 Sort messages by date after adding new message
      _messages.sort((a, b) => a.time.compareTo(b.time));
    });

    // 🚀 Auto-scroll to bottom when new message arrives
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
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
        type: (m['message_type'] ?? 'text').toString().trim().toLowerCase(),
        audioUrl: (m['media_url'] ?? '').toString(),
        durationSec: (m['media_duration'] as num?)?.toInt() ?? 0,
        isMine: sender == (userId ?? ''),
        time: createdAt ?? DateTime.now(),
        isEdited: m['is_edited'] == true,
        editedAt: DateTime.tryParse((m['edited_at'] ?? '').toString()),
        isRead: (m['is_read'] == true),
        readAt: readAt,
      );
    }).toList();

    final visibleMessages = widget.isSupportChat
        ? mapped.where((m) => !_isWarningType(m.type)).toList()
        : (_isWarningInboxMode
              ? mapped.where((m) => _isWarningType(m.type)).toList()
              : mapped);

    // 🚀 Sort messages by date (oldest first for proper display in ListView)
    visibleMessages.sort((a, b) => a.time.compareTo(b.time));

    setState(() {
      _currentUserId = userId;

      // 🔧 SMART UPDATE: Only replace list on first load or if count changes significantly
      if (!_hasInitialLoadCompleted) {
        _messages = visibleMessages;
        _hasInitialLoadCompleted = true;
        // 🚀 Auto-scroll to bottom on initial load
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.animateTo(
              _scrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      } else if (visibleMessages.length != _messages.length) {
        // Count changed - likely new message(s)
        _messages = visibleMessages;
      } else {
        // Merge updates for existing messages (e.g., read status, edits)
        for (int i = 0; i < visibleMessages.length; i++) {
          if (i < _messages.length &&
              visibleMessages[i].id == _messages[i].id) {
            // Update if read status or edit changed
            if (visibleMessages[i].isRead != _messages[i].isRead ||
                visibleMessages[i].isEdited != _messages[i].isEdited) {
              _messages[i] = visibleMessages[i];
            }
          }
        }
      }

      _loading = false;
    });

    // 🚀 Don't auto-scroll on load - let user control scroll
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
    });
  }

  Future<void> _send() async {
    print('[ChatScreen] _send() called');
    final text = _msgCtrl.text.trim();
    print('[ChatScreen] Text field content: "$text"');
    if (text.isEmpty) {
      print('[ChatScreen] Text is empty, returning');
      return;
    }

    _msgCtrl.clear();

    print('[ChatScreen] Sending message to partner: ${widget.partnerId}');
    print('[ChatScreen] Message content: $text');

    final response = await MessageService.sendMessage(
      partnerId: widget.partnerId,
      content: text,
    );

    print('[ChatScreen] Response: $response');

    if (!mounted) return;

    if (response['success'] == true) {
      final payload = response['message'] as Map<String, dynamic>;
      print('[ChatScreen] Payload from server: $payload');
      _pushSocketMessage(payload, forceMine: true);
      // 🚀 Don't auto-scroll - let user control scroll
      return;
    } else {
      print('[ChatScreen] Failed to send message: ${response['message']}');
    }
  }

  String _formatClock(DateTime? time) {
    if (time == null) return '';
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString();
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _resolveMediaUrl(String rawUrl) {
    final raw = rawUrl.trim();
    if (raw.isEmpty || raw == 'null' || raw == 'undefined') return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;

    final serverUrl = ApiClient.baseUrl.replaceFirst(
      RegExp(r'/api(?:/v1)?$'),
      '',
    );
    if (raw.startsWith('/')) return '$serverUrl$raw';
    return '$serverUrl/$raw';
  }

  String? _resolveAvatarUrl(String? rawUrl) {
    final raw = (rawUrl ?? '').trim();
    if (raw.isEmpty || raw == 'null' || raw == 'undefined') return null;

    // Local file URIs are not valid for NetworkImage in this context.
    if (raw.startsWith('file://')) return null;

    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;

    final serverUrl = ApiClient.baseUrl.replaceFirst(
      RegExp(r'/api(?:/v1)?$'),
      '',
    );

    if (raw.startsWith('/')) return '$serverUrl$raw';
    return '$serverUrl/$raw';
  }

  bool get _isDjTripAdminThread {
    final type = (widget.partnerType ?? '').trim().toLowerCase();
    final name = widget.partnerName.trim().toLowerCase();
    return type == 'admin' || name.contains('admin');
  }

  ImageProvider<Object>? _partnerAvatarProvider() {
    if (_isDjTripAdminThread) {
      return const AssetImage('assets/logos/app_logo.png');
    }

    final url = _resolveAvatarUrl(widget.partnerAvatar);
    if (url == null || url.isEmpty) return null;
    return NetworkImage(url);
  }

  Widget _adminBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFDCE9FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'ADMIN',
        style: TextStyle(
          color: Color(0xFF2E5BFF),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  bool _isImageMessage(_UiMessage msg) {
    if (msg.type == 'image') return true;
    final lower = msg.audioUrl.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }

  bool _isVoiceMessage(_UiMessage msg) {
    return msg.type == 'audio' || msg.type == 'voice';
  }

  bool _isVideoMessage(_UiMessage msg) {
    if (msg.type == 'video') return true;
    final lower = msg.audioUrl.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.webm');
  }

  bool _isLocationMessage(_UiMessage msg) {
    final t = msg.text.toLowerCase();
    return t.startsWith('location:') || t.contains('maps.google.com/?q=');
  }

  Future<void> _toggleVoicePlayback(_UiMessage msg) async {
    final url = _resolveMediaUrl(msg.audioUrl);
    if (url.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio unavailable for this message.')),
      );
      return;
    }

    try {
      final isCurrent = _playingMessageId == msg.id;
      final sameSource = _loadedAudioUrl == url;

      if (isCurrent && _voicePlayer.playing) {
        await _voicePlayer.pause();
        return;
      }

      if (!sameSource) {
        await _voicePlayer.setUrl(Uri.encodeFull(url));
        _loadedAudioUrl = url;
      }

      if (!mounted) return;
      setState(() {
        _playingMessageId = msg.id;
        _voicePosition = Duration.zero;
      });

      await _voicePlayer.play();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to play voice message.')),
      );
    }
  }

  void _onCallTap({required bool isVideo}) {
    if (widget.isSupportChat) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Calls are disabled for support chat.')),
      );
      return;
    }

    if (!_partnerOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.partnerName} is offline')),
      );
      return;
    }

    if (isVideo) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoCallScreen(
            partnerId: widget.partnerId,
            name: widget.partnerName,
            avatarUrl: widget.partnerAvatar ?? '',
            isInitiator: true,
            socket: _socket,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VoiceCallScreen(
            partnerId: widget.partnerId,
            name: widget.partnerName,
            avatarUrl: widget.partnerAvatar ?? '',
            subtitle: 'Calling from DJTrip',
            isInitiator: true,
            socket: _socket,
          ),
        ),
      );
    }
  }

  Future<void> _startRecordingUi() async {
    if (_isRecordingVoice || _isConversationBlocked) return;

    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission denied.')),
      );
      return;
    }

    try {
      final tmp = await getTemporaryDirectory();
      final path =
          '${tmp.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 96000,
          sampleRate: 44100,
        ),
        path: path,
      );

      if (!mounted) return;
      setState(() {
        _isRecordingVoice = true;
        _recordElapsedSec = 0;
        _isRecordingPaused = false;
      });

      _recordTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || !_isRecordingVoice || _isRecordingPaused) return;
        setState(() => _recordElapsedSec += 1);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to start recording: $e')));
    }
  }

  Future<void> _togglePauseRecordingUi() async {
    if (!_isRecordingVoice) return;

    try {
      if (_isRecordingPaused) {
        await _audioRecorder.resume();
      } else {
        await _audioRecorder.pause();
      }

      if (!mounted) return;
      setState(() {
        _isRecordingPaused = !_isRecordingPaused;
      });

      _recordTicker?.cancel();
      _recordTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || !_isRecordingVoice || _isRecordingPaused) return;
        setState(() => _recordElapsedSec += 1);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to pause recording: $e')));
    }
  }

  Future<void> _cancelRecordingUi() async {
    if (!_isRecordingVoice) return;
    _recordTicker?.cancel();

    String? filePath;
    try {
      filePath = await _audioRecorder.stop();
    } catch (_) {}

    if (filePath != null && filePath.isNotEmpty) {
      final f = File(filePath);
      if (await f.exists()) {
        await f.delete();
      }
    }

    if (!mounted) return;
    setState(() {
      _isRecordingVoice = false;
      _recordElapsedSec = 0;
    });
  }

  Future<void> _sendRecordingUi() async {
    if (!_isRecordingVoice) return;
    final elapsed = _recordElapsedSec;

    _recordTicker?.cancel();

    String? filePath;
    try {
      filePath = await _audioRecorder.stop();
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _isRecordingVoice = false;
      _recordElapsedSec = 0;
    });

    if (filePath == null || filePath.isEmpty || elapsed < 1) {
      if (filePath != null && filePath.isNotEmpty) {
        final f = File(filePath);
        if (await f.exists()) {
          await f.delete();
        }
      }
      return;
    }

    final res = await MessageService.sendAudioMessage(
      partnerId: widget.partnerId,
      audioFile: File(filePath),
      durationSec: elapsed,
    );

    if (!mounted) return;
    if (res['success'] == true) {
      final payload = res['message'] as Map<String, dynamic>;
      await _finalizeReplacement(payload);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          (res['messageText'] ?? 'Unable to send voice message').toString(),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isUploadingImage || _isConversationBlocked) return;

    try {
      final picked = await ImagePicker().pickImage(source: source);
      if (picked == null || !mounted) return;

      setState(() {
        _isUploadingImage = true;
      });

      final response = await MessageService.sendImageMessage(
        partnerId: widget.partnerId,
        imageFile: File(picked.path),
      );

      if (!mounted) return;

      if (response['success'] == true) {
        final payload = response['message'] as Map<String, dynamic>?;
        if (payload != null) {
          await _finalizeReplacement(payload);
        }
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (response['messageText'] ?? 'Unable to send image').toString(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Image upload failed: $e')));
    } finally {
      if (!mounted) return;
      setState(() {
        _isUploadingImage = false;
      });
    }
  }

  Future<void> _pickVideo() async {
    if (_isUploadingImage || _isConversationBlocked) return;

    try {
      final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
      if (picked == null || !mounted) return;

      setState(() {
        _isUploadingImage = true;
      });

      final response = await MessageService.sendVideoMessage(
        partnerId: widget.partnerId,
        videoFile: File(picked.path),
      );

      if (!mounted) return;

      if (response['success'] == true) {
        final payload = response['message'] as Map<String, dynamic>?;
        if (payload != null) {
          await _finalizeReplacement(payload);
        }
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (response['messageText'] ?? 'Unable to send video').toString(),
          ),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isUploadingImage = false;
      });
    }
  }

  Future<void> _pickAndSendLocation() async {
    final result = await Navigator.push<MapPickerResult>(
      context,
      MaterialPageRoute(builder: (_) => const MapPickerScreen()),
    );

    if (!mounted || result == null) return;

    final lat = result.latLng.latitude.toStringAsFixed(6);
    final lng = result.latLng.longitude.toStringAsFixed(6);
    final locationText =
        'Location: ${result.address}\nhttps://maps.google.com/?q=$lat,$lng';

    final response = await MessageService.sendMessage(
      partnerId: widget.partnerId,
      content: locationText,
    );

    if (!mounted) return;

    if (response['success'] == true) {
      final payload = response['message'] as Map<String, dynamic>;
      await _finalizeReplacement(payload);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          (response['messageText'] ?? 'Unable to share location').toString(),
        ),
      ),
    );
  }

  Future<void> _openAttachmentSheet() async {
    if (_isUploadingImage) return;

    final selection = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 16),
                _attachmentTile(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  color: const Color(0xFF315CFF),
                  onTap: () => Navigator.pop(ctx, 'gallery'),
                ),
                _attachmentTile(
                  icon: Icons.photo_camera_rounded,
                  label: 'Camera',
                  color: const Color(0xFF0EA5E9),
                  onTap: () => Navigator.pop(ctx, 'camera'),
                ),
                // 🔧 CONDITIONAL: Show different options based on chat type
                if (!widget.isSupportChat) ...[
                  _attachmentTile(
                    icon: Icons.location_on_rounded,
                    label: 'Location',
                    color: const Color(0xFF22C55E),
                    onTap: () => Navigator.pop(ctx, 'location'),
                  ),
                  _attachmentTile(
                    icon: Icons.video_collection_rounded,
                    label: 'Video',
                    color: const Color(0xFF8B5CF6),
                    onTap: () => Navigator.pop(ctx, 'video'),
                  ),
                ] else
                  // 🔧 SUPPORT CHAT: Show message hint
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Support chat: Text & Photos only',
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF999),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selection == null) return;

    if (selection == 'gallery') {
      await _pickImage(ImageSource.gallery);
      return;
    }

    if (selection == 'camera') {
      await _pickImage(ImageSource.camera);
      return;
    }

    if (selection == 'location') {
      await _pickAndSendLocation();
      return;
    }

    if (selection == 'video') {
      await _pickVideo();
    }
  }

  Widget _attachmentTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF1E2A4A),
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) return 'TODAY';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _buildHeader(ColorScheme cs) {
    final showAdminIdentity = _isDjTripAdminThread;
    final partnerAvatarProvider = _partnerAvatarProvider();
    final headerTitle = showAdminIdentity
        ? 'DJTrip Admin'
        : (widget.isSupportChat ? 'DJTrip Support' : widget.partnerName);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(bottom: BorderSide(color: AppColors.borderLight)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isPartnerTyping)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.partnerName} is typing...',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: cs.onSurface,
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    if (!widget.isSupportChat && !_isDjTripAdminThread) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PublicProfileScreen(userId: widget.partnerId),
                        ),
                      );
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: cs.surfaceVariant,
                        backgroundImage: partnerAvatarProvider,
                        child: partnerAvatarProvider == null
                            ? Icon(Icons.person, color: cs.onSurfaceVariant, size: 18)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 200),
                            child: Text(
                              headerTitle,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _partnerOnline ? 'Online' : 'Offline',
                            style: TextStyle(
                              fontSize: 12,
                              color: _partnerOnline ? Colors.green : Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (!widget.isSupportChat && !_isWarningInboxMode && !_isConversationBlocked) ...[
                  IconButton(
                    onPressed: () => _onCallTap(isVideo: false),
                    icon: const Icon(Icons.phone_rounded),
                    color: cs.onSurface,
                    tooltip: 'Voice call',
                  ),
                  IconButton(
                    onPressed: () => _onCallTap(isVideo: true),
                    icon: const Icon(Icons.videocam_rounded),
                    color: cs.onSurface,
                    tooltip: 'Video call',
                  ),
                ],
                if (showAdminIdentity)
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.info_outline_rounded),
                    color: cs.outline,
                  ),
                if (!widget.isSupportChat)
                  IconButton(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (_) => _buildMoreSheet(cs),
                      );
                    },
                    icon: Icon(Icons.more_vert_rounded, color: cs.onSurfaceVariant),
                    tooltip: 'More',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    final title = widget.isSupportChat
        ? 'Support is ready to help'
        : 'No messages yet';
    final subtitle = widget.isSupportChat
        ? 'Describe your issue and the support team will answer shortly.'
        : 'Start the conversation with your first message.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.primary.withOpacity(0.1),
              ),
              child: Icon(Icons.forum_outlined, color: cs.primary, size: 32),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(ColorScheme cs) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_messages.isEmpty) {
      return _buildEmptyState(cs);
    }

    final hasSupportCard =
        widget.isSupportChat && !_isReplyLocked && !_isDjTripAdminThread;
    final warningMessages = _messages
        .where((m) => _isWarningType(m.type))
        .toList();
    final supportMessages = _messages
        .where((m) => !_isWarningType(m.type))
        .toList();
    final displayMessages = widget.isSupportChat
        ? supportMessages
        : (_isWarningInboxMode ? warningMessages : _messages);

    return ListView.builder(
      controller: _scrollCtrl,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
      itemCount: displayMessages.length + (hasSupportCard ? 1 : 0),
      itemBuilder: (_, i) {
        if (hasSupportCard && i == 0) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: const [
                Icon(
                  Icons.support_agent_rounded,
                  color: Color(0xFF2563EB),
                  size: 18,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Support messages and admin warnings are separated below.',
                    style: TextStyle(
                      color: Color(0xFF1E3A8A),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final msgIndex = hasSupportCard ? i - 1 : i;
        if (widget.isSupportChat && warningMessages.isNotEmpty) {
          if (msgIndex == 0 && warningMessages.isNotEmpty) {
            return Column(
              children: [
                _buildSectionPill('ADMIN WARNING'),
                _buildRowMessage(
                  msg: displayMessages[msgIndex],
                  previous: null,
                  cs: cs,
                ),
              ],
            );
          }

          if (warningMessages.isNotEmpty &&
              msgIndex == warningMessages.length) {
            return Column(
              children: [
                _buildSectionPill('SUPPORT CHAT'),
                _buildRowMessage(
                  msg: displayMessages[msgIndex],
                  previous: msgIndex > 0 ? displayMessages[msgIndex - 1] : null,
                  cs: cs,
                ),
              ],
            );
          }
        }

        final msg = displayMessages[msgIndex];
        final previous = msgIndex > 0 ? displayMessages[msgIndex - 1] : null;
        return _buildRowMessage(msg: msg, previous: previous, cs: cs);
      },
    );
  }

  Widget _buildSectionPill(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF64748B),
            letterSpacing: 1.1,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildRowMessage({
    required _UiMessage msg,
    required _UiMessage? previous,
    required ColorScheme cs,
  }) {
    final showDay = previous == null || !_isSameDay(previous.time, msg.time);

    return Column(
      children: [
        if (showDay)
          Padding(
            padding: const EdgeInsets.only(bottom: 14, top: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _dayLabel(msg.time),
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  letterSpacing: 1.4,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        _buildMessageItem(msg, cs),
      ],
    );
  }

  Widget _buildMessageItem(_UiMessage msg, ColorScheme cs) {
    final isMine = msg.isMine;
    final bubbleColor = isMine ? const Color(0xFF4F6BFF) : const Color(0xFFF1F5F9);
    final textColor = isMine ? Colors.white : const Color(0xFF1E293B);
    final timeColor = const Color(0xFF94A3B8);
    final partnerAvatarProvider = _partnerAvatarProvider();

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMine && !_isWarningType(msg.type))
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 18),
                child: CircleAvatar(
                  radius: 13,
                  backgroundColor: const Color(0xFFF1F5F9),
                  backgroundImage: partnerAvatarProvider,
                  child: partnerAvatarProvider == null
                      ? Icon(Icons.person, size: 13, color: const Color(0xFF94A3B8))
                      : null,
                ),
              ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              child: Column(
                crossAxisAlignment: isMine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onLongPress: isMine ? () => _openMessageActions(msg) : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _buildMessageContent(msg, textColor, cs),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatClock(msg.time),
                        style: TextStyle(
                          color: timeColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      if (msg.type == 'text' && msg.isEdited && msg.editedAt != null)
                        Text(
                          '  \u2022  Modified ${_formatClock(msg.editedAt)}',
                          style: TextStyle(
                            color: timeColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                          ),
                        )
                      else if (isMine && msg.isRead && msg.readAt != null)
                        Text(
                          '  \u2022  Read ${_formatClock(msg.readAt)}',
                          style: TextStyle(
                            color: timeColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                          ),
                        )
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent(_UiMessage msg, Color textColor, ColorScheme cs) {
    if (_isWarningType(msg.type)) {
      final avatarProvider = _partnerAvatarProvider();
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header avec nom et badge - Style sobre
            Row(
              children: [
                // Avatar DJTrip Admin - Bleu avec coche
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F6BFF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'D',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Nom et badge - Utilise Expanded pour éviter overflow
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: const Text(
                              'DJTrip Admin',
                              style: TextStyle(
                                color: Color(0xFF1E293B),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'ADMIN',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Message d'alerte - Style sobre sans icône warning
            Text(
              msg.text,
              style: const TextStyle(
                color: Color(0xFF475569),
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            // Timestamp - Style sobre à gauche
            Text(
              _formatClock(msg.time),
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      );
    }

    if (_isVoiceMessage(msg)) {
      // 🔧 DISABLE: No audio playback in support chat
      if (widget.isSupportChat) {
        return Text(
          '[Audio not available in support chat]',
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontStyle: FontStyle.italic,
          ),
        );
      }

      final isCurrent = _playingMessageId == msg.id;
      final isPlaying = isCurrent && _voicePlayer.playing;
      final duration = isCurrent && _voiceDuration.inSeconds > 0
          ? _voiceDuration
          : Duration(seconds: msg.durationSec);
      final progress = isCurrent && duration.inMilliseconds > 0
          ? (_voicePosition.inMilliseconds / duration.inMilliseconds).clamp(
              0.0,
              1.0,
            )
          : 0.0;

      // 🎵 ENHANCED: Better styling for audio messages
      final playButtonColor = msg.isMine
          ? Colors.white70
          : const Color(0xFF1D4ED8);
      final bgColor = msg.isMine
          ? Colors.white.withOpacity(0.15)
          : const Color(0xFFF3F6FB);

      return SizedBox(
        width: 240,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _toggleVoicePlayback(msg),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: bgColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: msg.isMine
                            ? Colors.white.withOpacity(0.3)
                            : const Color(0xFFE0E7F3),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: playButtonColor,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 3,
                          backgroundColor: msg.isMine
                              ? Colors.white.withOpacity(0.2)
                              : const Color(0xFFE0E7F3),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            msg.isMine ? Colors.white : const Color(0xFF1D4ED8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(
                              isCurrent ? _voicePosition.inSeconds : 0,
                            ),
                            style: TextStyle(
                              color: msg.isMine
                                  ? Colors.white.withOpacity(0.8)
                                  : const Color(0xFF666F7D),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _formatDuration(duration.inSeconds),
                            style: TextStyle(
                              color: msg.isMine
                                  ? Colors.white.withOpacity(0.8)
                                  : const Color(0xFF666F7D),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (msg.text.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                msg.text,
                style: TextStyle(color: textColor, fontSize: 13, height: 1.3),
              ),
            ],
          ],
        ),
      );
    }

    if (_isVideoMessage(msg)) {
      final url = _resolveMediaUrl(msg.audioUrl);
      return Container(
        width: 230,
        height: 170,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.75),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.play_circle_fill_rounded,
              color: Colors.white,
              size: 44,
            ),
            const SizedBox(height: 8),
            Text(
              url.isEmpty ? 'Video unavailable' : 'Video message',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (_isImageMessage(msg)) {
      final url = _resolveMediaUrl(msg.audioUrl);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (url.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                url,
                width: 230,
                height: 170,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 230,
                  height: 170,
                  alignment: Alignment.center,
                  color: cs.surfaceVariant,
                  child: Text(
                    'Image unavailable',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
              ),
            ),
          if (msg.text.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              msg.text,
              style: TextStyle(color: textColor, fontSize: 14, height: 1.35),
            ),
          ],
        ],
      );
    }

    return Text(
      msg.text,
      style: TextStyle(
        color: textColor,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.35,
      ),
    );
  }

  Widget _buildAudioWave(double progress) {
    final heights = <double>[10, 18, 12, 26, 20, 32, 22, 14, 18, 12, 24, 16];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: heights.asMap().entries.map((entry) {
        final index = entry.key;
        final height = entry.value;
        final threshold = (index + 1) / heights.length;
        final active = progress >= threshold;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.5),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 3,
            height: height,
            decoration: BoxDecoration(
              color: active ? const Color(0xFF315CFF) : const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecordingWave() {
    final bars = <double>[26, 44, 60, 74, 96, 58, 44, 60, 40, 30];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: bars.asMap().entries.map((entry) {
        final index = entry.key;
        final h = entry.value;
        final isPrimary = index == 4;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 8,
            height: h,
            decoration: BoxDecoration(
              color: isPrimary
                  ? const Color(0xFF315CFF)
                  : const Color(0xFF9FB6FF),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecordingComposer(ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 10, 8, 4),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF315CFF).withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFFE879A3),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _formatDuration(_recordElapsedSec),
                style: const TextStyle(
                  color: Color(0xFF1E2A4A),
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'RECORDING AUDIO...',
            style: TextStyle(
              color: Color(0xFF55638A),
              letterSpacing: 3,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 28),
          _buildRecordingWave(),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _circleActionButton(
                icon: _isRecordingPaused
                    ? Icons.play_arrow_rounded
                    : Icons.pause_rounded,
                bg: const Color(0xFFDFE5FF),
                fg: const Color(0xFF2B3657),
                size: 52,
                onTap: _togglePauseRecordingUi,
              ),
              _circleActionButton(
                icon: Icons.send_rounded,
                bg: const Color(0xFF315CFF),
                fg: Colors.white,
                size: 64,
                onTap: _sendRecordingUi,
              ),
              _circleActionButton(
                icon: Icons.delete_rounded,
                bg: const Color(0xFFF4E2EE),
                fg: const Color(0xFFE11D48),
                size: 52,
                onTap: _cancelRecordingUi,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _circleActionButton({
    required IconData icon,
    required Color bg,
    required Color fg,
    required VoidCallback onTap,
    double size = 52,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: fg.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, color: fg, size: size * 0.44),
      ),
    );
  }

  Widget _buildMoreSheet(ColorScheme cs) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 5,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                children: [
                  if (!widget.isSupportChat) ...[
                    ListTile(
                      leading: const Icon(Icons.person_outline_rounded),
                      title: const Text('View Profile'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PublicProfileScreen(
                              userId: widget.partnerId,
                            ),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.info_outline_rounded),
                      title: const Text('Chat Info'),
                      onTap: () {
                        Navigator.pop(context);
                        _showChatInfoDialog();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.notifications_off_outlined),
                      title: Text(_isConversationMuted ? 'Unmute Notifications' : 'Mute Notifications'),
                      onTap: () {
                        Navigator.pop(context);
                        if (_isConversationMuted) {
                          _showUnmuteDialog();
                        } else {
                          _showMuteDialog();
                        }
                      },
                    ),
                    ListTile(
                      leading: Icon(_isPartnerBlocked ? Icons.block : Icons.block_outlined),
                      title: Text(_isPartnerBlocked ? 'Unblock User' : 'Block User', style: const TextStyle(color: Colors.red)),
                      onTap: () {
                        Navigator.pop(context);
                        if (_isPartnerBlocked) {
                          _showUnblockDialog();
                        } else {
                          _showBlockDialog();
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChatInfoDialog() {
    final messageCount = _messages.length;
    final firstMessage = _messages.isNotEmpty ? _messages.first : null;
    final startDate = firstMessage?.time;
    final formattedDate = startDate != null 
        ? '${startDate.day}/${startDate.month}/${startDate.year}' 
        : 'No messages yet';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chat Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: _partnerAvatarProvider(),
                  child: _partnerAvatarProvider() == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.partnerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _partnerOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          color: _partnerOnline ? Colors.green : Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildInfoRow('Messages', messageCount.toString()),
            const SizedBox(height: 12),
            _buildInfoRow('Started', formattedDate),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  void _showMuteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mute Notifications'),
        content: const Text('Are you sure you want to mute notifications from this conversation? You will not receive notifications for new messages.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final result = await MessageService.muteConversation(widget.partnerId);
              if (!mounted) return;
              if (result['success'] == true) {
                setState(() {
                  _isConversationMuted = true;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notifications muted')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result['message'] ?? 'Failed to mute conversation')),
                );
              }
            },
            child: const Text('Mute'),
          ),
        ],
      ),
    );
  }

  void _showUnmuteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unmute Notifications'),
        content: const Text('Are you sure you want to unmute notifications from this conversation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final result = await MessageService.unmuteConversation(widget.partnerId);
              if (!mounted) return;
              if (result['success'] == true) {
                setState(() {
                  _isConversationMuted = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notifications unmuted')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result['message'] ?? 'Failed to unmute conversation')),
                );
              }
            },
            child: const Text('Unmute'),
          ),
        ],
      ),
    );
  }

  void _showBlockDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content: const Text('Are you sure you want to block this user? They will not be able to send you messages or contact you.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final result = await MessageService.blockUser(widget.partnerId);
              if (!mounted) return;
              if (result['success'] == true) {
                setState(() {
                  _isPartnerBlocked = true;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User blocked successfully')),
                );
                // Navigate back to messages list after showing snackbar
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted) Navigator.pop(context);
                });
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result['message'] ?? 'Failed to block user')),
                );
              }
            },
            child: const Text('Block', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showUnblockDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unblock User'),
        content: const Text('Are you sure you want to unblock this user? They will be able to send you messages again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final result = await MessageService.unblockUser(widget.partnerId);
              if (!mounted) return;
              if (result['success'] == true) {
                setState(() {
                  _isPartnerBlocked = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User unblocked successfully')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result['message'] ?? 'Failed to unblock user')),
                );
              }
            },
            child: const Text('Unblock'),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedNoticeBanner({EdgeInsetsGeometry? margin}) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.lock_rounded,
              size: 16,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This is a no-reply chat.',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'This conversation is locked by an administrator notice. You cannot send new messages here.',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextComposer(ColorScheme cs) {
    final text = _msgCtrl.text.trim();
    final canSend = text.isNotEmpty;
    final isEditing = _editingMessageId.isNotEmpty;
    final isReplacing = _replacingMessageId.isNotEmpty;
    final isReplyLocked = _isReplyLocked;
    final isBlocked = _isConversationBlocked;
    final composerFill = widget.isSupportChat
        ? const Color(0xFFF1F5FF)
        : const Color(0xFFE8EDF5);
    final sendButtonColor = widget.isSupportChat
        ? const Color(0xFF1D4ED8)
        : const Color(0xFF315CFF);

    // Définissons une taille commune pour les deux boutons d'action
    // pour une meilleure harmonie visuelle.
    const double actionButtonSize = 38.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isReplyLocked)
          _buildLockedNoticeBanner(margin: const EdgeInsets.only(bottom: 8)),
        if (isBlocked)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEF4444)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.block,
                  size: 16,
                  color: Color(0xFFEF4444),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isPartnerBlocked 
                        ? 'You have blocked this user. Messaging is disabled.'
                        : 'This user has blocked you. Messaging is disabled.',
                    style: const TextStyle(
                      color: Color(0xFFB91C1C),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (isEditing || isReplacing)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF3FA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD5DEEE)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.edit_rounded,
                  size: 16,
                  color: Color(0xFF4A5B7A),
                ),
                const SizedBox(width: 8),
                const Expanded(child: Text('')),
                Expanded(
                  child: Text(
                    isEditing ? 'EDITING MESSAGE' : 'REPLACING MESSAGE',
                    style: const TextStyle(
                      color: Color(0xFF4A5B7A),
                      fontSize: 12,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    _cancelEditingMessage();
                    _cancelReplacingMessage();
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Color(0xFF8291AD),
                    ),
                  ),
                ),
              ],
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // --- BOUTON AJOUT (GAUCHE) ---
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 2),
              child: InkWell(
                onTap: isBlocked
                    ? null
                    : () {
                        if (isEditing) {
                          _cancelEditingMessage();
                        }
                        _openAttachmentSheet();
                      },
                borderRadius: BorderRadius.circular(actionButtonSize / 2),
                child: Container(
                  width: actionButtonSize,
                  height: actionButtonSize,
                  decoration: BoxDecoration(
                    color: isBlocked ? Colors.grey : const Color(0xFF90A0BB),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF64748B).withOpacity(0.18),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _isUploadingImage
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : isBlocked
                          ? const Icon(
                              Icons.block,
                              color: Colors.white,
                              size: 26,
                            )
                          : const Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                ),
              ),
            ),

            // --- CHAMP DE TEXTE (CENTRE) ---
            Expanded(
              child: TextField(
                controller: _msgCtrl,
                focusNode: _msgFocus,
                minLines: 1,
                maxLines: 4,
                enabled: !isReplyLocked && !isBlocked,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: isBlocked
                      ? 'Messaging disabled'
                      : (isReplyLocked
                          ? 'Replies disabled by admin notice'
                          : (isEditing ? 'Edit message...' : 'Type a message...')),
                  hintStyle: const TextStyle(
                    color: Color(0xFF6C7C97),
                    fontSize: 15,
                  ),

                  // On active le remplissage ici
                  filled: true,
                  fillColor: composerFill,
                  // On définit les bordures (none) mais avec un border radius
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),

                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),

            // --- ESPACEMENT ---
            const SizedBox(
              width: 8,
            ), // Un peu moins d'espace pour le raffinement
            // --- BOUTON ACTION (DROITE) ---
            Padding(
              // Un petit padding en bas pour qu'il s'aligne visuellement
              // avec la base du champ de texte
              padding: const EdgeInsets.only(bottom: 2),
              child: InkWell(
                onTap: isReplyLocked || isBlocked
                    ? null
                    : canSend
                    ? (isEditing ? _updateMessage : _send)
                    : (widget.isSupportChat
                          ? null // 🔧 DISABLE: No audio in support chat
                          : _startRecordingUi),
                onLongPress: !isReplyLocked && !isBlocked && !canSend && !widget.isSupportChat
                    ? _startRecordingUi
                    : null, // 🔧 DISABLE: No audio in support chat
                borderRadius: BorderRadius.circular(actionButtonSize / 2),
                child: Container(
                  width: actionButtonSize,
                  height: actionButtonSize,
                  decoration: BoxDecoration(
                    color: isBlocked ? Colors.grey : sendButtonColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: sendButtonColor.withOpacity(0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    isBlocked
                        ? Icons.block
                        : (isReplyLocked
                            ? Icons.lock_rounded
                            : canSend
                                ? (isEditing ? Icons.check_rounded : Icons.send_rounded)
                                : (widget.isSupportChat
                                      ? Icons
                                            .send_rounded // 🔧 Always show send in support
                                      : Icons.mic_rounded)),
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomComposer(ColorScheme cs) {
    if (_isReplyLocked) {
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: AppColors.borderLight)),
        ),
        child: SafeArea(top: false, child: _buildLockedNoticeBanner()),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: AppColors.borderLight)),
      ),
      child: SafeArea(
        top: false,
        child: _isRecordingVoice
            ? _buildRecordingComposer(cs)
            : _buildTextComposer(cs),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: widget.isSupportChat
          ? const Color(0xFFF7FAFF)
          : cs.surfaceVariant,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          _buildHeader(cs),
          Expanded(child: _buildMessageList(cs)),
          if (!_isRecordingVoice) _buildBottomComposer(cs),
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
  final bool isEdited;
  final DateTime? editedAt;
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
    this.isEdited = false,
    this.editedAt,
    required this.isRead,
    this.readAt,
  });

  _UiMessage copyWith({
    String? text,
    bool? isEdited,
    DateTime? editedAt,
    bool? isRead,
    DateTime? readAt,
  }) {
    return _UiMessage(
      id: id,
      text: text ?? this.text,
      type: type,
      audioUrl: audioUrl,
      durationSec: durationSec,
      isMine: isMine,
      time: time,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
    );
  }
}

class _MessageOptionRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final Color labelColor;
  final VoidCallback onTap;

  const _MessageOptionRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.labelColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF92A4C4).withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
