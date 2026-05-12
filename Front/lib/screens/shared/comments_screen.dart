import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../../models/comment_model.dart';
import '../../../models/post_model.dart';
import '../../../services/post_service.dart';
import '../../../services/auth_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/time_ago.dart';
import '../../../widgets/mention_autocomplete.dart';

class CommentsScreen extends StatefulWidget {
  final String postId;
  final String postTitle;
  final int initialCommentsCount;
  final PostModel? post;

  const CommentsScreen({
    super.key,
    required this.postId,
    required this.postTitle,
    this.initialCommentsCount = 0,
    this.post,
  });

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> with WidgetsBindingObserver {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _commentFocusNode = FocusNode();
  bool _isPostingComment = false;
  bool _isLoadingComments = false;
  bool _isLoadingReplies = false;
  List<CommentModel> _comments = [];
  // Lazy-loaded replies: Map<commentId, List<CommentModel>>
  final Map<String, List<CommentModel>> _repliesMap = {};
  final Map<String, bool> _repliesLoadingMap = {};
  String? _replyingToId;
  String? _replyingToName;
  String? _currentUserId;
  String? _postOwnerId;
  String? _currentUserRole;
  
  // Request cancellation token to prevent duplicate requests
  String? _currentRequestId;

  // Socket.io
  io.Socket? _socket;

  // Reaction emojis
  static const List<String> _reactionEmojis = ['❤️', '👏', '🔥', '😂', '😮', '😢', '👍', '🎉'];
  
  // Reaction types - all reactions use red color when selected
  static const Map<String, Map<String, dynamic>> _reactionTypes = {
    'like': {'emoji': '👍', 'icon': Icons.thumb_up, 'color': Colors.red},
    'love': {'emoji': '❤️', 'icon': Icons.favorite, 'color': Colors.red},
    'laugh': {'emoji': '😂', 'icon': Icons.sentiment_very_satisfied, 'color': Colors.red},
    'wow': {'emoji': '😮', 'icon': Icons.sentiment_neutral, 'color': Colors.red},
    'sad': {'emoji': '😢', 'icon': Icons.sentiment_dissatisfied, 'color': Colors.red},
    'angry': {'emoji': '😢', 'icon': Icons.mood_bad, 'color': Colors.red},
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    print('[COMMENTS SCREEN] initState - postId: ${widget.postId}');
    if (widget.postId.isEmpty) {
      print('[COMMENTS SCREEN] ERROR: postId is empty!');
    }
    _loadUserInfo();
    _loadComments();
    // _initSocket(); // Temporarily disabled to fix display issues
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Reload comments when app becomes visible again
    if (state == AppLifecycleState.resumed) {
      print('[COMMENTS SCREEN] App resumed, reloading comments');
      _loadComments();
    }
  }

  @override
  void didUpdateWidget(CommentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload comments if postId changes
    if (oldWidget.postId != widget.postId) {
      print('[COMMENTS SCREEN] PostId changed from ${oldWidget.postId} to ${widget.postId}, reloading comments');
      _resetState();
      _loadComments();
    }
  }

  void _resetState() {
    if (mounted) {
      setState(() {
        _comments = [];
        _repliesMap.clear();
        _repliesLoadingMap.clear();
        _currentRequestId = null;
      });
    }
  }

  Future<void> _loadUserInfo() async {
    // Get current user from AuthService
    final currentUser = AuthService.currentUser;
    if (currentUser != null) {
      setState(() {
        _currentUserId = currentUser['_id']?.toString();
        _currentUserRole = currentUser['role']?.toString();
      });
    }
    
    // Get post owner ID
    if (widget.post != null) {
      setState(() {
        _postOwnerId = widget.post!.authorId;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _commentController.dispose();
    _scrollController.dispose();
    _commentFocusNode.dispose();
    _disposeSocket();
    super.dispose();
  }

  void _initSocket() async {
    final token = await AuthService.getAccessToken();
    if (token == null) return;

    try {
      _socket = io.io(
        'http://10.0.2.2:3000', // For Android emulator
        // 'http://localhost:3000', // For iOS simulator
        <String, dynamic>{
          'transports': ['websocket'],
          'auth': {'token': token},
        },
      );

      _socket!.on('connect', (_) {
        print('Socket connected');
        _socket!.emit('comment:subscribe', {'postId': widget.postId});
      });

      _socket!.on('comment:created', (data) {
        if (mounted) {
          final newComment = CommentModel.fromJson(data);
          setState(() {
            if (!_comments.any((c) => c.id == newComment.id)) {
              _comments.add(newComment);
            }
          });
          HapticFeedback.lightImpact();
        }
      });

      _socket!.on('comment:deleted', (data) {
        if (mounted) {
          setState(() {
            _comments.removeWhere((c) => c.id == data['commentId']);
          });
          HapticFeedback.lightImpact();
        }
      });

      _socket!.on('comment:updated', (data) {
        if (mounted) {
          final updatedComment = CommentModel.fromJson(data);
          setState(() {
            final index = _comments.indexWhere((c) => c.id == updatedComment.id);
            if (index != -1) {
              _comments[index] = updatedComment;
            }
          });
        }
      });

      _socket!.on('disconnect', (_) {
        print('Socket disconnected');
      });

      _socket!.on('error', (error) {
        print('Socket error: $error');
      });
    } catch (e) {
      print('Socket initialization error: $e');
    }
  }

  void _disposeSocket() {
    if (_socket != null) {
      _socket!.emit('comment:unsubscribe', {'postId': widget.postId});
      _socket!.off('comment:created');
      _socket!.off('comment:deleted');
      _socket!.off('comment:updated');
      _socket!.off('connect');
      _socket!.off('disconnect');
      _socket!.off('error');
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
  }

  Future<void> _loadComments() async {
    // Generate unique request ID
    final requestId = DateTime.now().millisecondsSinceEpoch.toString();
    _currentRequestId = requestId;
    
    try {
      print('[LOAD COMMENTS] Loading comments for postId: ${widget.postId}, requestId: $requestId');
      
      // Set loading state
      if (mounted) {
        setState(() {
          _isLoadingComments = true;
        });
      }
      
      final comments = await PostService.getPostComments(widget.postId);
      print('[LOAD COMMENTS] Received ${comments.length} comments');
      
      // Check if this is still the current request
      if (_currentRequestId != requestId) {
        print('[LOAD COMMENTS] Request cancelled, newer request in progress');
        return;
      }
      
      if (mounted) {
        final allComments = comments.map((json) => CommentModel.fromJson(json)).toList();
        print('[LOAD COMMENTS] Parsed ${allComments.length} comments');
        
        setState(() {
          _comments = allComments;
          _isLoadingComments = false;
        });
        
        print('[LOAD COMMENTS] State updated with ${_comments.length} comments');
      }
    } catch (e) {
      print('[LOAD COMMENTS] Error loading comments: $e');
      if (mounted) {
        setState(() {
          _isLoadingComments = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading comments: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadReplies(String commentId) async {
    // Check if already loaded or loading
    if (_repliesMap.containsKey(commentId) || _repliesLoadingMap[commentId] == true) {
      print('[LOAD REPLIES] Already loaded or loading for comment $commentId');
      return;
    }

    try {
      print('[LOAD REPLIES] Loading replies for commentId: $commentId');
      
      // Set loading state for this specific comment
      if (mounted) {
        setState(() {
          _repliesLoadingMap[commentId] = true;
        });
      }
      
      final result = await PostService.getCommentReplies(
        commentId: commentId,
        page: 1,
        limit: 10,
      );
      
      if (result['success'] == true && mounted) {
        final replies = (result['replies'] as List)
            .map((json) => CommentModel.fromJson(json))
            .toList();
        
        setState(() {
          _repliesMap[commentId] = replies;
          _repliesLoadingMap[commentId] = false;
        });
        
        print('[LOAD REPLIES] Loaded ${replies.length} replies for comment $commentId');
      } else if (mounted) {
        setState(() {
          _repliesLoadingMap[commentId] = false;
        });
      }
    } catch (e) {
      print('[LOAD REPLIES] Error loading replies: $e');
      if (mounted) {
        setState(() {
          _repliesLoadingMap[commentId] = false;
        });
      }
    }
  }

  void _toggleReplies(String commentId) {
    if (_repliesMap.containsKey(commentId)) {
      // Hide replies
      setState(() {
        _repliesMap.remove(commentId);
      });
    } else {
      // Load and show replies
      _loadReplies(commentId);
    }
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isPostingComment = true);

    // Create optimistic comment for immediate UI update
    final optimisticComment = CommentModel(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      postId: widget.postId,
      authorId: _currentUserId ?? '',
      authorName: 'You',
      authorAvatar: null,
      content: text,
      createdAt: DateTime.now(),
      parentCommentId: _replyingToId,
      depth: _replyingToId != null ? 1 : 0,
    );

    // Add optimistic comment to UI
    setState(() {
      if (_replyingToId != null) {
        // It's a reply, add to replies
        _comments.add(optimisticComment);
      } else {
        // It's a root comment, add to beginning
        _comments.insert(0, optimisticComment);
      }
    });

    _commentController.clear();
    _clearReply();
    _scrollToBottom();

    try {
      final result = await PostService.addPostComment(
        postId: widget.postId,
        content: text,
        parentCommentId: _replyingToId,
      );

      if (result['success'] == true) {
        // Replace optimistic comment with real one
        if (result['comment'] != null) {
          final realComment = CommentModel.fromJson(result['comment']);
          setState(() {
            final index = _comments.indexWhere((c) => c.id == optimisticComment.id);
            if (index != -1) {
              _comments[index] = realComment;
            }
          });
        }
        
        if (mounted) {
          HapticFeedback.lightImpact();
        }
      } else {
        // Rollback optimistic update
        setState(() {
          _comments.removeWhere((c) => c.id == optimisticComment.id);
        });
        
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
      // Rollback optimistic update on error
      setState(() {
        _comments.removeWhere((c) => c.id == optimisticComment.id);
      });
      
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
    debugPrint('Reacting to comment: $commentId with type: $reactionType');
    
    // Check if it's a reply or root comment
    final isReply = _comments.any((c) => c.id != commentId) || 
                   _repliesMap.values.any((replies) => replies.any((r) => r.id == commentId));
    
    // Find the comment in root comments
    final commentIndex = _comments.indexWhere((c) => c.id == commentId);
    
    CommentModel? targetComment;
    int? targetIndex;
    String? parentCommentId;
    
    if (commentIndex != -1) {
      // It's a root comment
      targetComment = _comments[commentIndex];
      targetIndex = commentIndex;
    } else {
      // It's a reply - find it in the replies map
      for (final entry in _repliesMap.entries) {
        final replyIndex = entry.value.indexWhere((r) => r.id == commentId);
        if (replyIndex != -1) {
          targetComment = entry.value[replyIndex];
          targetIndex = replyIndex;
          parentCommentId = entry.key;
          break;
        }
      }
    }
    
    if (targetComment == null) {
      debugPrint('Comment not found: $commentId');
      return;
    }
    
    final oldComment = targetComment;
    
    // Toggle reaction locally
    final currentReaction = oldComment.userReaction;
    final isRemoving = currentReaction == reactionType;
    
    final newReactions = List<Map<String, dynamic>>.from(oldComment.reactions);
    final newTotalReactions = isRemoving 
        ? (oldComment.totalReactions ?? 0) - 1
        : (oldComment.totalReactions ?? 0) + 1;
    
    if (isRemoving) {
      newReactions.removeWhere((r) => r['user_id'] == _currentUserId);
    } else {
      newReactions.removeWhere((r) => r['user_id'] == _currentUserId);
      newReactions.add({
        'user_id': _currentUserId,
        'type': reactionType,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
    
    final updatedComment = CommentModel(
      id: oldComment.id,
      postId: widget.postId,
      content: oldComment.content,
      authorId: oldComment.authorId,
      authorName: oldComment.authorName,
      authorAvatar: oldComment.authorAvatar,
      createdAt: oldComment.createdAt,
      updatedAt: oldComment.updatedAt,
      reactions: newReactions,
      totalReactions: newTotalReactions,
      userReaction: isRemoving ? null : reactionType,
      parentCommentId: oldComment.parentCommentId,
    );
    
    // Update UI immediately
    setState(() {
      if (parentCommentId != null) {
        // It's a reply - update in replies map
        final replies = List<CommentModel>.from(_repliesMap[parentCommentId] ?? []);
        replies[targetIndex!] = updatedComment;
        _repliesMap[parentCommentId] = replies;
      } else {
        // It's a root comment
        _comments[commentIndex] = updatedComment;
      }
    });
    
    HapticFeedback.lightImpact();
    
    // Send to server in background
    try {
      await PostService.reactToComment(commentId, reactionType);
      debugPrint('Reaction successful');
      // Reload to sync with server state
      await _loadComments();
    } catch (e) {
      debugPrint('Error reacting to comment: $e');
      // Revert on error
      if (mounted) {
        setState(() {
          if (parentCommentId != null) {
            final replies = List<CommentModel>.from(_repliesMap[parentCommentId] ?? []);
            replies[targetIndex!] = oldComment;
            _repliesMap[parentCommentId] = replies;
          } else {
            _comments[commentIndex] = oldComment;
          }
        });
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
    _commentFocusNode.requestFocus();
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
              widget.postTitle,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz, color: Colors.black87),
            onPressed: () {
              // TODO: Show more options
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Post Preview
          if (widget.post != null) _buildPostPreview(),

          // Comments List
          Expanded(
            child: _isLoadingComments && _comments.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF4B63FF),
                    ),
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
                    : RefreshIndicator(
                        onRefresh: () async {
                          print('[COMMENTS SCREEN] Manual refresh triggered');
                          _resetState();
                          await _loadComments();
                        },
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _comments.length,
                          itemBuilder: (context, index) {
                            final comment = _comments[index];
                            final replies = _repliesMap[comment.id] ?? [];
                            final isLoadingReplies = _repliesLoadingMap[comment.id] == true;
                            
                            return _CommentTree(
                              comment: comment,
                              replies: replies,
                              isLoadingReplies: isLoadingReplies,
                              currentUserId: _currentUserId,
                              postOwnerId: _postOwnerId,
                              currentUserRole: _currentUserRole,
                              onReply: _setReply,
                              onReact: _reactToComment,
                              onEdit: (commentId, newContent) async {
                                setState(() => _isPostingComment = true);
                                try {
                                  final result = await PostService.updateComment(commentId, newContent);
                                  if (result['success'] == true) {
                                    await _loadComments();
                                    HapticFeedback.lightImpact();
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Comment updated successfully'),
                                          backgroundColor: Colors.green,
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  } else {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(result['message'] ?? 'Failed to update comment'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error updating comment: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(() => _isPostingComment = false);
                                  }
                                }
                              },
                              onDelete: (commentId) async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Comment'),
                                    content: const Text('Are you sure you want to delete this comment?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  setState(() => _isPostingComment = true);
                                  try {
                                    final result = await PostService.deleteComment(commentId);
                                    if (result['success'] == true) {
                                      await _loadComments();
                                      HapticFeedback.lightImpact();
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Error deleting comment: $e'),
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
                              },
                              onToggleReplies: _toggleReplies,
                              postReply: (content, parentCommentId) async {
                                setState(() => _isPostingComment = true);
                                
                                try {
                                  print('[POST REPLY] Calling API with parentCommentId: $parentCommentId');
                                  final result = await PostService.addPostComment(
                                    postId: widget.postId,
                                    content: content,
                                    parentCommentId: parentCommentId,
                                  );
                                  print('[POST REPLY] API result: $result');
                                  
                                  if (result['success'] == true) {
                                    // Reload replies for this comment
                                    await _loadReplies(parentCommentId);
                                    
                                    // Update parent comment's reply count
                                    setState(() {
                                      final parentIndex = _comments.indexWhere((c) => c.id == parentCommentId);
                                      if (parentIndex != -1) {
                                        final parentComment = _comments[parentIndex];
                                        _comments[parentIndex] = parentComment.copyWith(
                                          repliesCount: parentComment.repliesCount + 1,
                                        );
                                      }
                                    });
                                    
                                    HapticFeedback.lightImpact();
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Reply posted successfully'),
                                          backgroundColor: Colors.green,
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  } else {
                                    print('[POST REPLY] API returned failure: ${result['message']}');
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(result['message'] ?? 'Failed to post reply'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                } catch (e) {
                                  print('[POST REPLY] Error: $e');
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error posting reply: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(() => _isPostingComment = false);
                                  }
                                }
                              },
                            );
                          },
                        ),
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

                
                _buildReactionEmojis(),
                
                const SizedBox(height: 8),
                
                // Input field
                GestureDetector(
                  onTap: () {
                    _commentFocusNode.requestFocus();
                  },
                  child: Row(
                    children: [
                      // User avatar
                      _buildUserAvatar(),
                      const SizedBox(width: 12),
                      
                      Expanded(
                        child: Stack(
                          children: [
                            TextField(
                              controller: _commentController,
                              focusNode: _commentFocusNode,
                              decoration: InputDecoration(
                                hintText: _replyingToName != null
                                    ? 'Reply to $_replyingToName'
                                    : 'Add a comment...',
                                hintStyle: TextStyle(color: Colors.grey[400]),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Colors.grey[100],
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              maxLines: null,
                              textInputAction: TextInputAction.newline,
                            ),
                            MentionAutocomplete(
                              controller: _commentController,
                              focusNode: _commentFocusNode,
                              onMentionSelected: (username) {
                                // Mention inserted automatically
                              },
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(width: 8),
                      
                      // Send button
                      _isPostingComment
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF4B63FF),
                              ),
                            )
                          : IconButton(
                              onPressed: _commentController.text.trim().isEmpty
                                  ? null
                                  : _postComment,
                              icon: const Icon(
                                Icons.send,
                                color: Color(0xFF4B63FF),
                              ),
                            ),
                    ],
                  ),
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

  Widget _buildPostPreview() {
    final post = widget.post!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFE8E5FF),
            backgroundImage: post.authorAvatar?.isNotEmpty == true
                ? NetworkImage(post.authorAvatar!)
                : null,
            child: post.authorAvatar?.isEmpty != false
                ? const Icon(
                    Icons.person,
                    color: Color(0xFF4B63FF),
                    size: 20,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      post.authorName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E225E),
                      ),
                    ),
                    if (post.isVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.verified,
                        color: Colors.blue,
                        size: 14,
                      ),
                    ],
                    const SizedBox(width: 8),
                    Text(
                      TimeAgo.format(post.createdAt).toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  post.content,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF2D3748),
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAvatar() {
    final currentUser = AuthService.currentUser;
    final String? photoUrl = currentUser?['photo'];
    final String userName = currentUser?['username'] ?? currentUser?['name'] ?? 'User';
    final String firstLetter = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';
    
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 16,
        backgroundColor: const Color(0xFFE8E5FF),
        backgroundImage: NetworkImage(photoUrl),
        onBackgroundImageError: (exception, stackTrace) {
          // Fallback to initial if image fails to load
        },
        child: photoUrl.isEmpty ? null : null, // Show initial if no photo
      );
    }
    
    // Default avatar with icon
    return CircleAvatar(
      radius: 16,
      backgroundColor: const Color(0xFFE8E5FF),
      child: Icon(
        Icons.person,
        size: 18,
        color: const Color(0xFF4B63FF),
      ),
    );
  }

  Widget _buildReactionEmojis() {
    return Container(
      height: 40,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: _reactionEmojis.map((emoji) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _commentController.text += emoji;
                  });
                  // Move cursor to end of text
                  _commentController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _commentController.text.length),
                  );
                  // Request focus to ensure keyboard is active
                  _commentFocusNode.requestFocus();
                  HapticFeedback.lightImpact();
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _CommentTree extends StatefulWidget {
  final CommentModel comment;
  final List<CommentModel> replies;
  final bool isLoadingReplies;
  final String? currentUserId;
  final String? postOwnerId;
  final String? currentUserRole;
  final Function(String commentId, String authorName) onReply;
  final Function(String commentId, String reactionType) onReact;
  final Function(String commentId, String newContent) onEdit;
  final Function(String commentId) onDelete;
  final Function(String commentId) onToggleReplies;
  final Function(String content, String parentCommentId) postReply;

  const _CommentTree({
    required this.comment,
    required this.replies,
    required this.isLoadingReplies,
    required this.currentUserId,
    required this.postOwnerId,
    required this.currentUserRole,
    required this.onReply,
    required this.onReact,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleReplies,
    required this.postReply,
  });

  @override
  State<_CommentTree> createState() => _CommentTreeState();
}

class _CommentTreeState extends State<_CommentTree> {
  bool _showReplyField = false;
  bool _isEditing = false;
  bool _isPostingReply = false;
  final TextEditingController _replyController = TextEditingController();
  final FocusNode _replyFocusNode = FocusNode();

  bool get _canEdit {
    return widget.comment.authorId == widget.currentUserId;
  }

  bool get _canDelete {
    final isOwner = widget.comment.authorId == widget.currentUserId;
    final isPostOwner = widget.currentUserId == widget.postOwnerId;
    final isAdmin = widget.currentUserRole == 'admin';
    return isOwner || isPostOwner || isAdmin;
  }

  void _showEditDialog() {
    final controller = TextEditingController(text: widget.comment.content);
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Comment'),
          content: TextField(
            controller: controller,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Edit your comment...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: _isEditing
                  ? null
                  : () async {
                      final newContent = controller.text.trim();
                      if (newContent.isNotEmpty) {
                        setDialogState(() => _isEditing = true);
                        try {
                          await widget.onEdit(widget.comment.id, newContent);
                          if (mounted) {
                            Navigator.pop(context);
                          }
                        } catch (e) {
                          if (mounted) {
                            setDialogState(() => _isEditing = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error updating comment: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    },
              child: _isEditing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _replyController.dispose();
    _replyFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasReplies = widget.comment.repliesCount > 0;
    final showReplies = widget.replies.isNotEmpty;
    final indentation = widget.comment.depth * 16.0;
    final isNested = widget.comment.depth > 0;
    final avatarSize = isNested ? 16.0 : 20.0;
    final fontSize = isNested ? 12.0 : 14.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Comment content
        Container(
          margin: EdgeInsets.only(
            bottom: hasReplies ? 8 : 16,
            left: isNested ? indentation : 0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              CircleAvatar(
                radius: avatarSize,
                backgroundColor: const Color(0xFFE8E5FF),
                backgroundImage: widget.comment.authorAvatar?.isNotEmpty == true
                    ? NetworkImage(widget.comment.authorAvatar!)
                    : null,
                child: widget.comment.authorAvatar?.isEmpty != false
                    ? Icon(
                        Icons.person,
                        color: const Color(0xFF4B63FF),
                        size: avatarSize,
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
                          widget.comment.authorId == widget.currentUserId ? 'You' : widget.comment.authorName,
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E225E),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          TimeAgo.format(widget.comment.createdAt),
                          style: TextStyle(
                            fontSize: fontSize - 2,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    
                    // Comment text with mention highlighting
                    _buildCommentContent(widget.comment.content, fontSize),
                    
                    // Actions
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // Reactions
                        GestureDetector(
                          onTap: () => widget.onReact(widget.comment.id, 'love'),
                          child: Row(
                            children: [
                              Icon(
                                widget.comment.userReaction != null 
                                    ? Icons.favorite 
                                    : Icons.favorite_border,
                                size: fontSize + 2,
                                color: widget.comment.userReaction != null 
                                    ? Colors.red 
                                    : const Color(0xFF6B7280),
                              ),
                              if (widget.comment.totalReactions > 0) ...[
                                const SizedBox(width: 4),
                                Text(
                                  widget.comment.totalReactions.toString(),
                                  style: TextStyle(
                                    fontSize: fontSize,
                                    color: widget.comment.userReaction != null 
                                        ? Colors.red 
                                        : const Color(0xFF6B7280),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        
                        // Reply button (only if depth < 3)
                        if (widget.comment.depth < 3)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _showReplyField = !_showReplyField;
                              });
                              if (_showReplyField) {
                                Future.delayed(const Duration(milliseconds: 100), () {
                                  _replyFocusNode.requestFocus();
                                });
                              }
                            },
                            child: Text(
                              _showReplyField ? 'Cancel' : 'Reply',
                              style: TextStyle(
                                fontSize: fontSize,
                                color: _showReplyField ? Colors.red : Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        
                        // Edit button
                        if (_canEdit)
                          GestureDetector(
                            onTap: _showEditDialog,
                            child: Icon(
                              Icons.edit,
                              size: fontSize,
                              color: Colors.grey,
                            ),
                          ),
                        
                        const SizedBox(width: 8),
                        
                        // Delete button
                        if (_canDelete)
                          GestureDetector(
                            onTap: () => widget.onDelete(widget.comment.id),
                            child: Icon(
                              Icons.delete_outline,
                              size: fontSize,
                              color: Colors.grey,
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
        
        // Inline reply field with animation
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: _showReplyField
              ? Padding(
                  padding: EdgeInsets.only(left: isNested ? 44 : 52),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _replyController,
                        focusNode: _replyFocusNode,
                        decoration: InputDecoration(
                          hintText: 'Write a reply...',
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          suffixIcon: IconButton(
                            icon: _isPostingReply
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.send, color: Color(0xFF4B63FF)),
                            onPressed: _isPostingReply
                                ? null
                                : () async {
                                    final replyText = _replyController.text.trim();
                                    if (replyText.isNotEmpty) {
                                      setState(() => _isPostingReply = true);
                                      try {
                                        await widget.postReply(replyText, widget.comment.id);
                                        _replyController.clear();
                                        setState(() {
                                          _showReplyField = false;
                                        });
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Error posting reply: $e'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      } finally {
                                        if (mounted) {
                                          setState(() => _isPostingReply = false);
                                        }
                                      }
                                    }
                                  },
                          ),
                        ),
                        maxLines: 3,
                        minLines: 1,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        
        // Nested replies with lazy loading
        if (hasReplies)
          Padding(
            padding: EdgeInsets.only(left: isNested ? 32 : 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // View/hide replies button
                if (!showReplies)
                  GestureDetector(
                    onTap: () {
                      widget.onToggleReplies(widget.comment.id);
                      HapticFeedback.lightImpact();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: widget.isLoadingReplies
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF4B63FF),
                              ),
                            )
                          : Text(
                              'View ${widget.comment.repliesCount} ${widget.comment.repliesCount == 1 ? 'reply' : 'replies'}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF4B63FF),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hide replies button
                      GestureDetector(
                        onTap: () {
                          widget.onToggleReplies(widget.comment.id);
                          HapticFeedback.lightImpact();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: const Text(
                            'Hide replies',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF4B63FF),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      // Render replies
                      ...widget.replies.map((reply) => _CommentTree(
                            comment: reply,
                            replies: [], // No nested replies for now
                            isLoadingReplies: false,
                            currentUserId: widget.currentUserId,
                            postOwnerId: widget.postOwnerId,
                            currentUserRole: widget.currentUserRole,
                            onReply: widget.onReply,
                            onReact: widget.onReact,
                            onEdit: widget.onEdit,
                            onDelete: widget.onDelete,
                            onToggleReplies: widget.onToggleReplies,
                            postReply: widget.postReply,
                          )),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCommentContent(String content, double fontSize) {
    final RegExp mentionRegex = RegExp(r'@(\w+)');
    final matches = mentionRegex.allMatches(content);
    
    if (matches.isEmpty) {
      return Text(
        content,
        style: TextStyle(
          fontSize: fontSize,
          color: const Color(0xFF2D3748),
          height: 1.4,
        ),
      );
    }

    final List<TextSpan> spans = [];
    int lastMatchEnd = 0;

    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: content.substring(lastMatchEnd, match.start),
          style: TextStyle(
            fontSize: fontSize,
            color: const Color(0xFF2D3748),
            height: 1.4,
          ),
        ));
      }

      spans.add(TextSpan(
        text: match.group(0),
        style: TextStyle(
          fontSize: fontSize,
          color: const Color(0xFF4B63FF),
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
      ));

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < content.length) {
      spans.add(TextSpan(
        text: content.substring(lastMatchEnd),
        style: TextStyle(
          fontSize: fontSize,
          color: const Color(0xFF2D3748),
          height: 1.4,
        ),
      ));
    }

    return Text.rich(TextSpan(children: spans));
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
