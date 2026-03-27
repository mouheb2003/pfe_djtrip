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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadConversations();
    _initSocket();
  }

  @override
  void dispose() {
    print('🔴 [MessagesScreen] DISPOSE: Forcing logout...');
    
    // 🚀 NEW: Force logout before disposing
    _socket?.emit('force_logout');
    
    // Small delay to ensure the event is sent
    Future.delayed(const Duration(milliseconds: 100), () {
      WidgetsBinding.instance.removeObserver(this);
      _presenceReloadTimer?.cancel();
      _socket?.disconnect();
      _socket?.dispose();
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
        print('⏸️ App going to background, forcing logout...');
        // 🚀 NEW: Force logout on app background
        _socket?.emit('force_logout');
        
        Future.delayed(const Duration(milliseconds: 100), () {
          _socket?.disconnect();
          _socket?.dispose();
          _socket = null;
        });
        return;
        
      case AppLifecycleState.resumed:
        print('▶️ App resumed, reconnecting socket');
        if (_socket == null) {
          _initSocket();
        }
        break;
    }
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
      print('🔗 Messages Socket connected successfully');
    });

    socket.on('disconnect', (reason) {
      print('🔌 Messages Socket disconnected: $reason');
    });

    // 🚀 CRITICAL: Proper user status handling
    socket.on('user_status', (data) {
      print('📡 [MessagesScreen] Received user_status: $data');
      if (!mounted) return;
      if (data is! Map) return;

      final userId = (data['userId'] ?? '').toString();
      final isOnline = data['isOnline'] == true;
      final timestamp = data['timestamp'];

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

      // 🚀 SIMPLIFIED: Immediate UI update
      _presenceReloadTimer?.cancel();
      _presenceReloadTimer = Timer(const Duration(milliseconds: 300), () async {
        if (!mounted) return;
        await _loadConversations();
      });
    });

    socket.on('new_message', (_) {
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
      body: SafeArea(
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
                    Icon(Icons.search, color: cs.primary, size: 20),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => _query = v),
                        decoration: InputDecoration(
                          hintText: 'Search conversations',
                          hintStyle: TextStyle(
                            fontSize: 15,
                            color: cs.primary,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
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
                                    color: Color(0xFF16A34A),
                                    width: 2,
                                  ),
                                )
                              : null,
                        ),
                        child: Text(
                          _tabs[i],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                            color: active
                                ? const Color(0xFF16A34A)
                                : cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),
            // Conversation list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline,
                                  size: 64, color: cs.onSurfaceVariant),
                              const SizedBox(height: 16),
                              Text(
                                'Error loading conversations',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: cs.outline,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: _loadConversations,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _filteredConversations.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.chat_bubble_outline,
                                      size: 64, color: cs.onSurfaceVariant),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No conversations yet',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _filteredConversations.length,
                              itemBuilder: (context, index) {
                                final conv = _filteredConversations[index];
                                return _ChatItem(
                                  partnerId: conv.partnerId,
                                  avatarUrl: conv.partnerAvatar ?? '',
                                  name: conv.partnerName,
                                  lastMessage: conv.lastMessageContent,
                                  time: conv.timeLabel,
                                  unread: conv.unreadCount,
                                  online: conv.partnerOnline,
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                        builder: (_) => ChatConversationScreen(
                                          partnerId: conv.partnerId,
                                          partnerName: conv.partnerName,
                                          partnerAvatar: conv.partnerAvatar,
                                          partnerOnline: conv.partnerOnline,
                                        ),
                                      ),
                                    );
                                    _loadConversations(); // Refresh list after chat
                                  },
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
    print('🔄 [ChatItem] BUILD: name=$name, online=$online');
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Avatar with online indicator
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: cs.surfaceVariant,
                  backgroundImage: avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl.isEmpty
                      ? Icon(Icons.person, color: cs.onSurfaceVariant, size: 24)
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
                        color: const Color(0xFF22C55E), // Green for online
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
            // Chat info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.outline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMessage,
                          style: TextStyle(
                            fontSize: 14,
                            color: cs.onSurfaceVariant,
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
                          decoration: BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              unread > 99 ? '99+' : unread.toString(),
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  // 🚀 CRITICAL: Online status text
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: online
                              ? const Color(0xFF22C55E) // Green for online
                              : const Color(0xFF94A3B8), // Gray for offline
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        online ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontSize: 12,
                          color: online
                              ? const Color(0xFF22C55E) // Green for online
                              : const Color(0xFF94A3B8), // Gray for offline
                        ),
                      ),
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
}
