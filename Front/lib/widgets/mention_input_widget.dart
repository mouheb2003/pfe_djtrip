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
    final mentionRegex = RegExp(r'@([a-zA-Z0-9]{1,})$');
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
      final users = await UserService.searchUsersByName(query);
      
      setState(() {
        _suggestions = users.map((user) => {
          '_id': user['_id'],
          'fullname': user['fullname'],
          'avatar': user['avatar'],
          'userType': user['userType'],
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
    final userId = suggestion['_id'] as String;
    final fullname = suggestion['fullname'] as String;
    
    // Remplacer la mention dans le texte
    final text = widget.controller.text;
    final mentionRegex = RegExp(r'@([a-zA-Z0-9]{1,})$');
    final match = mentionRegex.firstMatch(text);
    
    if (match != null) {
      final beforeMention = text.substring(0, match.start);
      final afterMention = text.substring(match.end);
      
      // On utilise @userId en interne pour la détection backend robuste.
      final newText = '$beforeMention@$userId$afterMention';
      
      widget.controller.text = newText;
      widget.controller.selection = TextSelection.fromPosition(
        TextPosition(offset: match.start + userId.length + 1),
      );
      
      widget.onMentionAdded(userId);
    }
    
    setState(() {
      _showSuggestions = false;
      _currentQuery = '';
    });
    
    widget.focusNode?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      children: [
        // TextField pour écrire la description avec mentions
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          maxLines: 8,
          minLines: 5,
          style: TextStyle(
            fontSize: 15,
            height: 1.5,
            color: isDark ? Colors.white : const Color(0xFF1D245D),
          ),
          decoration: InputDecoration(
            hintText: "What's on your mind? Mention friends using @...",
            hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400], fontSize: 15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: isDark ? const Color(0xFF2E2E2E) : Colors.grey[200]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: isDark ? const Color(0xFF2E2E2E) : Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF121212) : Colors.white,
            contentPadding: const EdgeInsets.all(20),
          ),
        ),
        
        // Suggestions dropdown
        if (_showSuggestions && _suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE8EAF6)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? const Color(0xFF2E2E2E) : Colors.grey[100], indent: 64),
                itemBuilder: (context, index) {
                  final suggestion = _suggestions[index];
                  final fullname = suggestion['fullname'] ?? 'User';
                  final type = suggestion['userType'] ?? 'Touriste';
                  
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary.withOpacity(0.1), width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: isDark ? const Color(0xFF2A2D3E) : const Color(0xFFF0F2FF),
                        backgroundImage: suggestion['avatar'] != null
                            ? NetworkImage(suggestion['avatar'])
                            : null,
                        child: suggestion['avatar'] == null
                            ? const Icon(Icons.person, size: 20, color: AppColors.primary)
                            : null,
                      ),
                    ),
                    title: Text(
                      fullname,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isDark ? Colors.white : const Color(0xFF1D245D),
                      ),
                    ),
                    subtitle: Text(
                      type.toString().toUpperCase(),
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[500],
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    onTap: () => _selectSuggestion(suggestion),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
