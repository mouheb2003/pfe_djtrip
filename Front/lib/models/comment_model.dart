class CommentModel {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final String content;
  final DateTime createdAt;
  final String? userReaction;
  final int totalReactions;
  final List<CommentModel> replies;
  final Map<String, int> reactionCounts;

  const CommentModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    required this.content,
    required this.createdAt,
    this.userReaction,
    this.totalReactions = 0,
    this.replies = const [],
    this.reactionCounts = const {},
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    final author = json['author_id'] is Map<String, dynamic>
        ? json['author_id'] as Map<String, dynamic>
        : <String, dynamic>{};

    final repliesList = <CommentModel>[];
    if (json['replies'] != null && json['replies'] is List) {
      repliesList = (json['replies'] as List)
          .map((reply) => CommentModel.fromJson(reply as Map<String, dynamic>))
          .toList();
    }

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
      authorId: author['_id']?.toString() ?? author['id']?.toString() ?? '',
      authorName: author['fullname']?.toString() ?? 'Anonymous',
      authorAvatar: author['avatar']?.toString(),
      content: json['content']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      userReaction: json['user_reaction']?.toString(),
      totalReactions: (json['total_reactions'] as num?)?.toInt() ?? 0,
      replies: repliesList,
      reactionCounts: reactionCountsMap,
    );
  }

  // Create from backend comment data
  factory CommentModel.fromBackendComment(Map<String, dynamic> json, {String? userReaction}) {
    final author = json['author_id'] is Map<String, dynamic>
        ? json['author_id'] as Map<String, dynamic>
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
      id: json['_id']?.toString() ?? '',
      authorId: author['_id']?.toString() ?? '',
      authorName: author['fullname']?.toString() ?? 'Anonymous',
      authorAvatar: author['avatar']?.toString(),
      content: json['content']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      userReaction: userReaction,
      totalReactions: (json['total_reactions'] as num?)?.toInt() ?? 0,
      replies: [], // Replies will be handled separately
      reactionCounts: reactionCountsMap,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'author_id': {
        '_id': authorId,
        'fullname': authorName,
        'avatar': authorAvatar,
      },
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'user_reaction': userReaction,
      'total_reactions': totalReactions,
      'replies': replies.map((reply) => reply.toJson()).toList(),
      'reaction_counts': reactionCounts,
    };
  }

  CommentModel copyWith({
    String? id,
    String? authorId,
    String? authorName,
    String? authorAvatar,
    String? content,
    DateTime? createdAt,
    String? userReaction,
    int? totalReactions,
    List<CommentModel>? replies,
    Map<String, int>? reactionCounts,
  }) {
    return CommentModel(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      userReaction: userReaction ?? this.userReaction,
      totalReactions: totalReactions ?? this.totalReactions,
      replies: replies ?? this.replies,
      reactionCounts: reactionCounts ?? this.reactionCounts,
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
