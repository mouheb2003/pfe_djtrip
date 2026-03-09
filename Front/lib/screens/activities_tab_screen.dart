import 'package:flutter/material.dart';
import '../models/activite.dart';
import '../models/user.dart';
import '../models/inscription.dart';
import '../services/activity_service.dart';
import '../services/inscription_service.dart';
import '../widgets/activity_card_tourist.dart';
import 'package:intl/intl.dart';

class ActivitiesTabScreen extends StatefulWidget {
  final User user;

  const ActivitiesTabScreen({super.key, required this.user});

  @override
  State<ActivitiesTabScreen> createState() => _ActivitiesTabScreenState();
}

class _ActivitiesTabScreenState extends State<ActivitiesTabScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Activities',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFF6B1A),
          labelColor: const Color(0xFFFF6B1A),
          unselectedLabelColor: Colors.grey[600],
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(icon: Icon(Icons.explore), text: 'All Activities'),
            Tab(icon: Icon(Icons.history), text: 'My Past Activities'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          AllActivitiesTab(user: widget.user),
          MyPastActivitiesTab(user: widget.user),
        ],
      ),
    );
  }
}

// Tab for all activities (upcoming and in progress)
class AllActivitiesTab extends StatefulWidget {
  final User user;

  const AllActivitiesTab({super.key, required this.user});

  @override
  State<AllActivitiesTab> createState() => _AllActivitiesTabState();
}

