import 'dart:async';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../models/conversation_model.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/message_service.dart';
import 'chat_conversation_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen>
    with WidgetsBindingObserver {
  int _tabIndex = 0;
  final _tabs = const ['All Chats', 'Unread', 'Archived'];

  List<ConversationModel> _conversations = [];
  String _query = '';

  bool _isLoading = true;
  String? _errorMessage;
  int _dismissKeyCounter = 0;
  String? _currentUserId;

  io.Socket? _socket;

  void _disposeSocket() {
    _socket?.off('user_status');
    _socket?.off('new_message');
    _socket?.off('connect');
    _socket?.off('disconnect');
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCurrentUserId();
    _loadConversations();
    _initSocket();
  }

  Future<void> _loadCurrentUserId() async {
    final currentUser = AuthService.currentUser;
    if (currentUser != null) {
      setState(() {
        _currentUserId = currentUser['_id']?.toString();
      });
    }
  }

  @override
  void dispose() {
    _disposeSocket();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_socket == null) _initSocket();
      _loadConversations();
    } else {
      _disposeSocket();
    }
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

    socket.off('user_status');
    socket.off('new_message');
    socket.off('connect');
    socket.off('disconnect');

    socket.on('connect', (_) {});
    socket.on('disconnect', (_) {});

    socket.on('user_status', (data) {
      if (!mounted || data is! Map) return;

      final userId = (data['userId'] ?? '').toString();
      final isOnline = data['isOnline'] == true;

      setState(() {
        _conversations = _conversations.map((c) {
          if (c.partnerId == userId) {
            return c.copyWith(partnerOnline: isOnline);
          }
          return c;
        }).toList();
      });
    });

    socket.on('new_message', (_) => _loadConversations());

    socket.connect();
    _socket = socket;
  }

  Future<void> _loadConversations() async {
    try {
      final result = await MessageService.getConversations();

      print('[MessagesScreen] Loaded ${result.length} conversations');

      if (!mounted) return;

      setState(() {
        _conversations = result;
        _isLoading = false;
        _errorMessage = null;
        _dismissKeyCounter++;
      });
    } catch (e) {
      print('[MessagesScreen] Error loading conversations: $e');
      if (!mounted) return;

      setState(() {
        _conversations = [];
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _refreshConversations() async {
    await _loadConversations();
  }

  List<ConversationModel> get _filteredConversations {
    var list = _conversations;

    if (_tabIndex == 1) {
      list = list.where((c) => c.unreadCount > 0 && !c.isArchived).toList();
    } else if (_tabIndex == 2) {
      list = list.where((c) => c.isArchived).toList();
    } else {
      list = list.where((c) => !c.isArchived).toList();
    }

    final q = _query.toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((c) {
        return c.partnerName.toLowerCase().contains(q) ||
            c.lastMessageContent.toLowerCase().contains(q);
      }).toList();
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4FF),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            Row(
              children: [
                const SizedBox(width: 16),
                const Text(
                  'Messages',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4F6BFF),
                  ),
                ),
                const Spacer(),
              ],
            ),

            _SearchField(onChanged: (v) => setState(() => _query = v)),

            _TabsRow(
              labels: _tabs,
              current: _tabIndex,
              onTap: (i) => setState(() => _tabIndex = i),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshConversations,
                child: _isLoading
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 220),
                          Center(child: CircularProgressIndicator()),
                        ],
                      )
                    : _errorMessage != null
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        children: [
                          const SizedBox(height: 180),
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _errorMessage!.replaceFirst(
                                    'Exception: ',
                                    '',
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                FilledButton(
                                  onPressed: _loadConversations,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : _filteredConversations.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 220),
                          Center(child: Text('No conversations')),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredConversations.length,
                        itemBuilder: (_, i) {
                          final c = _filteredConversations[i];
                          return Dismissible(
                            key: ValueKey(
                              'conversation-${c.partnerId}-$_dismissKeyCounter',
                            ),
                            direction: DismissDirection.horizontal,
                            background: _SwipeActionBackground(
                              color: c.isArchived
                                  ? const Color(0xFF4F6BFF)
                                  : const Color(0xFF2FBF71),
                              icon: c.isArchived
                                  ? Icons.unarchive_rounded
                                  : Icons.archive_rounded,
                              label: c.isArchived ? 'Restore' : 'Archive',
                              alignment: Alignment.centerLeft,
                            ),
                            secondaryBackground: const _SwipeActionBackground(
                              color: Color(0xFFE53935),
                              icon: Icons.delete_forever_rounded,
                              label: 'Delete',
                              alignment: Alignment.centerRight,
                            ),
                            confirmDismiss: (direction) async {
                              if (direction == DismissDirection.endToStart) {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Leave Conversation'),
                                    content: const Text(
                                      'Are you sure you want to leave this conversation?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red,
                                        ),
                                        child: const Text('Leave'),
                                      ),
                                    ],
                                  ),
                                );
                                return confirmed ?? false;
                              }
                              return true;
                            },
                            onDismissed: (direction) async {
                              if (direction == DismissDirection.startToEnd) {
                                final result = c.isArchived
                                    ? await MessageService.unarchiveConversation(
                                        c.partnerId,
                                      )
                                    : await MessageService.archiveConversation(
                                        c.partnerId,
                                      );
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      result['message']?.toString() ??
                                          (c.isArchived
                                              ? 'Conversation restored'
                                              : 'Conversation archived'),
                                    ),
                                  ),
                                );
                              } else {
                                final result =
                                    await MessageService.deleteConversation(
                                      c.partnerId,
                                    );
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      result['message']?.toString() ??
                                          'Conversation left',
                                    ),
                                  ),
                                );
                              }
                              await _loadConversations();
                            },
                            child: _MessageTile(
                              conversation: c,
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatConversationScreen(
                                      partnerId: c.partnerId,
                                      partnerName: c.partnerName,
                                      partnerAvatar: c.partnerAvatar,
                                      partnerType: c.partnerType,
                                      partnerOnline: c.partnerOnline,
                                    ),
                                  ),
                                );
                                _loadConversations();
                              },
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const _SearchField({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE4E7FF)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Color(0xFF9CA3AF)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              decoration: const InputDecoration(
                hintText: 'Search conversations...',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabsRow extends StatelessWidget {
  final List<String> labels;
  final int current;
  final ValueChanged<int> onTap;

  const _TabsRow({
    required this.labels,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(labels.length, (i) {
          final active = i == current;

          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFF4F6BFF) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE4E7FF)),
                ),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: active ? Colors.white : Colors.grey,
                    fontSize: 12,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  final ConversationModel conversation;
  final VoidCallback onTap;

  const _MessageTile({required this.conversation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final unread = conversation.unreadCount > 0;
    final isAdminConversation =
        conversation.partnerType.trim().toLowerCase() == 'admin' ||
        conversation.partnerName.toLowerCase().contains('admin');
    final rawAvatar = (conversation.partnerAvatar ?? '').trim();
    final hasValidRemoteAvatar =
        rawAvatar.startsWith('http://') || rawAvatar.startsWith('https://');
    final titleName = isAdminConversation
        ? 'DJTrip Admin'
        : conversation.partnerName;

    final displayName = titleName
        .replaceAll(RegExp(r'\s*General\s*'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundImage: isAdminConversation
                  ? const AssetImage('assets/logos/app_logo.png')
                  : (hasValidRemoteAvatar ? NetworkImage(rawAvatar) : null),
              child:
                  ((conversation.partnerAvatar ?? '').isEmpty &&
                      !isAdminConversation)
                  ? const Icon(Icons.person)
                  : null,
            ),
            if (conversation.partnerOnline)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                displayName.isEmpty ? titleName : displayName,
                style: TextStyle(
                  fontWeight: unread ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
            if (isAdminConversation) ...[
              const SizedBox(width: 8),
              Container(
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
              ),
            ],
          ],
        ),
        subtitle: Text(
          isAdminConversation
              ? 'Avertissement administrateur'
              : conversation.lastMessageContent,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: unread
            ? CircleAvatar(
                radius: 10,
                backgroundColor: const Color(0xFF4F6BFF),
                child: Text(
                  '${conversation.unreadCount}',
                  style: const TextStyle(fontSize: 10, color: Colors.white),
                ),
              )
            : null,
      ),
    );
  }
}

class _SwipeActionBackground extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final Alignment alignment;

  const _SwipeActionBackground({
    required this.color,
    required this.icon,
    required this.label,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: alignment,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: alignment == Alignment.centerLeft
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.end,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
