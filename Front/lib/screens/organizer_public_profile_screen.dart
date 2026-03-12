import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/activite.dart';
import '../models/avis.dart';
import '../services/avis_service.dart';
import 'chat_screen.dart';

/// Public organizer profile — shown to tourists tapping "Profile"
/// in an activity card. Displays bio, stats, and reviews.
class OrganizerPublicProfileScreen extends StatefulWidget {
  final String organisateurId;
  final String fullname;
  final String? avatar;
  final double noteMoyenne;
  final int nombreAvis;

  const OrganizerPublicProfileScreen({
    super.key,
    required this.organisateurId,
    required this.fullname,
    this.avatar,
    required this.noteMoyenne,
    required this.nombreAvis,
  });

  // Convenience constructor from OrganisateurInfo
  factory OrganizerPublicProfileScreen.fromInfo(OrganisateurInfo info) {
    return OrganizerPublicProfileScreen(
      organisateurId: info.id,
      fullname: info.fullname,
      avatar: info.avatar,
      noteMoyenne: info.noteMoyenne,
      nombreAvis: info.nombreAvis,
    );
  }

  @override
  State<OrganizerPublicProfileScreen> createState() =>
      _OrganizerPublicProfileScreenState();
}

class _OrganizerPublicProfileScreenState
    extends State<OrganizerPublicProfileScreen> {
  List<Avis> _reviews = [];
  bool _loadingReviews = true;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    try {
      final r = await AvisService.getOrganisateurRatings(widget.organisateurId);
      if (mounted)
        setState(() {
          _reviews = r;
          _loadingReviews = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loadingReviews = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: CustomScrollView(
        slivers: [
          // ── Header SliverAppBar ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: const Color(0xFF2D5016),
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2D5016), Color(0xFF4a7c28)],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 56),
                    CircleAvatar(
                      radius: 52,
                      backgroundColor: Colors.white.withOpacity(0.25),
                      backgroundImage:
                          widget.avatar != null && widget.avatar!.isNotEmpty
                          ? NetworkImage(widget.avatar!)
                          : null,
                      child: widget.avatar == null || widget.avatar!.isEmpty
                          ? Text(
                              widget.fullname.isNotEmpty
                                  ? widget.fullname[0].toUpperCase()
                                  : 'O',
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.fullname,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Activity Organizer',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Stats row ────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _statItem(
                            Icons.star_rounded,
                            Colors.amber,
                            widget.noteMoyenne.toStringAsFixed(1),
                            'Rating / 5.0',
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.grey[200],
                        ),
                        Expanded(
                          child: _statItem(
                            Icons.rate_review_outlined,
                            const Color(0xFFFF6B1A),
                            '${widget.nombreAvis}',
                            'Reviews',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Message button ────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              partnerId: widget.organisateurId,
                              partnerName: widget.fullname,
                              partnerAvatar: widget.avatar,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.message_outlined, size: 20),
                      label: Text(
                        'Message ${widget.fullname.split(' ').first}',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B1A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Reviews section ───────────────────────────────────────
                  Row(
                    children: [
                      const Icon(
                        Icons.rate_review,
                        color: Color(0xFF2D5016),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Reviews (${widget.nombreAvis})',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2D5016),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _loadingReviews
                      ? const Center(child: CircularProgressIndicator())
                      : _reviews.isEmpty
                      ? _buildNoReviews()
                      : Column(
                          children: _reviews
                              .map((r) => _buildReviewCard(r))
                              .toList(),
                        ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, Color color, String value, String label) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildNoReviews() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.star_outline, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 8),
          Text(
            'No reviews yet',
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Avis avis) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: avatar + name + date
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFFF6B1A),
                backgroundImage:
                    avis.touristeAvatar != null &&
                        avis.touristeAvatar!.isNotEmpty
                    ? NetworkImage(avis.touristeAvatar!)
                    : null,
                child:
                    avis.touristeAvatar == null || avis.touristeAvatar!.isEmpty
                    ? Text(
                        (avis.touristeFullname?.isNotEmpty ?? false)
                            ? avis.touristeFullname![0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      avis.touristeFullname ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      DateFormat('d MMM yyyy').format(avis.createdAt.toLocal()),
                      style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
              // Stars
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < avis.note
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 16,
                    color: i < avis.note ? Colors.amber : Colors.grey[300],
                  );
                }),
              ),
            ],
          ),
          if (avis.commentaire != null && avis.commentaire!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              avis.commentaire!,
              style: const TextStyle(fontSize: 13.5, height: 1.45),
            ),
          ],
        ],
      ),
    );
  }
}
