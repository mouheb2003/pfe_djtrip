class CommentModel {
  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final String? authorUserType;
  final String content;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? parentCommentId;
  final String? userReaction;
  final int totalReactions;
  final List<dynamic> reactions;
  final Map<String, int> reactionCounts;
  final Map<String, dynamic>? parentComment;

  const CommentModel({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    this.authorUserType,
    required this.content,
    required this.createdAt,
    this.updatedAt,
    this.parentCommentId,
    this.userReaction,
    this.totalReactions = 0,
    this.reactions = const [],
    this.reactionCounts = const {},
    this.parentComment,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    final author = json['user_id'] is Map<String, dynamic>
        ? json['user_id'] as Map<String, dynamic>
        : <String, dynamic>{};

    final reactionCountsMap = <String, int>{};
    if (json['reaction_counts'] != null && json['reaction_counts'] is Map) {
      final counts = json['reaction_counts'] as Map<String, dynamic>;
      for (final entry in counts.entries) {
        if (entry.value is num) {
          reactionCountsMap[entry.key] = (entry.value as num).toInt();
        }
      }
    }

    return CommentModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      postId: json['post_id']?.toString() ?? '',
      authorId: author['_id']?.toString() ?? author['id']?.toString() ?? '',
      authorName: author['fullname']?.toString() ?? 'Anonymous',
      authorAvatar: author['avatar']?.toString(),
      authorUserType: author['userType']?.toString(),
      content: json['content']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? json['updatedAt']?.toString() ?? ''),
      parentCommentId: json['parent_comment_id']?.toString(),
      userReaction: json['user_reaction']?.toString(),
      totalReactions: (json['total_reactions'] as num?)?.toInt() ?? 0,
      reactions: json['reactions'] ?? [],
      reactionCounts: reactionCountsMap,
      parentComment: json['parent_comment_id'],
    );
  }

  // Check if current user can edit this comment
  bool canEdit(String currentUserId) {
    return authorId == currentUserId;
  }

  // Check if current user can delete this comment
  bool canDelete(String currentUserId, bool isPostOwner, bool isAdmin) {
    if (isAdmin) return true;
    if (authorId == currentUserId) return true;
    if (isPostOwner) return true;
    return false;
  }

  CommentModel copyWith({
    String? id,
    String? postId,
    String? authorId,
    String? authorName,
    String? authorAvatar,
    String? authorUserType,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? parentCommentId,
    String? userReaction,
    int? totalReactions,
    List<dynamic>? reactions,
    Map<String, int>? reactionCounts,
    Map<String, dynamic>? parentComment,
  }) {
    return CommentModel(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      authorUserType: authorUserType ?? this.authorUserType,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      userReaction: userReaction ?? this.userReaction,
      totalReactions: totalReactions ?? this.totalReactions,
      reactions: reactions ?? this.reactions,
      reactionCounts: reactionCounts ?? this.reactionCounts,
      parentComment: parentComment ?? this.parentComment,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CommentModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'CommentModel(id: $id, authorName: $authorName, content: $content)';
  }
}
