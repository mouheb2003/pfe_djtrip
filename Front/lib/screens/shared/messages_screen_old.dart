import 'package:flutter/material.dart';
import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../theme/app_theme.dart';
import '../../models/conversation_model.dart';
import '../../services/message_service.dart';
import '../../services/auth_service.dart';
import '../../services/api_client.dart';
import 'chat_conversation_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen>
    with WidgetsBindingObserver {
  int _tabIndex = 0;
  final _tabs = const ['All Chats', 'Unread', 'Groups'];
  List<ConversationModel> _conversations = [];
  String _query = '';
  bool _isLoading = true;
  String? _errorMessage;
  io.Socket? _socket;
  Timer? _presenceReloadTimer;
  Timer? _presencePollTimer;
  bool _pollInFlight = false;

  // 🚀 NEW: Add heartbeat and connection state tracking
  Timer? _heartbeatTimer;
  bool _isExplicitlyDisconnected = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadConversations();
    _initSocket();
    _startPresencePolling();
    _startHeartbeat(); // 🚀 NEW: Start heartbeat
  }

  @override
  void dispose() {
    _isExplicitlyDisconnected = true; // 🚀 NEW: Mark as explicitly disconnected
    _heartbeatTimer?.cancel(); // 🚀 NEW: Cancel heartbeat
    _presencePollTimer?.cancel();
    _presenceReloadTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 🚀 NEW: Heartbeat to maintain connection
  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_socket != null && _isExplicitlyDisconnected == false) {
        _socket?.emit('heartbeat', { 
          'timestamp': DateTime.now().millisecondsSinceEpoch 
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden: // 🚀 FIX: Add missing hidden case
        print('⏸️ App going to background/hidden, disconnecting socket');
        _isExplicitlyDisconnected = true; // 🚀 NEW: Mark as explicitly disconnected
        _socket?.disconnect();
        _socket?.dispose();
        _socket = null;
        _heartbeatTimer?.cancel(); // 🚀 NEW: Cancel heartbeat
        _presencePollTimer?.cancel();
        _presencePollTimer = null;
        return;
        
      case AppLifecycleState.resumed:
        print('▶️ App resumed, reconnecting socket');
        _isExplicitlyDisconnected = false; // 🚀 NEW: Allow reconnection
        if (_socket == null) {
          _initSocket();
        }
        _startHeartbeat(); // 🚀 NEW: Restart heartbeat
        _startPresencePolling();
        break;
    }
  }

  void _startPresencePolling() {
    // Avoid duplicates.
    _presencePollTimer?.cancel();
    _pollInFlight = false;

    // Poll every 10 seconds while MessagesScreen is visible.
    _presencePollTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!mounted) return;
      if (_pollInFlight) return;
      _pollInFlight = true;
      try {
        await _loadConversations();
      } catch (_) {
        // _loadConversations already handles UI state and error message.
      } finally {
        _pollInFlight = false;
      }
    });
  }

  Future<void> _initSocket() async {
    if (_isExplicitlyDisconnected) return; // 🚀 NEW: Don't reconnect if explicitly disconnected
    
    // Avoid multiple sockets when resuming.
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;

    final token = await AuthService.getAccessToken();
    if (token == null || token.isEmpty) return;

    final serverUrl = ApiClient.baseUrl.replaceFirst(RegExp(r'/api(?:/v1)?$'), '');
    final socket = io.io(
      serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .setReconnectionDelay(1000) // 🚀 NEW: Better reconnection settings
          .setReconnectionAttempts(5)
          .setTimeout(20000)
          .build(),
    );

    // 🚀 NEW: Better connection event handling
    socket.on('connect', (_) {
      print('🔗 Socket connected successfully');
      _isExplicitlyDisconnected = false;
    });

    socket.on('disconnect', (reason) {
      print('🔌 Socket disconnected: $reason');
      if (reason == 'io server disconnect') {
        _isExplicitlyDisconnected = true;
      }
    });

    socket.on('reconnect', (_) {
      print('🔄 Socket reconnected');
      _loadConversations(); // Recharger les conversations
    });

    socket.on('user_status', (data) {
      print('📡 [MessagesScreen] Received user_status: $data');
      if (!mounted) return;
      if (data is! Map) return;

      final userId = (data['userId'] ?? '').toString();
      final isOnline = data['isOnline'] == true;
      final timestamp = data['timestamp']; // 🚀 NEW: Log timestamp

      print('🔄 [MessagesScreen] Updating user $userId to online=$isOnline at $timestamp');
      setState(() {
        _conversations = _conversations.map((c) {
          if (c.partnerId == userId) {
            print('✅ [MessagesScreen] Found partner $userId in list, updating...');
            return c.copyWith(partnerOnline: isOnline);
          }
          return c;
        }).toList();
      });

      // 🚀 NEW: Reduce refresh delay for better responsiveness
      _presenceReloadTimer?.cancel();
      _presenceReloadTimer = Timer(const Duration(milliseconds: 300), () async {
        if (!mounted) return;
        await _loadConversations();
      });
    });

    socket.on('new_message', (_) {
      // Refresh list when a new message arrives to update last message/unread count
      _loadConversations();
    });

    socket.connect();
    _socket = socket;
  }

  Future<void> _loadConversations() async {
    try {
      final result = await MessageService.getConversations();
      if (!mounted) return;
      setState(() {
        _conversations = result;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final msg = e.toString().replaceAll('Exception: ', '');
      setState(() => _errorMessage = msg);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }

  List<ConversationModel> get _filteredConversations {
    var list = _conversations;
    if (_tabIndex == 1) {
      list = list.where((c) => c.unreadCount > 0).toList();
    }
    if (_tabIndex == 2) {
      list = const [];
    }

    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where(
            (c) =>
                c.partnerName.toLowerCase().contains(q) ||
                c.lastMessageContent.toLowerCase().contains(q),
          )
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surfaceVariant,
      body: SafeArea( // Utilise SafeArea pour éviter la bande blanche
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Messages',
                    style: TextStyle(
                      fontSize: 31,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: cs.outline),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    const Icon(
                      Icons.search,
                      color: AppColors.primaryLight,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => _query = v),
                        decoration: InputDecoration(
                          hintText: 'Search conversations',
                          hintStyle: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFFF1A77C),
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                          filled: false,
                        ),
                        style: TextStyle(
                          fontSize: 15,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Tab row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: List.generate(_tabs.length, (i) {
                  final active = i == _tabIndex;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _tabIndex = i),
                      child: Container(
                        padding: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          border: active
                              ? const Border(
                                  bottom: BorderSide(
                                    color: AppColors.primary,
                                    width: 2.5,
                                  ),
                                )
                              : null,
                        ),
                        child: Text(
                          _tabs[i],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: active
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: active
                                ? AppColors.primary
                                    : cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 10),
            // Chat list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: cs.onSurfaceVariant),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : _filteredConversations.isEmpty
                  ? const Center(
                      child: Text(
                        'No conversations',
                        style: TextStyle(color: AppColors.textGrey),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
                      itemCount: _filteredConversations.length,
                      itemBuilder: (_, i) {
                        final c = _filteredConversations[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ChatItem(
                            partnerId: c.partnerId,
                            avatarUrl: c.partnerAvatar ?? '',
                            name: c.partnerName,
                            lastMessage: c.lastMessageContent,
                            time: c.timeLabel,
                            unread: c.unreadCount,
                            online: c.partnerOnline,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatConversationScreen(
                                    partnerId: c.partnerId,
                                    partnerName: c.partnerName,
                                    partnerAvatar: c.partnerAvatar ?? '',
                                    partnerOnline: c.partnerOnline,
                                  ),
                                ),
                              );
                              if (!mounted) return;
                              await _loadConversations();
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatItem extends StatelessWidget {
  final String partnerId;
  final String avatarUrl;
  final String name;
  final String lastMessage;
  final String time;
  final int unread;
  final bool online;
  final VoidCallback onTap;

  const _ChatItem({
    required this.partnerId,
    required this.avatarUrl,
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.unread,
    required this.online,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cs.outline),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar with online indicator
              Stack(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: avatarUrl.isNotEmpty
                        ? NetworkImage(avatarUrl)
                        : null,
                    backgroundColor: cs.surfaceVariant,
                    child: avatarUrl.isEmpty
                        ? const Icon(Icons.person, color: Color(0xFF94A3B8))
                        : null,
                  ),
                  if (online)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 15,
                        height: 15,
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E), // Vert pour online
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: cs.surface,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: unread > 0
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              fontSize: 17,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 13,
                            color: unread > 0
                                ? AppColors.primary
                                : cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: online
                                ? const Color(0xFF22C55E) // Vert pour online
                                : Theme.of(context).colorScheme.outline,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          online ? 'Online' : 'Offline',
                          style: TextStyle(
                            fontSize: 12,
                            color: online
                                ? const Color(0xFF22C55E) // Vert pour online
                                : Theme.of(context).colorScheme.outline,
                            fontWeight:
                                online ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            lastMessage,
                            style: TextStyle(
                              fontSize: 14,
                              color: unread > 0
                                  ? cs.onSurface
                                  : cs.onSurfaceVariant,
                              fontWeight: unread > 0
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (unread > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            constraints: const BoxConstraints(
                              minWidth: 26,
                              minHeight: 26,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                unread > 99 ? '99+' : '$unread',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
