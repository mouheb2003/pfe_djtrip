import 'package:equatable/equatable.dart';
import 'booking_review_model.dart';

/// Élément de la queue de review avec métadonnées
class ReviewQueueItem extends Equatable {
  final BookingReviewModel booking;
  final DateTime queuedAt;
  final DateTime? lastShownAt;
  final int showCount;
  final bool isSnoozed;
  final DateTime? snoozedUntil;

  const ReviewQueueItem({
    required this.booking,
    required this.queuedAt,
    this.lastShownAt,
    this.showCount = 0,
    this.isSnoozed = false,
    this.snoozedUntil,
  });

  factory ReviewQueueItem.fromBooking(BookingReviewModel booking) {
    return ReviewQueueItem(
      booking: booking,
      queuedAt: DateTime.now(),
    );
  }

  factory ReviewQueueItem.fromJson(Map<String, dynamic> json) {
    return ReviewQueueItem(
      booking: BookingReviewModel.fromStorageJson(json['booking'] as Map<String, dynamic>),
      queuedAt: DateTime.parse(json['queuedAt'] as String),
      lastShownAt: json['lastShownAt'] != null 
          ? DateTime.parse(json['lastShownAt'] as String) 
          : null,
      showCount: json['showCount'] as int? ?? 0,
      isSnoozed: json['isSnoozed'] as bool? ?? false,
      snoozedUntil: json['snoozedUntil'] != null 
          ? DateTime.parse(json['snoozedUntil'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'booking': booking.toStorageJson(),
      'queuedAt': queuedAt.toIso8601String(),
      'lastShownAt': lastShownAt?.toIso8601String(),
      'showCount': showCount,
      'isSnoozed': isSnoozed,
      'snoozedUntil': snoozedUntil?.toIso8601String(),
    };
  }

  ReviewQueueItem copyWith({
    BookingReviewModel? booking,
    DateTime? queuedAt,
    DateTime? lastShownAt,
    int? showCount,
    bool? isSnoozed,
    DateTime? snoozedUntil,
  }) {
    return ReviewQueueItem(
      booking: booking ?? this.booking,
      queuedAt: queuedAt ?? this.queuedAt,
      lastShownAt: lastShownAt ?? this.lastShownAt,
      showCount: showCount ?? this.showCount,
      isSnoozed: isSnoozed ?? this.isSnoozed,
      snoozedUntil: snoozedUntil ?? this.snoozedUntil,
    );
  }

  /// Vérifie si l'item peut être affiché maintenant
  bool canBeShown({required Duration cooldown}) {
    if (isSnoozed) {
      if (snoozedUntil != null && DateTime.now().isBefore(snoozedUntil!)) {
        return false;
      }
    }

    if (lastShownAt != null) {
      final timeSinceLastShown = DateTime.now().difference(lastShownAt!);
      if (timeSinceLastShown < cooldown) {
        return false;
      }
    }

    return true;
  }

  /// Marque comme affiché maintenant
  ReviewQueueItem markAsShown() {
    return copyWith(
      lastShownAt: DateTime.now(),
      showCount: showCount + 1,
      isSnoozed: false,
      snoozedUntil: null,
    );
  }

  /// Snooze pour une durée donnée
  ReviewQueueItem snooze(Duration duration) {
    return copyWith(
      isSnoozed: true,
      snoozedUntil: DateTime.now().add(duration),
    );
  }

  @override
  List<Object?> get props => [
        booking,
        queuedAt,
        lastShownAt,
        showCount,
        isSnoozed,
        snoozedUntil,
      ];
}