class _AllActivitiesTabState extends State<AllActivitiesTab>
    with AutomaticKeepAliveClientMixin {
  List<Activite> _activities = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _sortBy =
      'upcoming'; // upcoming, recent, price_low, price_high, rating

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Auto-reload when the tab becomes visible
    if (mounted && !_isLoading) {
      _loadActivities();
    }
  }

  Future<void> _loadActivities() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ActivityService.getAllActivities();

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success']) {
          _activities = result['activities'] as List<Activite>;
          _sortActivities();
        } else {
          _errorMessage = result['message'];
        }
      });
    }
  }

  void _sortActivities() {
    switch (_sortBy) {
      case 'upcoming':
        _activities.sort((a, b) => a.dateDebut.compareTo(b.dateDebut));
        break;
      case 'recent':
        _activities.sort((a, b) => b.dateDebut.compareTo(a.dateDebut));
        break;
      case 'price_low':
        _activities.sort((a, b) => a.prix.compareTo(b.prix));
        break;
      case 'price_high':
        _activities.sort((a, b) => b.prix.compareTo(a.prix));
        break;
      case 'rating':
        _activities.sort((a, b) => b.noteMoyenne.compareTo(a.noteMoyenne));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF6B1A)),
      );
    }

    if (_errorMessage != null) {
      return RefreshIndicator(
        onRefresh: _loadActivities,
        color: const Color(0xFFFF6B1A),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height - 200,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Error',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pull down to refresh',
                    style: TextStyle(
                      color: const Color(0xFFFF6B1A),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadActivities,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B1A),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_activities.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadActivities,
        color: const Color(0xFFFF6B1A),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height - 200,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No activities available',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Check back later for new activities',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pull down to refresh',
                    style: TextStyle(
                      color: const Color(0xFFFF6B1A),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadActivities,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B1A),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadActivities,
      color: const Color(0xFFFF6B1A),
      child: Column(
        children: [
          // Sort Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.grey[50],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_activities.length} activit${_activities.length > 1 ? "ies" : "y"} available',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: DropdownButton<String>(
                    value: _sortBy,
                    underline: const SizedBox(),
                    icon: const Icon(
                      Icons.sort,
                      size: 20,
                      color: Color(0xFFFF6B1A),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'upcoming',
                        child: Text('Upcoming First'),
                      ),
                      DropdownMenuItem(
                        value: 'recent',
                        child: Text('Most Recent'),
                      ),
                      DropdownMenuItem(
                        value: 'price_low',
                        child: Text('Price: Low to High'),
                      ),
                      DropdownMenuItem(
                        value: 'price_high',
                        child: Text('Price: High to Low'),
                      ),
                      DropdownMenuItem(
                        value: 'rating',
                        child: Text('Best Rating'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _sortBy = value;
                          _sortActivities();
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          // Activities List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _activities.length,
              itemBuilder: (context, index) {
                return ActivityCardTourist(
                  activity: _activities[index],
                  user: widget.user,
                  onRefresh: _loadActivities,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Tab for past activities the tourist participated in
class MyPastActivitiesTab extends StatefulWidget {
  final User user;

  const MyPastActivitiesTab({super.key, required this.user});

  @override
  State<MyPastActivitiesTab> createState() => _MyPastActivitiesTabState();
}

class _MyPastActivitiesTabState extends State<MyPastActivitiesTab>
    with AutomaticKeepAliveClientMixin {
  List<Inscription> _pastInscriptions = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadPastActivities();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (mounted && !_isLoading) {
      _loadPastActivities();
    }
  }

  Future<void> _loadPastActivities() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Charger toutes les inscriptions du touriste
      final allInscriptions = await InscriptionService.getMesInscriptions();

      final now = DateTime.now();

      // Filtrer pour garder seulement les inscriptions approuvées avec activités terminées
      final pastInscriptions = allInscriptions.where((inscription) {
        return inscription.statut == 'approuvee' &&
            inscription.activite != null &&
            inscription.activite!.dateFin.isBefore(now);
      }).toList();

      // Trier par date (plus récent en premier)
      pastInscriptions.sort(
        (a, b) => b.activite!.dateFin.compareTo(a.activite!.dateFin),
      );

      if (mounted) {
        setState(() {
          _pastInscriptions = pastInscriptions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _showActivityDetails(BuildContext context, Inscription inscription) {
    final activity = inscription.activite!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Image
              if (activity.photos.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    activity.photos.first,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: 20),

              // Title
              Text(
                activity.titre,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // Type badge
              Wrap(
                spacing: 8,
                children: [
                  Chip(
                    avatar: Icon(
                      _getActivityIcon(activity.typeActivite),
                      size: 16,
                      color: Colors.white,
                    ),
                    label: Text(activity.typeActivite),
                    backgroundColor: const Color(0xFFFF6B1A),
                    labelStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Chip(
                    label: Text(
                      '${inscription.nombreParticipants} participant(s)',
                    ),
                    backgroundColor: Colors.blue.shade50,
                    labelStyle: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Description
              _buildDetailSection(
                Icons.description,
                'Description',
                activity.description,
              ),
              const SizedBox(height: 16),

              // Date
              _buildDetailSection(
                Icons.calendar_today,
                'Date',
                '${_formatDate(activity.dateDebut)} - ${_formatDate(activity.dateFin)}',
              ),
              const SizedBox(height: 16),

              // Location
              _buildDetailSection(Icons.location_on, 'Lieu', activity.lieu),
              const SizedBox(height: 16),

              // Duration
              _buildDetailSection(
                Icons.access_time,
                'Durée',
                '${activity.duree.toStringAsFixed(1)} heures',
              ),
              const SizedBox(height: 16),

              // Price
              _buildDetailSection(
                Icons.attach_money,
                'Prix payé',
                '${inscription.prixTotal.toStringAsFixed(0)} DT (${activity.prix.toStringAsFixed(0)} DT x ${inscription.nombreParticipants})',
              ),
              const SizedBox(height: 20),

              // Close button
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B1A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Fermer',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(IconData icon, String title, String content) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B1A).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFFFF6B1A)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getActivityIcon(String type) {
    switch (type.toLowerCase()) {
      case 'randonnée':
        return Icons.hiking;
      case 'aventure':
        return Icons.explore;
      case 'culture':
        return Icons.museum;
      case 'gastronomie':
        return Icons.restaurant;
      case 'sport':
        return Icons.sports;
      case 'excursion':
        return Icons.directions_bus;
      case 'visite guidée':
        return Icons.tour;
      default:
        return Icons.event;
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  Widget _buildPastActivityCard(Inscription inscription) {
    final activity = inscription.activite!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Image thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: activity.photos.isNotEmpty
                  ? Image.network(
                      activity.photos.first,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[300],
                        child: const Icon(Icons.image, size: 30),
                      ),
                    )
                  : Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey[300],
                      child: Icon(
                        _getActivityIcon(activity.typeActivite),
                        size: 30,
                        color: const Color(0xFFFF6B1A),
                      ),
                    ),
            ),
            const SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.titre,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(activity.dateFin),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          activity.lieu,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Eye icon button
            IconButton(
              onPressed: () => _showActivityDetails(context, inscription),
              icon: const Icon(
                Icons.visibility_outlined,
                color: Color(0xFFFF6B1A),
                size: 28,
              ),
              tooltip: 'Voir les détails',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF6B1A)),
      );
    }

    if (_errorMessage != null) {
      return RefreshIndicator(
        onRefresh: _loadPastActivities,
        color: const Color(0xFFFF6B1A),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height - 200,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Erreur',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadPastActivities,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Réessayer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B1A),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_pastInscriptions.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadPastActivities,
        color: const Color(0xFFFF6B1A),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height - 200,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Aucune activité passée',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Les activités auxquelles vous avez participé\naparaîtront ici',
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadPastActivities,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualiser'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B1A),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPastActivities,
      color: const Color(0xFFFF6B1A),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pastInscriptions.length,
        itemBuilder: (context, index) {
          return _buildPastActivityCard(_pastInscriptions[index]);
        },
      ),
    );
  }
}
