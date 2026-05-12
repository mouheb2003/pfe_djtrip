import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../theme/app_theme.dart';
import '../services/user_service.dart';

class MentionTextWidget extends StatefulWidget {
  final String text;
  final Function(String)? onMentionTap;

  const MentionTextWidget({
    super.key,
    required this.text,
    this.onMentionTap,
  });

  @override
  State<MentionTextWidget> createState() => _MentionTextWidgetState();
}

class _MentionTextWidgetState extends State<MentionTextWidget> {
  Map<String, String> _userFullnames = {};

  @override
  void initState() {
    super.initState();
    _loadUserFullnames();
  }

  Future<void> _loadUserFullnames() async {
    final mentionRegex = RegExp(r'@([a-zA-Z0-9_]{3,30})');
    final mentions = mentionRegex.allMatches(widget.text).map((m) => m.group(1)!).toSet();
    
    if (mentions.isEmpty) return;
    
    try {
      final Map<String, String> fullnames = {};
      
      for (final username in mentions) {
        try {
          final user = await UserService.getUserByUsername(username);
          if (user != null && user['fullname'] != null) {
            fullnames[username] = user['fullname'];
          } else {
            fullnames[username] = username;
          }
        } catch (e) {
          fullnames[username] = username;
        }
      }
      
      if (mounted) {
        setState(() {
          _userFullnames = fullnames;
        });
      }
    } catch (e) {
      // Ignore errors
    }
  }

  @override
  Widget build(BuildContext context) {
    // Regex pour trouver les mentions @username
    final mentionRegex = RegExp(r'@([a-zA-Z0-9_]{3,30})');
    final spans = <TextSpan>[];
    int lastEnd = 0;

    // Parcourir le texte et créer des spans pour les mentions
    for (final match in mentionRegex.allMatches(widget.text)) {
      // Texte avant la mention
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: widget.text.substring(lastEnd, match.start),
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF3B4371),
            height: 1.25,
          ),
        ));
      }

      // Texte de la mention (cliquable)
      final username = match.group(1)!;
      final displayName = _userFullnames[username] ?? username;
      spans.add(TextSpan(
        text: '@$displayName', 
        style: const TextStyle(
          fontSize: 16,
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
          height: 1.25,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            if (widget.onMentionTap != null) {
              widget.onMentionTap!(username);
            }
          },
      ));
      lastEnd = match.end;
    }

    // Ajouter le texte restant après la dernière mention
    if (lastEnd < widget.text.length) {
      spans.add(TextSpan(
        text: widget.text.substring(lastEnd),
        style: const TextStyle(
          fontSize: 16,
          color: Color(0xFF3B4371),
          height: 1.25,
        ),
      ));
    }

    return RichText(
      text: TextSpan(
        children: spans,
        style: const TextStyle(
          fontSize: 16,
          color: Color(0xFF3B4371),
          height: 1.25,
        ),
      ),
    );
  }
}

// Widget pour afficher les mentions dans les cards de posts
class PostMentionsWidget extends StatelessWidget {
  final List<String> mentions;
  final double? fontSize;

  const PostMentionsWidget({
    super.key,
    required this.mentions,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    if (mentions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: mentions.map((username) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Text(
            '@$username',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        );
      }).toList(),
    );
  }
}
