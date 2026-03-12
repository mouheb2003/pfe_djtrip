import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/avis.dart';
import '../services/avis_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Star rating row widget
// ─────────────────────────────────────────────────────────────────────────────
class StarRatingPicker extends StatefulWidget {
  final double initialValue;
  final ValueChanged<double> onChanged;

  const StarRatingPicker({
    super.key,
    this.initialValue = 0,
    required this.onChanged,
  });

  @override
  State<StarRatingPicker> createState() => _StarRatingPickerState();
}

class _StarRatingPickerState extends State<StarRatingPicker> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final star = i + 1;
        return GestureDetector(
          onTap: () {
            setState(() => _value = star.toDouble());
            widget.onChanged(_value);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              _value >= star ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 40,
              color: _value >= star ? Colors.amber : Colors.grey[400],
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialog: Submit a review for an activity
// ─────────────────────────────────────────────────────────────────────────────
Future<bool> showSubmitActivityReviewDialog(
  BuildContext context, {
  required String activiteId,
  required String activiteTitle,
}) async {
  double selectedNote = 0;
  final commentController = TextEditingController();
  bool submitting = false;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        title: Column(
          children: [
            const Icon(Icons.rate_review, color: Color(0xFFFF6B1A), size: 36),
            const SizedBox(height: 8),
            const Text(
              'Rate this Activity',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              activiteTitle,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              StarRatingPicker(onChanged: (v) => selectedNote = v),
              const SizedBox(height: 8),
              Text(
                selectedNote == 0
                    ? 'Tap a star to rate'
                    : _noteLabel(selectedNote),
                style: TextStyle(
                  fontSize: 13,
                  color: selectedNote == 0 ? Colors.grey : Colors.amber[800],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: commentController,
                maxLines: 4,
                maxLength: 1000,
                decoration: InputDecoration(
                  hintText: 'Share your experience (optional)...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFFF6B1A)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: submitting ? null : () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B1A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: submitting
                ? null
                : () async {
                    if (selectedNote == 0) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Please select a star rating'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                    setState(() => submitting = true);
                    try {
                      await AvisService.submitActivityReview(
                        activiteId: activiteId,
                        note: selectedNote,
                        commentaire: commentController.text,
                      );
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } catch (e) {
                      if (ctx.mounted) {
                        setState(() => submitting = false);
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              e.toString().replaceFirst('Exception: ', ''),
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
            child: submitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Submit'),
          ),
        ],
      ),
    ),
  );

  commentController.dispose();
  return result == true;
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialog: Submit a rating for an organizer
// ─────────────────────────────────────────────────────────────────────────────
Future<bool> showSubmitOrganisateurRatingDialog(
  BuildContext context, {
  required String organisateurId,
  required String organisateurName,
}) async {
  double selectedNote = 0;
  final commentController = TextEditingController();
  bool submitting = false;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        title: Column(
          children: [
            const Icon(Icons.person_pin, color: Color(0xFF2D5016), size: 36),
            const SizedBox(height: 8),
            const Text(
              'Rate this Organizer',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              organisateurName,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF2D5016),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              StarRatingPicker(onChanged: (v) => selectedNote = v),
              const SizedBox(height: 8),
              Text(
                selectedNote == 0
                    ? 'Tap a star to rate'
                    : _noteLabel(selectedNote),
                style: TextStyle(
                  fontSize: 13,
                  color: selectedNote == 0 ? Colors.grey : Colors.amber[800],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: commentController,
                maxLines: 3,
                maxLength: 1000,
                decoration: InputDecoration(
                  hintText: 'Leave a comment (optional)...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF2D5016)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: submitting ? null : () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D5016),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: submitting
                ? null
                : () async {
                    if (selectedNote == 0) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Please select a star rating'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                    setState(() => submitting = true);
                    try {
                      await AvisService.submitOrganisateurRating(
                        organisateurId: organisateurId,
                        note: selectedNote,
                        commentaire: commentController.text,
                      );
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } catch (e) {
                      if (ctx.mounted) {
                        setState(() => submitting = false);
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              e.toString().replaceFirst('Exception: ', ''),
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
            child: submitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Submit'),
          ),
        ],
      ),
    ),
  );

  commentController.dispose();
  return result == true;
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom sheet: View all reviews for an activity
// ─────────────────────────────────────────────────────────────────────────────
Future<void> showActivityReviewsSheet(
  BuildContext context, {
  required String activiteId,
  required String activiteTitle,
  required double noteMoyenne,
  required int nombreAvis,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ActivityReviewsSheet(
      activiteId: activiteId,
      activiteTitle: activiteTitle,
      noteMoyenne: noteMoyenne,
      nombreAvis: nombreAvis,
    ),
  );
}

class _ActivityReviewsSheet extends StatefulWidget {
  final String activiteId;
  final String activiteTitle;
  final double noteMoyenne;
  final int nombreAvis;

  const _ActivityReviewsSheet({
    required this.activiteId,
    required this.activiteTitle,
    required this.noteMoyenne,
    required this.nombreAvis,
  });

  @override
  State<_ActivityReviewsSheet> createState() => _ActivityReviewsSheetState();
}

class _ActivityReviewsSheetState extends State<_ActivityReviewsSheet> {
  List<Avis> _reviews = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final reviews = await AvisService.getActivityReviews(widget.activiteId);
      if (mounted)
        setState(() {
          _reviews = reviews;
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                children: [
                  const Icon(
                    Icons.rate_review,
                    color: Color(0xFFFF6B1A),
                    size: 28,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.activiteTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Colors.amber,
                        size: 22,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.noteMoyenne > 0
                            ? widget.noteMoyenne.toStringAsFixed(1)
                            : 'No ratings yet',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                      if (widget.noteMoyenne > 0) ...[
                        Text(
                          ' / 5.0',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '(${widget.nombreAvis} review${widget.nombreAvis == 1 ? '' : 's'})',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Review list
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFF6B1A),
                      ),
                    )
                  : _reviews.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.rate_review_outlined,
                            size: 60,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No reviews yet',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: scroll,
                      padding: const EdgeInsets.all(16),
                      itemCount: _reviews.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) => _ReviewTile(_reviews[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final Avis avis;
  const _ReviewTile(this.avis);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFFFF6B1A),
            backgroundImage:
                avis.touristeAvatar != null && avis.touristeAvatar!.isNotEmpty
                ? NetworkImage(avis.touristeAvatar!)
                : null,
            child: avis.touristeAvatar == null || avis.touristeAvatar!.isEmpty
                ? Text(
                    (avis.touristeFullname ?? 'T').isNotEmpty
                        ? (avis.touristeFullname ?? 'T')[0].toUpperCase()
                        : 'T',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      avis.touristeFullname ?? 'Tourist',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      DateFormat('dd MMM yyyy').format(avis.createdAt),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < avis.note
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 16,
                      color: Colors.amber,
                    ),
                  ),
                ),
                if (avis.commentaire != null &&
                    avis.commentaire!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    avis.commentaire!,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
String _noteLabel(double note) {
  switch (note.toInt()) {
    case 1:
      return 'Poor';
    case 2:
      return 'Fair';
    case 3:
      return 'Good';
    case 4:
      return 'Very good';
    case 5:
      return 'Excellent!';
    default:
      return '';
  }
}
