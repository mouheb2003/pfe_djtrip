import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class ScreenNetwork extends StatefulWidget {
  const ScreenNetwork({super.key});

  @override
  State<ScreenNetwork> createState() => _ScreenNetworkState();
}

class _ScreenNetworkState extends State<ScreenNetwork> {
  final List<NetworkPost> _posts = [
    NetworkPost(
      id: '1',
      username: 'Amel Ben Salem',
      avatar: 'https://via.placeholder.com/50',
      timeAgo: '2 HOURS AGO',
      category: 'ART & CULTURE',
      image:
          'https://via.placeholder.com/400x300?text=Djerba+Art', // Colorful art
      likes: 1240,
      comments: 48,
      description:
          'Lost in the colors of #Djerbahood. Every corner tells a story. Highly recommend the sunset walk through the village. 🎨✨',
    ),
    NetworkPost(
      id: '2',
      username: 'Youssef Trabelsi',
      avatar: 'https://via.placeholder.com/50',
      timeAgo: '4 HOURS AGO • FLAMINGO ISLAND',
      category: 'NATURE',
      image:
          'https://via.placeholder.com/400x300?text=Flamingos+Sunset', // Beach sunset
      likes: 850,
      comments: 12,
      description:
          'Finally made it to see the flamingos! The boat trip from Mount Souk was incredible. The water is actually blue. 💛🌊',
    ),
    NetworkPost(
      id: '3',
      username: 'Sarah Miller',
      avatar: 'https://via.placeholder.com/50',
      timeAgo: '6 HOURS AGO • DJERBA POTTERY',
      category: 'CRAFTS',
      image:
          'https://via.placeholder.com/400x300?text=Pottery+Workshop', // Pottery
      likes: 2400,
      comments: 156,
      description:
          'Spent the morning in Guellala learning the secrets of Djerbian pottery. 🏺 The craftsmanship is out of this world.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surfaceVariant,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            backgroundColor: cs.surface,
            elevation: 0,
            pinned: true,
            automaticallyImplyLeading: false,
            centerTitle: true,
            title: Text(
              'Network',
              style: TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: 24,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_none),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.message_outlined),
                onPressed: () {},
              ),
            ],
          ),
          // Posts Feed
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _NetworkPostCard(post: _posts[index]),
              childCount: _posts.length,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Post Model ───────────────────────────────────────────────────────────────

class NetworkPost {
  final String id;
  final String username;
  final String avatar;
  final String timeAgo;
  final String category;
  final String image;
  final int likes;
  final int comments;
  final String description;

  NetworkPost({
    required this.id,
    required this.username,
    required this.avatar,
    required this.timeAgo,
    required this.category,
    required this.image,
    required this.likes,
    required this.comments,
    required this.description,
  });
}

// ── Post Card ────────────────────────────────────────────────────────────────

class _NetworkPostCard extends StatefulWidget {
  final NetworkPost post;
  const _NetworkPostCard({required this.post});

  @override
  State<_NetworkPostCard> createState() => _NetworkPostCardState();
}

class _NetworkPostCardState extends State<_NetworkPostCard> {
  late bool _isLiked;

  @override
  void initState() {
    super.initState();
    _isLiked = false;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      color: cs.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar, Name, Time, Menu
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(widget.post.avatar),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.post.username,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: cs.onSurface,
                        ),
                      ),
                      Text(
                        widget.post.timeAgo,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
              ],
            ),
          ),
          // Category Badge
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                widget.post.category,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Image
          SizedBox(
            height: 250,
            width: double.infinity,
            child: Image.network(
              widget.post.image,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[300],
                  child: const Center(child: Icon(Icons.image_not_supported)),
                );
              },
            ),
          ),
          // Interaction Bar: Likes, Comments, Shares
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _isLiked = !_isLiked),
                  child: Row(
                    children: [
                      Icon(
                        _isLiked ? Icons.favorite : Icons.favorite_border,
                        color: _isLiked ? Colors.red : cs.onSurface,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.post.likes}',
                        style: TextStyle(fontSize: 12, color: cs.onSurface),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Row(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 20,
                      color: cs.onSurface,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.post.comments}',
                      style: TextStyle(fontSize: 12, color: cs.onSurface),
                    ),
                  ],
                ),
                const Spacer(),
                Icon(Icons.share_outlined, size: 20, color: cs.onSurface),
              ],
            ),
          ),
          // Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              widget.post.description,
              style: TextStyle(fontSize: 13, color: cs.onSurface),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
