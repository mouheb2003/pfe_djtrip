import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';

class MentionInputWidget extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onMentionAdded;
  final FocusNode? focusNode;

  const MentionInputWidget({
    super.key,
    required this.controller,
    required this.onMentionAdded,
    this.focusNode,
  });

  @override
  State<MentionInputWidget> createState() => _MentionInputWidgetState();
}

class _MentionInputWidgetState extends State<MentionInputWidget> {
  bool _showSuggestions = false;
  List<Map<String, dynamic>> _suggestions = [];
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    final mentionRegex = RegExp(r'@([a-zA-Z0-9_]{1,})$');
    final match = mentionRegex.firstMatch(text);
    
    if (match != null) {
      final query = match.group(1)!;
      
      if (query != _currentQuery) {
        setState(() {
          _currentQuery = query;
          _showSuggestions = query.isNotEmpty;
        });
        
        if (query.isNotEmpty) {
          _searchUsers(query);
        }
      }
    } else {
      setState(() {
        _showSuggestions = false;
        _currentQuery = '';
      });
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.length < 1) return;

    try {
      final users = await UserService.searchUsersByUsername(query);
      
      setState(() {
        _suggestions = users.map((user) => {
          'username': user['username'],
          'fullname': user['fullname'],
          'avatar': user['avatar'],
        }).toList();
      });
    } catch (e) {
      print('Error searching users: $e');
      setState(() {
        _suggestions = [];
      });
    }
  }

  void _selectSuggestion(Map<String, dynamic> suggestion) {
    final username = suggestion['username'] as String;
    
    // Remplacer la mention dans le texte
    final text = widget.controller.text;
    final mentionRegex = RegExp(r'@([a-zA-Z0-9_]{1,})$');
    final match = mentionRegex.firstMatch(text);
    
    if (match != null) {
      final beforeMention = text.substring(0, match.start);
      final afterMention = text.substring(match.end);
      final newText = '$beforeMention@$username$afterMention';
      
      widget.controller.text = newText;
      widget.controller.selection = TextSelection.fromPosition(
        TextPosition(offset: match.start + username.length + 1),
      );
      
      widget.onMentionAdded(username);
    }
    
    setState(() {
      _showSuggestions = false;
      _currentQuery = '';
    });
    
    widget.focusNode?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // TextField pour écrire la description avec mentions
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          maxLines: 6,
          minLines: 4,
          style: const TextStyle(
            fontSize: 16,
            height: 1.4,
          ),
          decoration: InputDecoration(
            hintText: "Share your Djerba experience...",
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
        
        // Suggestions dropdown
        if (_showSuggestions && _suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.all(8),
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return ListTile(
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundImage: suggestion['avatar'] != null
                        ? NetworkImage(suggestion['avatar'])
                        : null,
                    child: suggestion['avatar'] == null
                        ? const Icon(Icons.person, size: 20)
                        : null,
                  ),
                  title: Text(
                    '@${suggestion['username']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    suggestion['fullname'],
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  onTap: () => _selectSuggestion(suggestion),
                );
              },
            ),
          ),
      ],
    );
  }
}
