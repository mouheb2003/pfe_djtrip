import 'package:flutter/material.dart';
import '../../config/api_config.dart';
import '../../models/conversation_model.dart';
import '../../services/message_service.dart';

class SharePostToConversationScreen extends StatefulWidget {
  final String postId;
  final String postContent;
  final String? postImageUrl;

  const SharePostToConversationScreen({
    super.key,
    required this.postId,
    required this.postContent,
    this.postImageUrl,
  });

  @override
  State<SharePostToConversationScreen> createState() => _SharePostToConversationScreenState();
}

class _SharePostToConversationScreenState extends State<SharePostToConversationScreen> {
  List<ConversationModel> _conversations = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() => _loading = true);
    try {
      final conversations = await MessageService.getConversations();
      if (mounted) {
        setState(() {
          _conversations = conversations;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _shareToConversation(ConversationModel conversation) async {
    setState(() => _sending = true);
    try {
      final shareMessage = _buildShareMessage();
      final result = await MessageService.sendMessage(
        partnerId: conversation.partnerId,
        content: shareMessage,
      );

      if (mounted) {
        if (result['success'] == true) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Publication shared successfully')),
          );
        } else {
          setState(() => _sending = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['messageText'] ?? 'Failed to share')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing: $e')),
        );
      }
    }
  }

  String _buildShareMessage() {
    final content = widget.postContent.length > 100
        ? '${widget.postContent.substring(0, 100)}...'
        : widget.postContent;
    
    return '📱 Shared a publication:\n\n$content\n\n🔗 View publication: ${ApiConfig.serverBaseUrl}/posts/${widget.postId}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Share to Conversation'),
        backgroundColor: const Color(0xFF3049D9),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No conversations yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start a conversation to share publications',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _conversations.length,
                  itemBuilder: (context, index) {
                    final conversation = _conversations[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: conversation.partnerAvatar?.isNotEmpty == true
                            ? NetworkImage(conversation.partnerAvatar!)
                            : null,
                        child: conversation.partnerAvatar?.isEmpty == true
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(conversation.partnerName),
                      subtitle: conversation.lastMessageContent.isNotEmpty
                          ? Text(
                              conversation.lastMessageContent,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      trailing: _sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send, color: Color(0xFF3049D9)),
                      onTap: () => _shareToConversation(conversation),
                    );
                  },
                ),
    );
  }
}
