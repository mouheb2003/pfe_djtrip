import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../theme/app_theme.dart';
import '../../../models/inscription_model.dart';
import '../../../models/activity_model.dart';
import '../../../services/inscription_service.dart';
import 'booking_detail_screen.dart';

class MyReservationsScreen extends StatelessWidget {
  const MyReservationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF4F3FE),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF4F3FE),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : const Color(0xFF1F235F)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MANAGEMENT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
                color: AppColors.primary,
              ),
            ),
            Text(
              'My Reservations',
              style: TextStyle(
                fontSize: 20,
                height: 1,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF1F235F),
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: SafeArea(child: MyReservationsTab()),
    );
  }
}

class MyReservationsTab extends StatefulWidget {
  const MyReservationsTab({super.key});

  @override
  State<MyReservationsTab> createState() => _MyReservationsTabState();
}

class _MyReservationsTabState extends State<MyReservationsTab>
    with TickerProviderStateMixin {
  late TabController _tabController;

  List<InscriptionModel> _reservations = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadReservations();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _loadReservations({bool refresh = false}) async {
    if (!mounted) return;

    setState(() {
      if (refresh) {
        _isRefreshing = true;
      } else {
        _isLoading = true;
      }
      _errorMessage = null;
    });

    try {
      final reservations = await InscriptionService.getOrganizerReservations();

      if (!mounted) return;

      setState(() {
        _reservations = reservations;
        _isLoading = false;
        _isRefreshing = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading reservations: $e');
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        _errorMessage = 'Failed to load reservations. Please try again.';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load reservations: $e'),
          backgroundColor: const Color(0xFFFF4757),
        ),
      );
    }
  }

  List<InscriptionModel> get _pendingReservations {
    return _reservations.where((r) => r.isPending).toList();
  }

  List<InscriptionModel> get _approvedReservations {
    return _reservations.where((r) => r.isApproved).toList();
  }

  List<InscriptionModel> get _cancelledReservations {
    return _reservations.where((r) => r.isCancelled).toList();
  }

  List<InscriptionModel> _getFilteredReservations(
    List<InscriptionModel> source,
  ) {
    if (_searchQuery.isEmpty) return source;

    final q = _searchQuery.toLowerCase();
    return source.where((r) {
      final activity = r.activite ?? {};
      final tourist = r.touriste ?? {};
      return (activity['titre']?.toString().toLowerCase().contains(q) ??
              false) ||
          (activity['lieu']?.toString().toLowerCase().contains(q) ?? false) ||
          (tourist['fullname']?.toString().toLowerCase().contains(q) ?? false);
    }).toList();
  }

  Future<void> _approveReservation(InscriptionModel reservation) async {
    try {
      setState(() => _isLoading = true);

      final success = await InscriptionService.approveReservation(
        reservation.id,
        messageOrganisateur: 'Approved by organizer',
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reservation approved successfully'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
        _loadReservations(refresh: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to approve reservation'),
            backgroundColor: Color(0xFFFF4757),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Color(0xFFFF4757),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _rejectReservation(InscriptionModel reservation) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Reject Reservation',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Please provide a reason for rejection:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Reason for rejection...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Reject',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() => _isLoading = true);

      final success = await InscriptionService.rejectReservation(
        reservation.id,
        messageOrganisateur: reasonController.text.trim(),
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reservation rejected successfully'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
        _loadReservations(refresh: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to reject reservation'),
            backgroundColor: Color(0xFFFF4757),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Color(0xFFFF4757),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_isLoading && _reservations.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadReservations,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Search Bar
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
            style: TextStyle(
              fontSize: 14, 
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black,
            ),
            decoration: const InputDecoration(
              hintText: 'Search by tourist or activity...',
              hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
              prefixIcon: Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),

        // Custom Pill Tabs
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Row(
              children: [
                _buildTabItem(0, 'PENDING', const Color(0xFFF59E0B)),
                _buildTabItem(1, 'APPROVED', const Color(0xFF10B981)),
                _buildTabItem(2, 'CANCELLED', const Color(0xFFEF4444)),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildReservationsList(
                _getFilteredReservations(_pendingReservations),
                isPending: true,
              ),
              _buildReservationsList(
                _getFilteredReservations(_approvedReservations),
                isPending: false,
              ),
              _buildReservationsList(
                _getFilteredReservations(_cancelledReservations),
                isPending: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabItem(int index, String label, Color activeColor) {
    final isActive = _tabController.index == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _tabController.animateTo(index);
          setState(() {});
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: isActive ? Colors.white : const Color(0xFF7B82A8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReservationsList(
    List<InscriptionModel> reservations, {
    required bool isPending,
  }) {
    if (reservations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPending ? Icons.pending_outlined : Icons.check_circle_outline,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              isPending ? 'No pending reservations' : 'No reservations found',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadReservations(refresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: reservations.length,
        itemBuilder: (context, index) {
          final reservation = reservations[index];
          return _buildReservationCard(reservation, isPending);
        },
      ),
    );
  }

  Widget _buildReservationCard(InscriptionModel reservation, bool isPending) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activityModel = reservation.activityModel;
    final activity = reservation.activite ?? {};
    final tourist = reservation.touriste ?? {};

    // Extraction robuste des données
    String activityTitle = activityModel?.titre ?? (activity['titre'] ?? activity['title'] ?? '').toString();
    if (activityTitle.isEmpty && activity['_id'] != null) {
      activityTitle = 'Activity #${activity['_id'].toString().substring(max(0, activity['_id'].toString().length - 5))}';
    } else if (activityTitle.isEmpty) {
      activityTitle = 'Unknown Activity';
    }

    String touristName = (tourist['fullname'] ?? tourist['nom'] ?? '').toString();
    if (touristName.isEmpty && tourist['_id'] != null) {
      touristName = 'Tourist #${tourist['_id'].toString().substring(max(0, tourist['_id'].toString().length - 5))}';
    } else if (touristName.isEmpty) {
      touristName = 'Unknown Tourist';
    }

    final touristAvatar = (tourist['avatar'] ?? tourist['photoProfil'] ?? '').toString();
    final activityPhoto = activityModel?.thumbnailUrl ?? 
        ((activity['photos'] is List && (activity['photos'] as List).isNotEmpty)
            ? activity['photos'][0].toString()
            : '');

    final participantCount = reservation.nombreParticipants;
    final requestDate = reservation.dateDemande;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrganizerBookingDetailScreen(inscription: reservation),
          ),
        ).then((_) => _loadReservations(refresh: true));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with activity photo and title
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: activityPhoto.isNotEmpty
                        ? Image.network(activityPhoto, fit: BoxFit.cover)
                        : Container(color: AppColors.primary.withOpacity(0.1)),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                      ),
                    ),
                    child: Text(
                      activityTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.people_alt_rounded, size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          '$participantCount',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tourist info
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primary.withOpacity(0.08),
                        backgroundImage: touristAvatar.isNotEmpty ? NetworkImage(touristAvatar) : null,
                        child: touristAvatar.isEmpty
                            ? Text(
                                touristName.isNotEmpty ? touristName[0].toUpperCase() : 'T',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TOURIST',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: Colors.grey[400],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              touristName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF1B2458),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Divider(height: 1, color: Colors.grey[100]),
                  const SizedBox(height: 16),

                  // Request date and actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_month_rounded, size: 16, color: Colors.grey[400]),
                          const SizedBox(width: 8),
                          Text(
                            requestDate != null
                                ? '${requestDate.day}/${requestDate.month}/${requestDate.year}'
                                : 'N/A',
                            style: TextStyle(
                              fontSize: 13, 
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if (!isPending)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: (reservation.isApproved ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            reservation.statusLabel.toUpperCase(),
                            style: TextStyle(
                              color: reservation.isApproved ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                    ],
                  ),

                  if (isPending) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _approveReservation(reservation),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'APPROVE',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _rejectReservation(reservation),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFEF4444),
                              side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'REJECT',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
