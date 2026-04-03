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
  final _tabs = const ['All Chats', 'Unread', 'Groups', 'Archived'];

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
    _presenceReloadTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_socket == null) _initSocket();
    } else {
      _socket?.disconnect();
      _socket?.dispose();
      _socket = null;
    }
  }

  Future<void> _initSocket() async {
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
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

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

      _presenceReloadTimer?.cancel();
      _presenceReloadTimer = Timer(
        const Duration(milliseconds: 300),
        _loadConversations,
      );
    });

    socket.on('new_message', (_) => _loadConversations());

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

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  List<ConversationModel> get _filteredConversations {
    var list = _conversations;

    if (_tabIndex == 1) {
      list = list.where((c) => c.unreadCount > 0).toList();
    } else if (_tabIndex == 2) {
      list = list.where((c) => c.partnerType.toLowerCase() == 'group').toList();
    } else if (_tabIndex == 3) {
      list = [];
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
            const Text(
              'Messages',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4F6BFF),
              ),
            ),

            /// SEARCH
            _SearchField(onChanged: (v) => setState(() => _query = v)),

            /// TABS
            _TabsRow(
              labels: _tabs,
              current: _tabIndex,
              onTap: (i) => setState(() => _tabIndex = i),
            ),

            const SizedBox(height: 10),

            /// LIST
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _errorMessage!.replaceFirst('Exception: ', ''),
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
                    )
                  : _filteredConversations.isEmpty
                  ? const Center(child: Text('No conversations'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredConversations.length,
                      itemBuilder: (_, i) {
                        final c = _filteredConversations[i];

                        return _MessageTile(
                          conversation: c,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatConversationScreen(
                                  partnerId: c.partnerId,
                                  partnerName: c.partnerName,
                                  partnerAvatar: c.partnerAvatar,
                                  partnerOnline: c.partnerOnline,
                                ),
                              ),
                            );
                            _loadConversations();
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),

      /// FAB
      floatingActionButton: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4F6BFF), Color(0xFF6E8BFF)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
    );
  }
}

//// ================= UI COMPONENTS =================

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

          // Correction ici : Un simple espacement au lieu d'une décoration Border
          const SizedBox(width: 12),

          Expanded(
            child: TextField(
              onChanged: onChanged,
              decoration: const InputDecoration(
                hintText: 'Search conversations...',
                // On retire toutes les bordures internes du TextField
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
              backgroundImage: (conversation.partnerAvatar ?? '').isNotEmpty
                  ? NetworkImage(conversation.partnerAvatar!)
                  : null,
              child: (conversation.partnerAvatar ?? '').isEmpty
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
        title: Text(
          conversation.partnerName,
          style: TextStyle(
            fontWeight: unread ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        subtitle: Text(
          conversation.lastMessageContent,
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
