import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/auth_service.dart';
import '../../../services/api_service.dart';

class MentionAutocomplete extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Function(String username) onMentionSelected;
  final VoidCallback? onDismiss;

  const MentionAutocomplete({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onMentionSelected,
    this.onDismiss,
  });

  @override
  State<MentionAutocomplete> createState() => _MentionAutocompleteState();
}

class _MentionAutocompleteState extends State<MentionAutocomplete> {
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  List<Map<String, dynamic>> _suggestions = [];
  bool _isLoading = false;
  String _currentQuery = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    _debounce?.cancel();
    _removeOverlay();
    super.dispose();
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    final cursorPosition = widget.controller.selection.baseOffset;
    
    if (cursorPosition < 0) return;

    // Find @ symbol before cursor
    int atPosition = -1;
    for (int i = cursorPosition - 1; i >= 0; i--) {
      if (text[i] == '@') {
        atPosition = i;
        break;
      }
      if (text[i] == ' ') {
        break;
      }
    }

    if (atPosition != -1) {
      final query = text.substring(atPosition + 1, cursorPosition);
      if (query != _currentQuery) {
        _currentQuery = query;
        _searchUsers(query);
      }
    } else {
      _removeOverlay();
    }
  }

  void _onFocusChanged() {
    if (!widget.focusNode.hasFocus) {
      _removeOverlay();
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.length < 2) {
      _removeOverlay();
      return;
    }

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _isLoading = true);
      
      try {
        final response = await ApiService.instance.get(
          '/comments/users/search',
          query: {'query': query, 'limit': '5'},
        );
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['users'] != null) {
            setState(() {
              _suggestions = List<Map<String, dynamic>>.from(data['users']);
            });
            
            if (_suggestions.isNotEmpty) {
              _showOverlay();
            } else {
              _removeOverlay();
            }
          } else {
            _removeOverlay();
          }
        } else {
          _removeOverlay();
        }
      } catch (e) {
        _removeOverlay();
      } finally {
        setState(() => _isLoading = false);
      }
    });
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 300,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 50),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _suggestions.length,
                      itemBuilder: (context, index) {
                        final user = _suggestions[index];
                        return _buildUserTile(user);
                      },
                    ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    final username = user['username'] ?? '';
    final fullname = user['fullname'] ?? '';
    final avatar = user['avatar'];

    return InkWell(
      onTap: () {
        _insertMention(username);
        widget.onMentionSelected(username);
        HapticFeedback.lightImpact();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: avatar != null && avatar.isNotEmpty
                  ? NetworkImage(avatar)
                  : null,
              child: avatar == null || avatar.isEmpty
                  ? Text(
                      fullname[0].toUpperCase(),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fullname,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '@$username',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
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

  void _insertMention(String username) {
    final text = widget.controller.text;
    final cursorPosition = widget.controller.selection.baseOffset;
    
    // Find @ symbol position
    int atPosition = -1;
    for (int i = cursorPosition - 1; i >= 0; i--) {
      if (text[i] == '@') {
        atPosition = i;
        break;
      }
      if (text[i] == ' ') {
        break;
      }
    }

    if (atPosition != -1) {
      final beforeAt = text.substring(0, atPosition);
      final afterCursor = text.substring(cursorPosition);
      
      widget.controller.value = TextEditingValue(
        text: '$beforeAt@$username $afterCursor',
        selection: TextSelection.collapsed(offset: beforeAt.length + username.length + 2),
      );
    }

    _removeOverlay();
    widget.focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: const SizedBox.shrink(),
    );
  }
}
