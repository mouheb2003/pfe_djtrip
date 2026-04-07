import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_client.dart';
import '../../services/message_service.dart';
import '../../theme/app_theme.dart';
import 'chat_conversation_screen.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  bool _openingChat = false;

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return null;
  }

  List<Map<String, dynamic>> _extractUsers(dynamic decoded) {
    dynamic users;
    if (decoded is Map<String, dynamic>) {
      users = decoded['users'];
      if (users == null && decoded['data'] is Map<String, dynamic>) {
        users = (decoded['data'] as Map<String, dynamic>)['users'];
      }
      if (users == null && decoded['data'] is List) {
        users = decoded['data'];
      }
    }

    if (users is! List) return const <Map<String, dynamic>>[];

    return users.map(_asMap).whereType<Map<String, dynamic>>().toList();
  }

  void _showInfo(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.primary),
    );
  }

  Future<Map<String, dynamic>?> _findAdminUser() async {
    final response = await ApiClient.get('/users/all', auth: false);
    if (response.statusCode != 200) {
      throw Exception('Unable to load support contact');
    }

    final decoded = jsonDecode(response.body);
    final users = _extractUsers(decoded);
    if (users.isEmpty) return null;

    final admin = users.firstWhere(
      (user) => user['userType']?.toString().trim().toLowerCase() == 'admin',
      orElse: () => <String, dynamic>{},
    );

    if (admin.isEmpty) return null;
    return admin;
  }

  Future<void> _openSupportChat() async {
    if (_openingChat) return;

    Future<bool> openFromConversationsFallback() async {
      try {
        final conversations = await MessageService.getConversations();
        final adminConversation = conversations.firstWhere(
          (c) =>
              c.partnerType.trim().toLowerCase() == 'admin' ||
              c.partnerName.toLowerCase().contains('admin'),
          orElse: () => throw Exception('No admin conversation found'),
        );

        if (!mounted) return false;

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatConversationScreen(
              partnerId: adminConversation.partnerId,
              partnerName: adminConversation.partnerName,
              partnerAvatar: adminConversation.partnerAvatar,
              partnerType: adminConversation.partnerType,
              partnerOnline: adminConversation.partnerOnline,
              isSupportChat: true,
            ),
          ),
        );
        return true;
      } catch (_) {
        return false;
      }
    }

    setState(() => _openingChat = true);
    try {
      final admin = await _findAdminUser();
      if (!mounted) return;

      if (admin == null) {
        final opened = await openFromConversationsFallback();
        if (opened || !mounted) return;
        _showInfo('Support chat is not available right now.');
        return;
      }

      final partnerId = admin['_id']?.toString() ?? '';
      if (partnerId.isEmpty) {
        final opened = await openFromConversationsFallback();
        if (opened || !mounted) return;
        _showInfo('Support chat is not available right now.');
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatConversationScreen(
            partnerId: partnerId,
            partnerName: admin['fullname']?.toString() ?? 'DJTrip Support',
            partnerAvatar: admin['avatar']?.toString(),
            partnerOnline: admin['isOnline'] == true,
            isSupportChat: true,
          ),
        ),
      );
    } catch (_) {
      final opened = await openFromConversationsFallback();
      if (opened || !mounted) return;
      _showInfo('Unable to open support chat right now.');
    } finally {
      if (mounted) {
        setState(() => _openingChat = false);
      }
    }
  }

  Future<void> _callSupport() async {
    final uri = Uri.parse('tel:+21670000000');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    _showInfo('Call support is not available on this device.');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : const Color(0xFFF4F2FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Help Center',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
        children: [
          _HeroCard(onSearchTap: () => _showInfo('Search coming soon.')),
          const SizedBox(height: 16),
          const _SectionTitle('Quick Access'),
          const SizedBox(height: 10),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickChip(icon: Icons.credit_card, label: 'Payment Issues'),
              _QuickChip(icon: Icons.lock, label: 'Account Safety'),
              _QuickChip(icon: Icons.event_note, label: 'My Bookings'),
            ],
          ),
          const SizedBox(height: 16),
          const _FaqCard(),
          const SizedBox(height: 16),
          const _SafetyCard(),
          const SizedBox(height: 16),
          _SupportCard(
            openingChat: _openingChat,
            onChatTap: _openSupportChat,
            onCallTap: _callSupport,
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final VoidCallback onSearchTap;

  const _HeroCard({required this.onSearchTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF2E5BFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E5BFF).withOpacity(0.28),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How can we help you today?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 28 / 1.4,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Search for guides or troubleshooting tips to get your trip back on track.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.92),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: onSearchTap,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: const [
                  Icon(Icons.search, color: Color(0xFF1D4ED8), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Search for 'refund policy'",
                      style: TextStyle(
                        color: Color(0xFF7C86A3),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;

  const _SectionTitle(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        letterSpacing: 1.05,
        fontWeight: FontWeight.w700,
        color: Color(0xFF8A8CB0),
        fontSize: 11,
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _QuickChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFD8D6F8),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF3B3E8A)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF3B3E8A),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqCard extends StatelessWidget {
  const _FaqCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE6E4F7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Getting Started',
            style: TextStyle(
              fontSize: 21 / 1.3,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1B2042),
            ),
          ),
          SizedBox(height: 10),
          _FaqItem(title: 'How do I create my first itinerary?'),
          _FaqItem(title: 'Can I invite friends to collaborate?'),
          _FaqItem(title: 'Syncing DJTrip with my calendar'),
        ],
      ),
    );
  }
}

class _FaqItem extends StatelessWidget {
  final String title;

  const _FaqItem({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF23284A),
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          const Icon(Icons.add, color: Color(0xFF69708F), size: 18),
        ],
      ),
    );
  }
}

class _SafetyCard extends StatelessWidget {
  const _SafetyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F104A),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                'Safety',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 22 / 1.35,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Your security is our top priority. Learn how we keep your data and travels safe.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.87),
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          const _DarkTile(
            title: 'Two-Factor Authentication',
            subtitle: 'Setup instructions',
          ),
          const SizedBox(height: 8),
          const _DarkTile(
            title: 'Secure Payments',
            subtitle: 'Our encryption standards',
          ),
        ],
      ),
    );
  }
}

class _DarkTile extends StatelessWidget {
  final String title;
  final String subtitle;

  const _DarkTile({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 11.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  final bool openingChat;
  final VoidCallback onChatTap;
  final VoidCallback onCallTap;

  const _SupportCard({
    required this.openingChat,
    required this.onChatTap,
    required this.onCallTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Still need assistance?',
            style: TextStyle(
              fontSize: 32 / 1.45,
              fontWeight: FontWeight.w800,
              color: Color(0xFF151845),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Our support agents are ready to jump in and solve any issue quickly.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6C7295), height: 1.35),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: openingChat ? null : onChatTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1645E8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              icon: openingChat
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.chat_bubble),
              label: Text(openingChat ? 'Opening chat...' : 'Chat with us'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onCallTap,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                side: const BorderSide(color: Color(0xFFC8C9E8)),
              ),
              icon: const Icon(Icons.call, color: Color(0xFF2A2E62)),
              label: const Text(
                'Call support',
                style: TextStyle(
                  color: Color(0xFF2A2E62),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
