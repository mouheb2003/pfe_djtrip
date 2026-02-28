import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import 'auth/new_login_screen.dart';
import 'edit_profile_screen.dart';

class OrganisatorProfileScreen extends StatelessWidget {
  final User user;

  const OrganisatorProfileScreen({super.key, required this.user});

  void _shareProfile(BuildContext context) async {
    final profileText =
        '''
🏢 ${user.nomEntreprise ?? 'Activity Organizer'}

👤 ${user.fullname}
📧 ${user.email}
${user.numeroLicence != null ? '🎫 License: ${user.numeroLicence}\n' : ''}
${user.adresseEntreprise != null ? '📍 ${user.adresseEntreprise}\n' : ''}
${user.siteWeb != null ? '🌐 ${user.siteWeb}\n' : ''}

🎯 ${user.nombreActivites ?? 0} activities created
⭐ ${user.noteMoyenne?.toStringAsFixed(1) ?? '0.0'} / 5.0 (${user.nombreAvis ?? 0} reviews)

✈️ Activity Organizer on Travelo
''';

    try {
      await Clipboard.setData(ClipboardData(text: profileText));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Profile copied to clipboard!'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sharing error'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Logout'),
        content: Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await AuthService.logout();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => NewLoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // AppBar with company branding
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: Color(0xFF1976D2),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: 20),
                      // Company Logo/Avatar
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 15,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: user.avatar != null
                            ? ClipOval(
                                child: Image.network(
                                  user.avatar!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.business,
                                      size: 50,
                                      color: Color(0xFF1976D2),
                                    );
                                  },
                                ),
                              )
                            : Icon(
                                Icons.business,
                                size: 50,
                                color: Color(0xFF1976D2),
                              ),
                      ),
                      SizedBox(height: 12),
                      // Company name
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          user.nomEntreprise ?? 'Company',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(height: 4),
                      // Rating
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, color: Colors.amber, size: 16),
                            SizedBox(width: 4),
                            Text(
                              '${user.noteMoyenne?.toStringAsFixed(1) ?? '0.0'}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              ' (${user.nombreAvis ?? 0} reviews)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 4),
                      // Activities count
                      Text(
                        '${user.nombreActivites ?? 0} activities created',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: _buildCompactButton(
                          icon: Icons.edit,
                          label: 'Edit',
                          color: Color(0xFF1976D2),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    EditProfileScreen(user: user),
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildCompactButton(
                          icon: Icons.share_rounded,
                          label: 'Share',
                          color: Colors.green,
                          onTap: () {
                            _shareProfile(context);
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),

                  // Company information section
                  _buildSectionTitle('Company Information'),
                  _buildInfoCard(
                    icon: Icons.person_outline,
                    title: 'Contact person',
                    value: user.fullname,
                  ),
                  SizedBox(height: 12),
                  _buildInfoCard(
                    icon: Icons.email_outlined,
                    title: 'Email',
                    value: user.email,
                  ),
                  if (user.numTel != null) ...[
                    SizedBox(height: 12),
                    _buildInfoCard(
                      icon: Icons.phone_outlined,
                      title: 'Phone',
                      value: user.numTel!,
                    ),
                  ],
                  if (user.numeroLicence != null) ...[
                    SizedBox(height: 12),
                    _buildInfoCard(
                      icon: Icons.badge_outlined,
                      title: 'License number',
                      value: user.numeroLicence!,
                    ),
                  ],
                  if (user.adresseEntreprise != null) ...[
                    SizedBox(height: 12),
                    _buildInfoCard(
                      icon: Icons.location_on_outlined,
                      title: 'Address',
                      value: user.adresseEntreprise!,
                    ),
                  ],
                  if (user.siteWeb != null) ...[
                    SizedBox(height: 12),
                    _buildInfoCard(
                      icon: Icons.language,
                      title: 'Website',
                      value: user.siteWeb!,
                    ),
                  ],
                  if (user.paysOrigine != null) ...[
                    SizedBox(height: 12),
                    _buildInfoCard(
                      icon: Icons.public_outlined,
                      title: 'Country',
                      value: user.paysOrigine!,
                    ),
                  ],

                  SizedBox(height: 24),

                  // About section
                  if (user.description != null || user.bio != null) ...[
                    _buildSectionTitle('About'),
                    _buildInfoCard(
                      icon: Icons.info_outline,
                      title: 'Description',
                      value: user.description ?? user.bio ?? 'No description',
                    ),
                    SizedBox(height: 24),
                  ],

                  // Activities section
                  _buildSectionTitle('Activities & Services'),
                  if (user.typesActivites != null &&
                      user.typesActivites!.isNotEmpty)
                    _buildActivitiesCard(user.typesActivites!),
                  if (user.typesActivites == null ||
                      user.typesActivites!.isEmpty)
                    _buildInfoCard(
                      icon: Icons.local_activity_outlined,
                      title: 'Activity types',
                      value: 'No activities specified',
                    ),

                  if (user.languesProposees != null &&
                      user.languesProposees!.isNotEmpty) ...[
                    SizedBox(height: 12),
                    _buildInfoCard(
                      icon: Icons.translate,
                      title: 'Languages offered',
                      value: user.languesProposees!.join(', '),
                    ),
                  ],

                  if (user.capaciteMoyenne != null) ...[
                    SizedBox(height: 12),
                    _buildInfoCard(
                      icon: Icons.people_outline,
                      title: 'Average capacity',
                      value:
                          '${user.capaciteMoyenne} participants per activity',
                    ),
                  ],

                  SizedBox(height: 24),

                  // Certifications section
                  if (user.certifications != null &&
                      user.certifications!.isNotEmpty) ...[
                    _buildSectionTitle('Certifications & Awards'),
                    _buildCertificationsCard(user.certifications!),
                    SizedBox(height: 24),
                  ],

                  // Settings section
                  _buildSectionTitle('Settings'),
                  _buildSettingsCard(
                    icon: Icons.notifications_outlined,
                    title: 'Notifications',
                    subtitle:
                        'Email: ${user.notificationsEmail ? "Enabled" : "Disabled"}',
                    onTap: () {
                      // TODO: Navigate to notifications settings
                    },
                  ),
                  SizedBox(height: 12),
                  _buildSettingsCard(
                    icon: Icons.lock_outline,
                    title: 'Privacy',
                    subtitle: 'Manage your data',
                    onTap: () {
                      // TODO: Navigate to privacy settings
                    },
                  ),
                  SizedBox(height: 12),
                  _buildSettingsCard(
                    icon: Icons.help_outline,
                    title: 'Help & Support',
                    subtitle: 'FAQ and contact',
                    onTap: () {
                      // TODO: Navigate to help
                    },
                  ),
                  SizedBox(height: 24),

                  // Logout button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () => _handleLogout(context),
                      icon: Icon(Icons.logout, color: Colors.red),
                      label: Text(
                        'Logout',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.red.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Color(0xFF1976D2), size: 22),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.grey[700], size: 24),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivitiesCard(List<String> activities) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(0xFF1976D2).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.sports, color: Color(0xFF1976D2), size: 22),
                ),
                SizedBox(width: 12),
                Text(
                  'Activity types',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: activities.map((activity) {
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Color(0xFF1976D2).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Color(0xFF1976D2).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    activity,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFF1976D2),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCertificationsCard(List<String> certifications) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.verified, color: Colors.green, size: 22),
                ),
                SizedBox(width: 12),
                Text(
                  'Certifications',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
            SizedBox(height: 12),
            ...certifications.map((cert) {
              return Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        cert,
                        style: TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
