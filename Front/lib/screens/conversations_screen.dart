import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/message.dart';
import '../services/message_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shimmer_box.dart';
import 'chat_screen.dart';

class ConversationsScreen extends StatefulWidget {
  final int refreshTrigger;
  final String userType;

  const ConversationsScreen({
    super.key,
    this.refreshTrigger = 0,
    this.userType = 'touriste',
  });

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  List<Conversation> _conversations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    _load();

    MessageService.onMessage(_onNewMessage);
    MessageService.onMessageSent(_onNewMessageSent);
  }

  @override
  void didUpdateWidget(ConversationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.refreshTrigger != widget.refreshTrigger) {
      _load();
    }
  }

  @override
  void dispose() {
    MessageService.offMessage(_onNewMessage);
    MessageService.offMessageSent(_onNewMessageSent);

    super.dispose();
  }

  void _onNewMessage(Message msg) {
    _load();
  }

  void _onNewMessageSent(Message msg) {
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await MessageService.getConversations();

      list.sort((a, b) {
        final aTime = a.lastMessage?.createdAt ?? DateTime(2000);
        final bTime = b.lastMessage?.createdAt ?? DateTime(2000);

        return bTime.compareTo(aTime);
      });

      if (!mounted) return;

      setState(() {
        _conversations = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text('Messages', style: AppTextStyles.headlineSmall.copyWith(color: AppColors.accent)),
        automaticallyImplyLeading: false,
      ),
      body: _loading
          ? ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 8,
              itemBuilder: (_, __) => const ConversationTileSkeleton(),
            )
          : _error != null
          ? _buildError()
          : _conversations.isEmpty
          ? _buildEmpty()
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _conversations.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: Colors.grey[200]),
                itemBuilder: (context, index) =>
                    _buildTile(_conversations[index]),
              ),
            ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_outlined, size: 64, color: Colors.grey[300]),

          const SizedBox(height: 16),

          Text(
            'Could not load messages',
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
          ),

          const SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 72, color: Colors.grey[300]),

          const SizedBox(height: 16),

          Text(
            'No conversations yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[500],
            ),
          ),

          const SizedBox(height: 8),

          Text(
            widget.userType == 'organisateur'
                ? 'Tourists can contact you from activity listings'
                : 'Start a chat from an activity card',
            style: TextStyle(fontSize: 13, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(Conversation conv) {
    final last = conv.lastMessage;

    final time = last != null ? _formatTime(last.createdAt) : '';

    final preview = last?.content ?? '';

    final hasUnread = conv.unreadCount > 0;

    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              partnerId: conv.partnerId,
              partnerName: conv.partnerName,
              partnerAvatar: conv.partnerAvatar,
              partnerIsOnline: conv.isOnline,
            ),
          ),
        );

        _load();
      },

      child: Container(
        color: hasUnread ? AppColors.primary.withOpacity(0.06) : AppColors.card,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.accent,
                  backgroundImage:
                      conv.partnerAvatar != null && conv.partnerAvatar!.isNotEmpty
                          ? NetworkImage(conv.partnerAvatar!)
                          : null,
                  child: conv.partnerAvatar == null || conv.partnerAvatar!.isEmpty
                      ? Text(
                          conv.partnerName.isNotEmpty
                              ? conv.partnerName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        )
                      : null,
                ),
                if (conv.isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.online,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.card, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conv.partnerName,
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                            color: AppColors.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        time,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: hasUnread ? AppColors.primary : AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: hasUnread ? AppColors.onSurfaceVariant : Colors.grey,
                          ),
                        ),
                      ),
                      if (hasUnread)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            conv.unreadCount > 99 ? '99+' : '${conv.unreadCount}',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
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
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();

    final local = dt.toLocal();

    final today = DateTime(now.year, now.month, now.day);

    final d = DateTime(local.year, local.month, local.day);

    if (d == today) return DateFormat('HH:mm').format(local);

    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';

    return DateFormat('d MMM').format(local);
  }
}
