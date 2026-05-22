import 'package:flutter/material.dart';
import '../../services/follow_service.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex);
    _loadFollowers();
    _loadFollowing();
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

  Widget _buildUserList(List<Map<String, dynamic>> users, bool isLoading) {
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

        return ListTile(
          leading: CircleAvatar(
            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
            child: avatar.isEmpty ? const Icon(Icons.person) : null,
          ),
          title: Text(finalName, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(userType),
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
          _buildUserList(_followers, _isLoadingFollowers),
          _buildUserList(_following, _isLoadingFollowing),
        ],
      ),
    );
  }
}
