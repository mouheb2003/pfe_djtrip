import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';

class MentionZoneWidget extends StatefulWidget {
  final List<String> selectedMentions;
  final Map<String, String>? initialFullnames; // Map of userId -> fullname
  final Function(List<String> newMentions) onMentionsChanged;
  final Function(Map<String, String> updatedFullnames)? onFullnamesUpdated;

  const MentionZoneWidget({
    super.key,
    required this.selectedMentions,
    this.initialFullnames,
    required this.onMentionsChanged,
    this.onFullnamesUpdated,
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
  final Map<String, String> _fullnameCache = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialFullnames != null) {
      _fullnameCache.addAll(widget.initialFullnames!);
    }
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
    
    if (query.isEmpty) {
      setState(() {
        _showResults = false;
        _searchResults = [];
      });
      return;
    }

    if (query == _lastQuery) return;
    _lastQuery = query;

    _searchUsers(query);
  }

  Future<void> _searchUsers(String query) async {
    if (query.length < 1) return;

    setState(() {
      _isLoading = true;
      _showResults = true;
    });

    try {
      final results = await UserService.searchUsersByName(query);
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
    final userId = user['_id'] as String;
    final fullname = user['fullname'] as String;
    
    if (!widget.selectedMentions.contains(userId)) {
      final newList = List<String>.from(widget.selectedMentions)..add(userId);
      _fullnameCache[userId] = fullname;
      widget.onMentionsChanged(newList);
      if (widget.onFullnamesUpdated != null) {
        widget.onFullnamesUpdated!(_fullnameCache);
      }
    }
    
    setState(() {
      _showResults = false;
      _searchController.clear();
      _lastQuery = '';
    });
    
    HapticFeedback.lightImpact();
  }

  void _removeMention(String userId) {
    final newMentions = widget.selectedMentions.where((m) => m != userId).toList();
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
                const Icon(
                  Icons.person_add_alt_1_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Mention Friends',
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

          // Search Zone
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Search people to mention...',
                prefixIcon: const Icon(Icons.person_search, color: AppColors.primary),
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
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                filled: true,
                fillColor: const Color(0xFFF8F9FE),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),

          // Search Results
          if (_showResults)
            Container(
              height: 240,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE8EAF6)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2.5,
                      ),
                    )
                  : _searchResults.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off, color: Colors.grey[300], size: 40),
                              const SizedBox(height: 8),
                              Text(
                                'No users found',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _searchResults.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            indent: 70,
                            color: Colors.grey[100],
                          ),
                          itemBuilder: (context, index) {
                            final user = _searchResults[index];
                            final userId = user['_id'] as String;
                            final fullname = user['fullname'] as String;
                            final userType = user['userType'] ?? 'Touriste';
                            final isAlreadySelected = widget.selectedMentions.contains(userId);
                            
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isAlreadySelected ? Colors.grey[200]! : AppColors.primary.withOpacity(0.1),
                                    width: 2,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 22,
                                  backgroundColor: const Color(0xFFF0F2FF),
                                  backgroundImage: user['avatar']?.isNotEmpty == true
                                      ? NetworkImage(user['avatar'])
                                      : null,
                                  child: user['avatar']?.isEmpty != false
                                      ? const Icon(Icons.person, color: AppColors.primary, size: 20)
                                      : null,
                                ),
                              ),
                              title: Text(
                                fullname,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: isAlreadySelected ? Colors.grey[400] : const Color(0xFF1D245D),
                                ),
                              ),
                              subtitle: Row(
                                children: [
                                  Icon(
                                    userType == 'Organisateur' ? Icons.business_center : Icons.explore,
                                    size: 12,
                                    color: Colors.grey[500],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    userType.toString().toUpperCase(),
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: isAlreadySelected
                                  ? const Icon(Icons.check_circle, color: Colors.green, size: 24)
                                  : Icon(Icons.add_circle_outline, color: AppColors.primary.withOpacity(0.7), size: 24),
                              onTap: isAlreadySelected ? null : () => _addMention(user),
                            );
                          },
                        ),
            ),

          // Selected Mentions
          if (widget.selectedMentions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SELECTED PEOPLE:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF9E9E9E),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: widget.selectedMentions.map((userId) {
                      final displayName = _fullnameCache[userId] ?? 'User';
                      return Container(
                        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _removeMention(userId),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: AppColors.primary,
                                  size: 14,
                                ),
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

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
