import 'dart:convert';

import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../services/theme_service.dart';
import '../../services/message_service.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';
import 'chat_conversation_screen.dart';
import 'help_center_screen.dart';
import '../settings/privacy_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = ThemeService.isDark;

  void _showInfo(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.primary),
    );
  }

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

  Future<void> _openContactUsChat() async {
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

    try {
      final response = await ApiClient.get('/users/all', auth: false);
      if (response.statusCode != 200) {
        final opened = await openFromConversationsFallback();
        if (opened || !mounted) return;
        throw Exception('Unable to load support contact');
      }

      final decoded = jsonDecode(response.body);
      final users = _extractUsers(decoded);
      final admin = users.firstWhere(
        (user) => user['userType']?.toString().trim().toLowerCase() == 'admin',
        orElse: () => <String, dynamic>{},
      );

      if (!mounted) return;

      if (admin.isEmpty) {
        final opened = await openFromConversationsFallback();
        if (opened || !mounted) return;
        _showInfo('Support chat is not available right now.');
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatConversationScreen(
            partnerId: admin['_id']?.toString() ?? '',
            partnerName: admin['fullname']?.toString() ?? 'Admin',
            partnerAvatar: admin['avatar']?.toString(),
            partnerOnline: admin['isOnline'] == true,
            isSupportChat: true,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      final opened = await openFromConversationsFallback();
      if (opened || !mounted) return;
      _showInfo('Unable to open support chat right now.');
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        title: const Text(
          'Log Out?',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: const Text(
          "Are you sure you want to log out? You'll need to sign back in to access your Account.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color.fromARGB(255, 202, 18, 5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Log Out',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await AuthService.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── ACCOUNT ──────────────────────────────────────────
            _SectionHeader(label: 'ACCOUNT'),
            _SettingsTile(
              icon: Icons.person,
              label: 'Edit Profile',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              ),
            ),
            _SettingsTile(
              icon: Icons.lock,
              label: 'Change Password',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
              ),
            ),
            _SettingsTile(
              icon: Icons.security,
              label: 'Privacy Settings',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PrivacySettingsScreen(),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ── PREFERENCES ─────────────────────────────────────
            _SectionHeader(label: 'PREFERENCES'),
            _SettingsTile(
              icon: Icons.language,
              label: 'Language',
              trailing: Text(
                'English',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
              onTap: () => _showInfo('Language selector coming soon.'),
            ),
            _SettingsTileSwitch(
              icon: Icons.notifications,
              label: 'Notifications',
              value: _notificationsEnabled,
              onChanged: (val) => setState(() => _notificationsEnabled = val),
            ),
            _SettingsTileSwitch(
              icon: Icons.dark_mode,
              label: 'Dark Mode',
              value: _darkModeEnabled,
              onChanged: (val) async {
                setState(() => _darkModeEnabled = val);
                await ThemeService.setDarkMode(val);
              },
            ),
            const SizedBox(height: 8),

            // ── SUPPORT & LEGAL ──────────────────────────────────
            _SectionHeader(label: 'SUPPORT & LEGAL'),
            _SettingsTile(
              icon: Icons.help,
              label: 'Help Center',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HelpCenterScreen()),
              ),
            ),
            _SettingsTile(
              icon: Icons.description,
              label: 'Terms of Use',
              onTap: () => _showInfo('Terms of use coming soon.'),
            ),
            _SettingsTile(
              icon: Icons.privacy_tip,
              label: 'Privacy Policy',
              onTap: () => _showInfo('Privacy policy coming soon.'),
            ),
            _SettingsTile(
              icon: Icons.support_agent,
              label: 'Contact Us',
              onTap: _openContactUsChat,
              showDivider: false,
            ),
            const SizedBox(height: 32),

            // ── VERSION ─────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.travel_explore,
                      color: AppColors.primary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'DJTrip Version 2.4.1 (Build 108)',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── LOGOUT BUTTON ────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(
                  Icons.logout_rounded,
                  color: Color.fromARGB(255, 202, 18, 5),
                  size: 22,
                ),
                label: const Text(
                  'Logout',
                  style: TextStyle(
                    color: Color.fromARGB(255, 202, 18, 5),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.06),
                  side: BorderSide(
                    color: Colors.red.withOpacity(0.35),
                    width: 1,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 8, bottom: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: Colors.grey[500],
        ),
      ),
    );
  }
}

// ── Settings tile (arrow) ─────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool showDivider;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 2,
          ),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          title: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : AppColors.textDark,
            ),
          ),
          trailing:
              trailing ??
              Icon(Icons.chevron_right, color: Colors.grey[400], size: 22),
          onTap: onTap,
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 52,
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : AppColors.borderLight,
          ),
      ],
    );
  }
}

// ── Settings tile (switch) ────────────────────────────────────────────────────

class _SettingsTileSwitch extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsTileSwitch({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 2,
          ),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          title: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : AppColors.textDark,
            ),
          ),
          trailing: Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ),
        Divider(
          height: 1,
          indent: 52,
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : AppColors.borderLight,
        ),
      ],
    );
  }
}
