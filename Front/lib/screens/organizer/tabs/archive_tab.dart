import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/activity_model.dart';
import '../../../models/inscription_model.dart';
import '../../../models/conversation_model.dart';
import '../../shared/activity_detail_screen.dart';
import '../../shared/chat_conversation_screen.dart';
import '../../shared/public_tourist_profile_screen.dart';
import '../../../services/activity_service.dart';
import '../../../services/inscription_service.dart';
import '../../../services/message_service.dart';
import '../../../widgets/auto_image_carousel.dart';

class ArchiveTab extends StatefulWidget {
  const ArchiveTab({super.key});

  @override
  State<ArchiveTab> createState() => _ArchiveTabState();
}

class _ArchiveTabState extends State<ArchiveTab> {
  final TextEditingController _searchController = TextEditingController();
  List<_ArchivedActivityBundle> _activities = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreActivities = true;
  String _query = '';
  int _currentOffset = 0;
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _fetchArchives();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchArchives({bool isLoadMore = false}) async {
    if (mounted) {
      if (isLoadMore) {
        setState(() => _isLoadingMore = true);
      } else {
        setState(() => _isLoading = true);
        _currentOffset = 0;
        _hasMoreActivities = true;
      }
    }

    try {
      final activities = await ActivityService.getArchivedActivities(
        offset: isLoadMore ? _currentOffset : null,
        limit: _pageSize,
      );
      final participantLists = await Future.wait(
        activities.map(
          (activity) => InscriptionService.getOrganizerInscriptions(
            statut: 'approuvee',
            activiteId: activity.id,
          ),
        ),
      );

      if (!mounted) return;
      setState(() {
        if (isLoadMore) {
          _activities.addAll([
            for (var i = 0; i < activities.length; i++)
              _ArchivedActivityBundle(
                activity: activities[i],
                participants: participantLists[i],
              ),
          ]);
          _currentOffset += activities.length;
        } else {
          _activities = [
            for (var i = 0; i < activities.length; i++)
              _ArchivedActivityBundle(
                activity: activities[i],
                participants: participantLists[i],
              ),
          ];
          _currentOffset = activities.length;
        }
        
        _hasMoreActivities = activities.length == _pageSize;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  List<_ArchivedActivityBundle> get _filteredActivities {
    final q = _query.trim().toLowerCase();
    final list = q.isEmpty
        ? List<_ArchivedActivityBundle>.from(_activities)
        : _activities.where((bundle) {
            final activity = bundle.activity;
            return activity.titre.toLowerCase().contains(q) ||
                activity.description.toLowerCase().contains(q) ||
                activity.typeActivite.toLowerCase().contains(q) ||
                activity.lieu.toLowerCase().contains(q);
          }).toList();

    list.sort((a, b) {
      final dateA =
          a.activity.dateDebut ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateB =
          b.activity.dateDebut ?? DateTime.fromMillisecondsSinceEpoch(0);
      return dateB.compareTo(dateA);
    });

    if (q.isEmpty) {
      return list;
    }

    list.sort((a, b) {
      final scoreA = _searchScore(a.activity, q);
      final scoreB = _searchScore(b.activity, q);
      if (scoreA != scoreB) return scoreA.compareTo(scoreB);
      final dateA =
          a.activity.dateDebut ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateB =
          b.activity.dateDebut ?? DateTime.fromMillisecondsSinceEpoch(0);
      return dateB.compareTo(dateA);
    });
    return list;
  }

  int _searchScore(ActivityModel activity, String query) {
    final title = activity.titre.toLowerCase();
    final description = activity.description.toLowerCase();
    final type = activity.typeActivite.toLowerCase();
    final location = activity.lieu.toLowerCase();

    if (title.contains(query)) return 0;
    if (description.contains(query)) return 1;
    if (type.contains(query) || location.contains(query)) return 2;
    return 3;
  }

  double get _totalRevenue {
    return _activities.fold<double>(
      0,
      (sum, bundle) =>
          sum + (bundle.activity.prix * bundle.activity.nombreReservations),
    );
  }

  int get _totalParticipants {
    return _activities.fold<int>(
      0,
      (sum, bundle) => sum + bundle.activity.nombreReservations,
    );
  }

  List<String> get _heroImages {
    return _activities
        .expand(
          (bundle) => bundle.participants.map(
            (inscription) => inscription.touriste?['avatar']?.toString() ?? '',
          ),
        )
        .where((url) => url.isNotEmpty)
        .take(3)
        .toList();
  }

  List<InscriptionModel> get _allParticipants {
    return _activities.expand((bundle) => bundle.participants).toList();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('dd MMM yyyy').format(date);
  }

  String _formatMoney(double value) {
    return '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2)} TND';
  }

  String _statusLabel(ActivityModel activity) {
    final status = activity.statut.toLowerCase();
    if (status.contains('arch')) return 'ARCHIVED';
    return 'COMPLETED';
  }

  String _compactCount(int value) {
    if (value >= 1000) {
      final compact = (value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1);
      return '${compact}k';
    }
    return value.toString();
  }

  Future<void> _deleteActivity(ActivityModel activity) async {
    final reasonController = TextEditingController();
    String? inlineError;

    final reason = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Delete Activity?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Deleting "${activity.titre}" will cancel all related bookings. Please provide a cancellation reason for tourists.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  maxLines: 4,
                  minLines: 3,
                  maxLength: 280,
                  decoration: InputDecoration(
                    hintText:
                        'Example: Activity removed due to weather conditions.',
                    errorText: inlineError,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: () {
                  final reason = reasonController.text.trim();
                  if (reason.isEmpty) {
                    setDialogState(() {
                      inlineError = 'Reason is required';
                    });
                    return;
                  }
                  Navigator.pop(ctx, reason);
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (reason == null || reason.trim().isEmpty) return;

    setState(() => _isLoading = true);
    final success = await ActivityService.deleteActivity(
      activity.id,
      cancellationMessage: reason.trim(),
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Activity deleted successfully.')),
        );
        _fetchArchives();
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete activity.')),
        );
      }
    }
  }

  Future<void> _showParticipantsSheet(
    List<InscriptionModel> participants,
  ) async {
    final totalPeople = participants.fold<int>(
      0,
      (sum, inscription) => sum + inscription.nombreParticipants,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.78,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Participants',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$totalPeople approved participants',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: participants.isEmpty
                        ? Center(
                            child: Text(
                              'No approved participants yet',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.only(bottom: 8),
                            itemCount: participants.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, index) {
                              final inscription = participants[index];
                              final tourist = inscription.touriste ?? const {};
                              final name =
                                  (tourist['fullname'] ?? 'Participant')
                                      .toString();
                              final avatar =
                                  tourist['avatar']?.toString() ?? '';
                              final phone =
                                  tourist['num_tel']?.toString() ?? '';

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8F9FF),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFE7E9F7),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 22,
                                          backgroundColor: const Color(0xFFE8E5FF),
                                          backgroundImage: avatar.isNotEmpty
                                              ? NetworkImage(avatar)
                                              : null,
                                          child: avatar.isEmpty
                                              ? const Icon(
                                                  Icons.person,
                                                  color: Color(0xFF4B63FF),
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              if (phone.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  phone,
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE8E5FF),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            '${inscription.nombreParticipants} pax',
                                            style: const TextStyle(
                                              color: Color(0xFF4B63FF),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () async {
                                              final touristId = tourist['_id']?.toString() ?? tourist['id']?.toString() ?? '';
                                              if (touristId.isEmpty) return;
                                              
                                              // Check if conversation already exists
                                              final conversations = await MessageService.getConversations();
                                              final existingConversation = conversations.firstWhere(
                                                (conv) => conv.partnerId == touristId,
                                                orElse: () => ConversationModel(
                                                  partnerId: '',        
                                                  partnerName: '', 
                                                  partnerType: 'Tourist',
                                                  lastMessageContent: '',
                                                ),
                                              );
                                              
                                              if (existingConversation.partnerId.isNotEmpty) {
                                                // Open existing conversation
                                                if (mounted) {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => ChatConversationScreen(
                                                        partnerId: touristId,
                                                        partnerName: name,
                                                        partnerAvatar: avatar.isNotEmpty ? avatar : null,
                                                        partnerType: 'Tourist',
                                                        partnerOnline: false,
                                                      ),
                                                    ),
                                                  );
                                                }
                                              } else {
                                                // Start new conversation
                                                try {
                                                  await MessageService.sendMessage(
                                                    partnerId: touristId,
                                                    content: 'Hello! I\'m the organizer of this activity.',
                                                  );
                                                  if (mounted) {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) => ChatConversationScreen(
                                                          partnerId: touristId,
                                                          partnerName: name,
                                                          partnerAvatar: avatar.isNotEmpty ? avatar : null,
                                                          partnerType: 'Tourist',
                                                          partnerOnline: false,
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                } catch (e) {
                                                  if (mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text('Error starting conversation: $e'),
                                                        backgroundColor: Colors.red,
                                                      ),
                                                    );
                                                  }
                                                }
                                              }
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF4B63FF),
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              padding: const EdgeInsets.symmetric(vertical: 8),
                                            ),
                                            child: const Text(
                                              'Contact',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: () {
                                              final touristId = tourist['_id']?.toString() ?? tourist['id']?.toString() ?? '';
                                              if (touristId.isEmpty) return;
                                              
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => PublicUserProfileScreen(
                                                    userId: touristId,
                                                    canContact: true,
                                                  ),
                                                ),
                                              );
                                            },
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: const Color(0xFF4B63FF),
                                              side: const BorderSide(color: Color(0xFF4B63FF)),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              padding: const EdgeInsets.symmetric(vertical: 8),
                                            ),
                                            child: const Text(
                                              'Profile',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filteredActivities = _filteredActivities;
    final heroImages = _heroImages;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F1FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchArchives,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            children: [
              _RevenueCard(
                totalRevenue: _formatMoney(_totalRevenue),
                eventsCount: _activities.length,
                participantsText: _compactCount(_totalParticipants),
              ),
              const SizedBox(height: 18),
              _ReachCard(
                images: heroImages,
                participants: _totalParticipants,
                onTap: _allParticipants.isEmpty
                    ? null
                    : () => _showParticipantsSheet(_allParticipants),
              ),
              const SizedBox(height: 18),
              _SearchBar(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 16),
              Text(
                'Completed Activities',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (filteredActivities.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 64),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.archive_outlined,
                          size: 52,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _query.isNotEmpty
                              ? 'No results'
                              : 'No archived activities',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...filteredActivities.asMap().entries.map((entry) {
                  final isLast = entry.key == filteredActivities.length - 1;
                  return Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 18 : 16),
                    child: _ArchiveActivityCard(
                      activity: entry.value.activity,
                      statusLabel: _statusLabel(entry.value.activity),
                      formatDate: _formatDate,
                      formatMoney: _formatMoney,
                      onParticipantsTap: () =>
                          _showParticipantsSheet(entry.value.participants),
                      onDeleteTap: () => _deleteActivity(entry.value.activity),
                      onDetailTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ActivityDetailScreen(
                              activityId: entry.value.activity.id,
                              viewOnly: true,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }),
              if (_hasMoreActivities && !_isLoading && !_isLoadingMore)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Center(
                    child: SizedBox(
                      width: 180,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: _isLoadingMore ? null : () => _fetchArchives(isLoadMore: true),
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: const Color(0xFFE3D7FF),
                          foregroundColor: Colors.black87,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        child: _isLoadingMore
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
                                ),
                              )
                            : const Text(
                                'Show More Records',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
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

class _ArchivedActivityBundle {
  final ActivityModel activity;
  final List<InscriptionModel> participants;

  const _ArchivedActivityBundle({
    required this.activity,
    required this.participants,
  });
}

class _RevenueCard extends StatelessWidget {
  final String totalRevenue;
  final int eventsCount;
  final String participantsText;

  const _RevenueCard({
    required this.totalRevenue,
    required this.eventsCount,
    required this.participantsText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4D63FF), Color(0xFF6C83FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4D63FF).withOpacity(0.20),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                
                const SizedBox(height: 10),
                Text(
                  'Total Revenue',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.95),
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  totalRevenue,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$eventsCount activities',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$participantsText Participant(s)',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReachCard extends StatelessWidget {
  final List<String> images;
  final int participants;
  final VoidCallback? onTap;

  const _ReachCard({
    required this.images,
    required this.participants,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: const Color(0xFFF2ECFF),
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(26)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'COMMUNITY REACH',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total Participants',
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _AvatarStackItem(
                          url: images.isNotEmpty ? images[0] : null,
                        ),
                        _AvatarStackItem(
                          url: images.length > 1 ? images[1] : null,
                          offset: -10,
                        ),
                        _AvatarStackItem(
                          url: images.length > 2 ? images[2] : null,
                          offset: -20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _compactCount(participants),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2243FF),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _compactCount(int value) {
    if (value >= 1000) {
      final compact = (value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1);
      return '${compact}k';
    }
    return value.toString();
  }
}

class _AvatarStackItem extends StatelessWidget {
  final String? url;
  final double offset;

  const _AvatarStackItem({required this.url, this.offset = 0});

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(offset, 0),
      child: CircleAvatar(
        radius: 15,
        backgroundColor: Colors.white,
        backgroundImage: (url != null && url!.isNotEmpty)
            ? NetworkImage(url!)
            : null,
        child: (url == null || url!.isEmpty)
            ? const Icon(Icons.image_outlined, size: 14, color: Colors.grey)
            : null,
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 20, color: Colors.grey[500]),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onSubmitted: onChanged,
              
              decoration: const InputDecoration(
  hintText: 'Search archive...',
  border: InputBorder.none,
  enabledBorder: InputBorder.none,
  focusedBorder: InputBorder.none,
  disabledBorder: InputBorder.none,
  errorBorder: InputBorder.none,
  focusedErrorBorder: InputBorder.none,
  isDense: true,
  contentPadding: EdgeInsets.zero, // 🔥 important aussi
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 32,
            child: ElevatedButton(
              onPressed: () => onChanged(controller.text),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: const Color(0xFF2243FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                'Search',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchiveActivityCard extends StatelessWidget {
  final ActivityModel activity;
  final String statusLabel;
  final String Function(DateTime?) formatDate;
  final String Function(double) formatMoney;
  final VoidCallback onParticipantsTap;
  final VoidCallback onDetailTap;
  final VoidCallback onDeleteTap;

  const _ArchiveActivityCard({
    required this.activity,
    required this.statusLabel,
    required this.formatDate,
    required this.formatMoney,
    required this.onParticipantsTap,
    required this.onDetailTap,
    required this.onDeleteTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final imageUrl = activity.thumbnailUrl;
    final revenue = activity.prix * activity.nombreReservations;
    final tickets = '${activity.nombreReservations}/${activity.capaciteMax}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 170,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (activity.photos.isNotEmpty)
                    AutoImageCarousel(
                      imageUrls: activity.photos,
                      aspectRatio: 16 / 9,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      fit: BoxFit.cover,
                      showIndicators: activity.photos.length > 1,
                      interval: const Duration(seconds: 3),
                    )
                  else if (imageUrl.isNotEmpty)
                    Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _heroFallback(),
                    )
                  else
                    _heroFallback(),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.10),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8E5FF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          statusLabel,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6A5AF9),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        formatDate(activity.dateDebut),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    activity.titre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 22,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    activity.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: onParticipantsTap,
                        child: _StatMini(
                          label: 'REVENUE',
                          value: formatMoney(revenue),
                        ),
                      ),
                      const SizedBox(width: 22),
                      GestureDetector(
                        onTap: onParticipantsTap,
                        child: _StatMini(label: 'TICKETS', value: tickets),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Delete Button
                        GestureDetector(
                          onTap: onDeleteTap,
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.redAccent,
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Detail Button
                        GestureDetector(
                          onTap: onDetailTap,
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE8E5FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.manage_search_rounded,
                              color: Color(0xFF4B63FF),
                              size: 22,
                            ),
                          ),
                        ),
                      ],
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

  Widget _heroFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFB36B), Color(0xFF2D3E75)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.landscape_rounded, color: Colors.white, size: 40),
      ),
    );
  }
}

class _StatMini extends StatelessWidget {
  final String label;
  final String value;

  const _StatMini({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.9,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF2243FF),
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
