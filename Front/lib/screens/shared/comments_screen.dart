import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/comment_model.dart';
import '../../../services/post_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/time_ago.dart';

class CommentsScreen extends StatefulWidget {
  final String postId;
  final String postTitle;
  final int initialCommentsCount;

  const CommentsScreen({
    super.key,
    required this.postId,
    required this.postTitle,
    this.initialCommentsCount = 0,
  });

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;
  bool _isPostingComment = false;
  List<CommentModel> _comments = [];
  String? _replyingToId;
  String? _replyingToName;

  // Reaction types
  static const Map<String, Map<String, dynamic>> _reactionTypes = {
    'like': {'emoji': 'like', 'icon': Icons.thumb_up, 'color': Colors.blue},
    'love': {'emoji': 'love', 'icon': Icons.favorite, 'color': Colors.red},
    'laugh': {'emoji': 'laugh', 'icon': Icons.sentiment_very_satisfied, 'color': Colors.yellow},
    'wow': {'emoji': 'wow', 'icon': Icons.sentiment_neutral, 'color': Colors.orange},
    'sad': {'emoji': 'sad', 'icon': Icons.sentiment_dissatisfied, 'color': Colors.grey},
    'angry': {'emoji': 'angry', 'icon': Icons.mood_bad, 'color': Colors.red},
  };

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    
    try {
      final comments = await PostService.getPostComments(widget.postId);
      if (mounted) {
        setState(() {
          _comments = comments.map((c) => CommentModel.fromJson(c)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading comments: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isPostingComment = true);

    try {
      final result = await PostService.addPostComment(
        postId: widget.postId,
        content: text,
        parentCommentId: _replyingToId,
      );

      if (result['success'] == true) {
        _commentController.clear();
        _clearReply();
        await _loadComments();
        _scrollToBottom();
        
        if (mounted) {
          HapticFeedback.lightImpact();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']?.toString() ?? 'Failed to post comment'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error posting comment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPostingComment = false);
      }
    }
  }

  Future<void> _reactToComment(String commentId, String reactionType) async {
    try {
      await PostService.reactToComment(commentId, reactionType);
      await _loadComments();
      HapticFeedback.lightImpact();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reacting to comment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _setReply(String commentId, String authorName) {
    setState(() {
      _replyingToId = commentId;
      _replyingToName = authorName;
    });
    _commentController.requestFocus();
  }

  void _clearReply() {
    setState(() {
      _replyingToId = null;
      _replyingToName = null;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Comments',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${_comments.length} comments',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort, color: Colors.black87),
            onPressed: () {
              _showSortOptions();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Post Info Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4B63FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.article,
                    color: Color(0xFF4B63FF),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.postTitle,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E225E),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Post ID: ${widget.postId}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Comments List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF4B63FF)),
                  )
                : _comments.isEmpty
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
                              'No comments yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Be the first to share your thoughts!',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          return _CommentTile(
                            comment: _comments[index],
                            onReply: _setReply,
                            onReact: _reactToComment,
                            reactionTypes: _reactionTypes,
                          );
                        },
                      ),
          ),

          // Comment Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Reply indicator
                if (_replyingToId != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4B63FF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF4B63FF).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.reply,
                          color: Color(0xFF4B63FF),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Replying to $_replyingToName',
                          style: const TextStyle(
                            color: Color(0xFF4B63FF),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: _clearReply,
                          child: const Icon(
                            Icons.close,
                            color: Color(0xFF4B63FF),
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Input field
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: InputDecoration(
                          hintText: _replyingToId != null 
                              ? 'Write a reply...' 
                              : 'Write a comment...',
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        maxLines: 3,
                        minLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: _commentController.text.trim().isNotEmpty
                            ? const Color(0xFF4B63FF)
                            : Colors.grey[300],
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: _commentController.text.trim().isNotEmpty && !_isPostingComment
                            ? _postComment
                            : null,
                        icon: _isPostingComment
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(
                                Icons.send,
                                color: Colors.white,
                                size: 20,
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
    );
  }

  void _showSortOptions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Sort Comments',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E225E),
              ),
            ),
            const SizedBox(height: 20),
            _SortOption(
              icon: Icons.access_time,
              title: 'Newest First',
              onTap: () {
                Navigator.pop(context);
                _sortComments('newest');
              },
            ),
            _SortOption(
              icon: Icons.history,
              title: 'Oldest First',
              onTap: () {
                Navigator.pop(context);
                _sortComments('oldest');
              },
            ),
            _SortOption(
              icon: Icons.thumb_up,
              title: 'Most Liked',
              onTap: () {
                Navigator.pop(context);
                _sortComments('popular');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _sortComments(String sortBy) {
    setState(() {
      switch (sortBy) {
        case 'newest':
          _comments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          break;
        case 'oldest':
          _comments.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          break;
        case 'popular':
          _comments.sort((a, b) => b.totalReactions.compareTo(a.totalReactions));
          break;
      }
    });
  }
}

class _CommentTile extends StatefulWidget {
  final CommentModel comment;
  final Function(String commentId, String authorName) onReply;
  final Function(String commentId, String reactionType) onReact;
  final Map<String, Map<String, dynamic>> reactionTypes;

  const _CommentTile({
    required this.comment,
    required this.onReply,
    required this.onReact,
    required this.reactionTypes,
  });

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  bool _showReplies = false;
  bool _showReactions = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main comment
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFE8E5FF),
                backgroundImage: widget.comment.authorAvatar?.isNotEmpty == true
                    ? NetworkImage(widget.comment.authorAvatar!)
                    : null,
                child: widget.comment.authorAvatar?.isEmpty != false
                    ? const Icon(
                        Icons.person,
                        color: Color(0xFF4B63FF),
                        size: 20,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              
              // Comment content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Author info and time
                    Row(
                      children: [
                        Text(
                          widget.comment.authorName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E225E),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          TimeAgo.format(widget.comment.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    
                    // Comment text
                    Text(
                      widget.comment.content,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF2D3748),
                        height: 1.4,
                      ),
                    ),
                    
                    // Actions
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Reactions
                        _buildReactionButton(),
                        const SizedBox(width: 16),
                        
                        // Reply button
                        GestureDetector(
                          onTap: () => widget.onReply(widget.comment.id, widget.comment.authorName),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.reply,
                                  size: 14,
                                  color: Color(0xFF6B7280),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Reply',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
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
          
          // Replies section
          if (widget.comment.replies.isNotEmpty) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                setState(() {
                  _showReplies = !_showReplies;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showReplies ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.comment.replies.length} ${_showReplies ? 'Hide' : 'Show'} Replies',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            if (_showReplies) ...[
              const SizedBox(height: 12),
              ...widget.comment.replies.map((reply) => Padding(
                padding: const EdgeInsets.only(left: 52, bottom: 12),
                child: _CommentTile(
                  comment: reply,
                  onReply: widget.onReply,
                  onReact: widget.onReact,
                  reactionTypes: widget.reactionTypes,
                ),
              )).toList(),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildReactionButton() {
    final userReaction = widget.comment.userReaction;
    final totalReactions = widget.comment.totalReactions;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _showReactions = !_showReactions;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: userReaction != null ? const Color(0xFF4B63FF).withOpacity(0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: userReaction != null 
              ? Border.all(color: const Color(0xFF4B63FF).withOpacity(0.3))
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              userReaction != null ? _getEmoji(userReaction) : 'like',
              style: TextStyle(
                fontSize: 12,
                color: userReaction != null ? const Color(0xFF4B63FF) : Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            if (totalReactions > 0) ...[
              const SizedBox(width: 4),
              Text(
                totalReactions.toString(),
                style: TextStyle(
                  fontSize: 12,
                  color: userReaction != null ? const Color(0xFF4B63FF) : Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getEmoji(String reactionType) {
    switch (reactionType) {
      case 'like': return 'like';
      case 'love': return 'love';
      case 'laugh': return 'laugh';
      case 'wow': return 'wow';
      case 'sad': return 'sad';
      case 'angry': return 'angry';
      default: return 'like';
    }
  }
}

class _SortOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _SortOption({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              color: const Color(0xFF4B63FF),
              size: 20,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E225E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
