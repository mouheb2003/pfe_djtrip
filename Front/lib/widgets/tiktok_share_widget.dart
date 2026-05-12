import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../models/conversation_model.dart';
import '../services/message_service.dart';
import '../theme/app_theme.dart';

class TikTokShareWidget extends StatefulWidget {
  final String postId;
  final String postContent;
  final String? postImageUrl;
  final VoidCallback? onClose;

  const TikTokShareWidget({
    super.key,
    required this.postId,
    required this.postContent,
    this.postImageUrl,
    this.onClose,
  });

  @override
  State<TikTokShareWidget> createState() => _TikTokShareWidgetState();
}

class _TikTokShareWidgetState extends State<TikTokShareWidget> {
  List<ConversationModel> _conversations = [];
  bool _loading = true;
  final Set<String> _sendingToConversations = <String>{};

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() => _loading = true);
    try {
      final conversations = await MessageService.getConversations();
      
      // Filtrer les conversations admin/support
      final filteredConversations = conversations.where((conv) {
        final otherUserName = conv.partnerName.toLowerCase();
        return !otherUserName.contains('admin') && 
               !otherUserName.contains('support') &&
               !otherUserName.contains('administrator');
      }).toList();

      if (mounted) {
        setState(() {
          _conversations = filteredConversations;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _shareToConversation(ConversationModel conversation) async {
    setState(() => _sendingToConversations.add(conversation.partnerId));
    
    try {
      final messageText = widget.postImageUrl != null
          ? '${widget.postContent}\n\n📷 Shared post'
          : widget.postContent;

      await MessageService.sendMessage(
        partnerId: conversation.partnerId,
        content: messageText,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Shared to ${conversation.partnerName}'),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to share'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sendingToConversations.remove(conversation.partnerId));
      }
    }
  }

  void _shareToWhatsApp() {
    final text = widget.postImageUrl != null
        ? '${widget.postContent}\n\n📷 Shared post'
        : widget.postContent;
    Share.share(text, subject: 'Check out this post from DJTrip');
  }

  void _shareToFacebook() {
    final text = widget.postContent;
    Share.share(text, subject: 'Check out this post from DJTrip');
  }

  void _shareToTwitter() {
    final text = '${widget.postContent} #DJTrip #Djerba';
    Share.share(text, subject: 'Check out this post from DJTrip');
  }

  void _copyLink() {
    // Simuler la copie du lien
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copied to clipboard!'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                const Text(
                  'Share Post',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D245D),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: widget.onClose ?? () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Color(0xFF6D739A)),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),

          // Share options (WhatsApp, Facebook, etc.)
          Container(
            height: 80,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ShareOption(
                  icon: Icons.message,
                  label: 'WhatsApp',
                  color: const Color(0xFF25D366),
                  onTap: _shareToWhatsApp,
                ),
                _ShareOption(
                  icon: Icons.facebook,
                  label: 'Facebook',
                  color: const Color(0xFF1877F2),
                  onTap: _shareToFacebook,
                ),
                _ShareOption(
                  icon: Icons.alternate_email,
                  label: 'Twitter',
                  color: const Color(0xFF1DA1F2),
                  onTap: _shareToTwitter,
                ),
                _ShareOption(
                  icon: Icons.link,
                  label: 'Copy Link',
                  color: const Color(0xFF6B7280),
                  onTap: _copyLink,
                ),
              ],
            ),
          ),

          const Divider(height: 32, color: Color(0xFFE5E7EB)),

          // Users section
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                const Text(
                  'Share to conversation',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1D245D),
                  ),
                ),
                const Spacer(),
                if (_loading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
              ],
            ),
          ),

          // Users list
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            )
          else if (_conversations.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No conversations available',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shrinkWrap: true,
                itemCount: _conversations.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final conversation = _conversations[index];
                  final isSending = _sendingToConversations.contains(conversation.partnerId);
                  
                  return _UserTile(
                    userName: conversation.partnerName,
                    userAvatar: conversation.partnerAvatar,
                    lastMessage: conversation.lastMessageContent,
                    isSending: isSending,
                    onTap: () => _shareToConversation(conversation),
                  );
                },
              ),
            ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ShareOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final String userName;
  final String? userAvatar;
  final String lastMessage;
  final bool isSending;
  final VoidCallback onTap;

  const _UserTile({
    required this.userName,
    this.userAvatar,
    required this.lastMessage,
    required this.isSending,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: CircleAvatar(
        backgroundColor: AppColors.primary,
        radius: 24,
        backgroundImage: userAvatar != null && userAvatar!.isNotEmpty
            ? NetworkImage(userAvatar!)
            : null,
        child: (userAvatar == null || userAvatar!.isEmpty)
            ? Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              )
            : null,
      ),
      title: Text(
        userName,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFF1D245D),
        ),
      ),
      subtitle: Text(
        lastMessage.isNotEmpty ? lastMessage : 'No messages yet',
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 13,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: isSending
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : const Icon(
              Icons.send_rounded,
              color: AppColors.primary,
              size: 20,
            ),
      onTap: isSending ? null : onTap,
    );
  }
}
