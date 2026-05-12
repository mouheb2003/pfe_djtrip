import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../theme/app_theme.dart';
import '../screens/shared/public_profile_screen.dart';
import '../services/user_service.dart';

class FacebookMentionsInlineWidget extends StatefulWidget {
  final List<String> mentions;

  const FacebookMentionsInlineWidget({
    super.key,
    required this.mentions,
  });

  @override
  State<FacebookMentionsInlineWidget> createState() => _FacebookMentionsInlineWidgetState();
}

class _FacebookMentionsInlineWidgetState extends State<FacebookMentionsInlineWidget> {
  Map<String, String> _userFullnames = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserFullnames();
  }

  Future<void> _loadUserFullnames() async {
    if (widget.mentions.isEmpty) return;
    
    setState(() => _isLoading = true);
    
    try {
      final Map<String, String> fullnames = {};
      
      for (final username in widget.mentions) {
        try {
          final user = await UserService.getUserByUsername(username);
          if (user != null && user['fullname'] != null) {
            fullnames[username] = user['fullname'];
          } else {
            fullnames[username] = username; // Fallback to username
          }
        } catch (e) {
          fullnames[username] = username; // Fallback on error
        }
      }
      
      setState(() {
        _userFullnames = fullnames;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mentions.isEmpty || _isLoading) {
      return const SizedBox.shrink();
    }

    return _buildInlineMentions();
  }

  Widget _buildInlineMentions() {
    final mentions = widget.mentions;
    
    if (mentions.isEmpty) return const SizedBox.shrink();

    // Format: "with X and Y others" - adaptable avec Wrap
    if (mentions.length == 1) {
      final username = mentions.first;
      final displayName = _userFullnames[username] ?? username;
      return _buildMentionTextWrap('with $displayName', [username]);
    }

    if (mentions.length == 2) {
      final first = _userFullnames[mentions.first] ?? mentions.first;
      final second = _userFullnames[mentions.last] ?? mentions.last;
      return _buildMentionTextWrap('with $first and $second', mentions);
    }

    // More than 2 mentions - Wrap pour adaptabilité
    final first = _userFullnames[mentions.first] ?? mentions.first;
    final second = _userFullnames[mentions[1]] ?? mentions[1];
    final remainingCount = mentions.length - 2;
    
    return Wrap(
      spacing: 2,
      runSpacing: 2,
      children: [
        Text(
          'with ',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF616161),
            fontWeight: FontWeight.w800,
          ),
        ),
        GestureDetector(
          onTap: () => _navigateToProfile(mentions.first),
          child: Text(
            first,
            style: const TextStyle(
              color: Color(0xFF1976D2),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
        Text(
          ' and ',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF616161),
            fontWeight: FontWeight.w800,
          ),
        ),
        GestureDetector(
          onTap: () => _navigateToProfile(mentions[1]),
          child: Text(
            second,
            style: const TextStyle(
              color: Color(0xFF1976D2),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
        GestureDetector(
          onTap: () => _showAllMentionsDialog(),
          child: Text(
            ' and $remainingCount others',
            style: const TextStyle(
              color: Color(0xFF1976D2),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMentionTextWrap(String text, List<String> usernames) {
    return Wrap(
      spacing: 2,
      runSpacing: 2,
      children: [
        Text(
          'with ',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF616161),
            fontWeight: FontWeight.w800,
          ),
        ),
        GestureDetector(
          onTap: () {
            if (usernames.isNotEmpty) {
              _navigateToProfile(usernames.first);
            }
          },
          child: Text(
            text.replaceFirst('with ', ''),
            style: const TextStyle(
              color: Color(0xFF1976D2),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  void _navigateToProfile(String username) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PublicProfileScreen(userId: username),
      ),
    );
  }

  void _showAllMentionsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mentions'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: widget.mentions.map((username) {
              final displayName = _userFullnames[username] ?? username;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToProfile(username);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person, size: 20, color: Color(0xFF1976D2)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1976D2),
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right, size: 16, color: Color(0xFF1976D2)),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
