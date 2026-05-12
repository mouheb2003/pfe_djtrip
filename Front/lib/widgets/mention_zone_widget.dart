import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';

class MentionZoneWidget extends StatefulWidget {
  final List<String> selectedMentions;
  final Function(List<String>) onMentionsChanged;

  const MentionZoneWidget({
    super.key,
    required this.selectedMentions,
    required this.onMentionsChanged,
  });

  @override
  State<MentionZoneWidget> createState() => _MentionZoneWidgetState();
}

class _MentionZoneWidgetState extends State<MentionZoneWidget> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  bool _showResults = false;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    
    // Si la requête est vide, masquer les résultats
    if (query.isEmpty) {
      setState(() {
        _showResults = false;
        _searchResults = [];
      });
      return;
    }

    // Éviter les recherches répétées
    if (query == _lastQuery) return;
    _lastQuery = query;

    // Recherche instantanée lettre par lettre
    _searchUsers(query);
  }

  Future<void> _searchUsers(String query) async {
    if (query.length < 1) return; // Commencer la recherche dès 1 lettre

    setState(() {
      _isLoading = true;
      _showResults = true;
    });

    try {
      final results = await UserService.searchUsersByUsername(query);
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
    }
  }

  void _addMention(Map<String, dynamic> user) {
    final username = user['username'] as String;
    
    if (!widget.selectedMentions.contains(username)) {
      final newMentions = [...widget.selectedMentions, username];
      widget.onMentionsChanged(newMentions);
      
      // Vider le champ de recherche
      _searchController.clear();
      setState(() {
        _showResults = false;
        _searchResults = [];
        _lastQuery = '';
      });
      
      HapticFeedback.lightImpact();
    }
  }

  void _removeMention(String username) {
    final newMentions = widget.selectedMentions.where((m) => m != username).toList();
    widget.onMentionsChanged(newMentions);
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8F9FA),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.alternate_email,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Mention Users',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D245D),
                  ),
                ),
                const Spacer(),
                if (widget.selectedMentions.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${widget.selectedMentions.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Zone de recherche
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Search users by username...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF757575)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _showResults = false;
                            _searchResults = [];
                            _lastQuery = '';
                          });
                        },
                        icon: const Icon(Icons.clear, color: Color(0xFF757575)),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // Résultats de recherche
          if (_showResults)
            Container(
              height: 200,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    )
                  : _searchResults.isEmpty
                      ? Center(
                          child: Text(
                            _searchController.text.length < 2
                                ? 'Type at least 2 characters...'
                                : 'No users found',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final user = _searchResults[index];
                            final isAlreadySelected = widget.selectedMentions.contains(user['username']);
                            
                            return ListTile(
                              leading: CircleAvatar(
                                radius: 20,
                                backgroundImage: user['avatar']?.isNotEmpty == true
                                    ? NetworkImage(user['avatar'])
                                    : null,
                                child: user['avatar']?.isEmpty != false
                                    ? const Icon(Icons.person, size: 20)
                                    : null,
                              ),
                              title: Text(
                                '@${user['username']}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: isAlreadySelected ? Colors.grey : Colors.black87,
                                ),
                              ),
                              subtitle: user['fullname']?.isNotEmpty == true
                                  ? Text(
                                      user['fullname'],
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    )
                                  : null,
                              trailing: isAlreadySelected
                                  ? const Icon(Icons.check_circle, color: Colors.green)
                                  : const Icon(Icons.add_circle_outline, color: AppColors.primary),
                              onTap: isAlreadySelected ? null : () => _addMention(user),
                            );
                          },
                        ),
            ),

          // Mentions sélectionnées
          if (widget.selectedMentions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Selected Mentions:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF757575),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.selectedMentions.map((username) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF2196F3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '@$username',
                              style: const TextStyle(
                                color: Color(0xFF1976D2),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => _removeMention(username),
                              child: const Icon(
                                Icons.close,
                                color: Color(0xFF1976D2),
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
