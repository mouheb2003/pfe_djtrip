class PostModel {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final String? authorUserType;
  final String content;
  final String? imageUrl;
  final List<String> imageUrls;
  final String? locationLabel;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final bool isLiked;
  final bool isBookmarked;
  final bool isVerified;
  final bool isArchived;
  final List<String> hashtags;
  final List<String> mentions;
  final String? audience;

  const PostModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    this.authorUserType,
    required this.content,
    this.imageUrl,
    this.imageUrls = const [],
    this.locationLabel,
    required this.createdAt,
    this.updatedAt,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.sharesCount = 0,
    this.isLiked = false,
    this.isBookmarked = false,
    this.isVerified = false,
    this.isArchived = false,
    this.hashtags = const [],
    this.mentions = const [],
    this.audience,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    final author = json['author'] is Map<String, dynamic>
        ? json['author'] as Map<String, dynamic>
        : json['user_id'] is Map<String, dynamic>
            ? json['user_id'] as Map<String, dynamic>
            : json['author_id'] is Map<String, dynamic>
                ? json['author_id'] as Map<String, dynamic>
                : <String, dynamic>{};

    // Handle multiple image field variations
    List<String> imageUrlsList = [];
    
    // Try imageUrls (camelCase)
    if (json['imageUrls'] is List) {
      imageUrlsList = (json['imageUrls'] as List).map((e) => e.toString()).toList();
    }
    // Try image_urls (snake_case)
    else if (json['image_urls'] is List) {
      imageUrlsList = (json['image_urls'] as List).map((e) => e.toString()).toList();
    }
    // Try imageUrl (camelCase)
    else if (json['imageUrl'] is String && json['imageUrl'].toString().isNotEmpty) {
      imageUrlsList = [json['imageUrl'].toString()];
    }
    // Try image_url (snake_case)
    else if (json['image_url'] is String && json['image_url'].toString().isNotEmpty) {
      imageUrlsList = [json['image_url'].toString()];
    }

    List<String> hashtagsList = [];
    if (json['hashtags'] is List) {
      hashtagsList = (json['hashtags'] as List).map((e) => e.toString()).toList();
    }

    List<String> mentionsList = [];
    if (json['mentions'] is List) {
      mentionsList = (json['mentions'] as List).map((e) => e.toString()).toList();
    }

    return PostModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      authorId: author['_id']?.toString() ?? author['id']?.toString() ?? '',
      authorName: author['fullname']?.toString() ?? author['name']?.toString() ?? 'Anonymous',
      authorAvatar: author['avatar']?.toString(),
      authorUserType: author['userType']?.toString(),
      content: json['content']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? json['image_url']?.toString(),
      imageUrls: imageUrlsList,
      locationLabel: json['locationLabel']?.toString() ?? json['location_label']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? json['updated_at']?.toString() ?? ''),
      likesCount: (json['likesCount'] as num?)?.toInt() ?? (json['likes_count'] as num?)?.toInt() ?? 0,
      commentsCount: (json['commentsCount'] as num?)?.toInt() ?? (json['comments_count'] as num?)?.toInt() ?? 0,
      sharesCount: (json['sharesCount'] as num?)?.toInt() ?? (json['shares_count'] as num?)?.toInt() ?? 0,
      isLiked: json['isLiked'] == true || json['is_liked'] == true,
      isBookmarked: json['isBookmarked'] == true || json['is_bookmarked'] == true,
      isVerified: author['isVerified'] == true || author['is_verified'] == true,
      isArchived: json['isArchived'] == true || json['is_archived'] == true,
      hashtags: hashtagsList,
      mentions: mentionsList,
      audience: json['audience']?.toString(),
    );
  }

  String get displayImage {
    if (imageUrls.isNotEmpty) return imageUrls.first;
    if (imageUrl != null && imageUrl!.isNotEmpty) return imageUrl!;
    return '';
  }

  PostModel copyWith({
    String? id,
    String? authorId,
    String? authorName,
    String? authorAvatar,
    String? authorUserType,
    String? content,
    String? imageUrl,
    List<String>? imageUrls,
    String? locationLabel,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? likesCount,
    int? commentsCount,
    int? sharesCount,
    bool? isLiked,
    bool? isBookmarked,
    bool? isVerified,
    List<String>? hashtags,
    String? audience,
  }) {
    return PostModel(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      authorUserType: authorUserType ?? this.authorUserType,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      locationLabel: locationLabel ?? this.locationLabel,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      isLiked: isLiked ?? this.isLiked,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      isVerified: isVerified ?? this.isVerified,
      hashtags: hashtags ?? this.hashtags,
      audience: audience ?? this.audience,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PostModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'PostModel(id: $id, authorName: $authorName, content: ${content.substring(0, content.length > 30 ? 30 : content.length)}...)';
  }
}
