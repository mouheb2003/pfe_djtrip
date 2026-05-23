import 'package:flutter/material.dart';
import '../../services/follow_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import 'public_profile_screen.dart';

class RelationsScreen extends StatefulWidget {
  final String userId;
  final int initialTabIndex; // 0 for Followers, 1 for Following

  const RelationsScreen({
    super.key,
    required this.userId,
    this.initialTabIndex = 0,
  });

  @override
  State<RelationsScreen> createState() => _RelationsScreenState();
}

class _RelationsScreenState extends State<RelationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _followers = [];
  List<Map<String, dynamic>> _following = [];
  bool _isLoadingFollowers = true;
  bool _isLoadingFollowing = true;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex);
    _loadCurrentUserId();
    _loadFollowers();
    _loadFollowing();
  }

  Future<void> _loadCurrentUserId() async {
    final id = await AuthService.getUserId();
    if (mounted) {
      setState(() {
        _currentUserId = id;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFollowers() async {
    setState(() => _isLoadingFollowers = true);
    final data = await FollowService.getFollowersList(widget.userId);
    if (mounted) {
      setState(() {
        _followers = data;
        _isLoadingFollowers = false;
      });
    }
  }

  Future<void> _loadFollowing() async {
    setState(() => _isLoadingFollowing = true);
    final data = await FollowService.getFollowingList(widget.userId);
    if (mounted) {
      setState(() {
        _following = data;
        _isLoadingFollowing = false;
      });
    }
  }

  Widget _buildUserList(List<Map<String, dynamic>> users, bool isLoading, bool isFollowersTab) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (users.isEmpty) {
      return const Center(child: Text("No users found.", style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final id = (user['_id'] ?? user['id'] ?? '').toString();
        final name = '${user['prenom'] ?? ''} ${user['nom'] ?? ''}'.trim();
        final finalName = name.isEmpty ? (user['username'] ?? 'Unknown User') : name;
        final avatar = user['photo_profil'] ?? user['profileImage'] ?? '';
        final userType = user['userType'] ?? 'Tourist';

        final bool isOwner = _currentUserId == widget.userId;
        
        // Show Unfollow if we are viewing our own following list
        final bool showUnfollow = isOwner && !isFollowersTab;
        // Show Delete if we are viewing our own followers list
        final bool showDelete = isOwner && isFollowersTab;

        return ListTile(
          leading: CircleAvatar(
            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
            child: avatar.isEmpty ? const Icon(Icons.person) : null,
          ),
          title: Text(finalName, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(userType),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showUnfollow)
                TextButton(
                  onPressed: () async {
                    final res = await FollowService.unfollowUser(id);
                    if (res['success'] == true) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Unfollowed user')));
                        _loadFollowing();
                      }
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(res['message'] ?? 'Error')));
                      }
                    }
                  },
                  child: const Text('Unfollow', style: TextStyle(color: Colors.red)),
                ),
              if (showDelete)
                TextButton(
                  onPressed: () async {
                    final res = await FollowService.deleteFollower(id);
                    if (res['success'] == true) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Removed follower')));
                        _loadFollowers();
                      }
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(res['message'] ?? 'Error')));
                      }
                    }
                  },
                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                ),
            ],
          ),
          onTap: () {
            if (id.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PublicProfileScreen(userId: id),
                ),
              );
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relations', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Followers'),
            Tab(text: 'Following'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUserList(_followers, _isLoadingFollowers, true),
          _buildUserList(_following, _isLoadingFollowing, false),
        ],
      ),
    );
  }
}
