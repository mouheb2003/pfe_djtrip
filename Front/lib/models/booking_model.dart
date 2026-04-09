class BookingModel {
  final String id;
  final String activityId;
  final String touristeId;
  final String organisateurId;
  final String statut;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime dateReservation;
  final int nombreParticipants;
  final double prixTotal;
  final String? paymentStatus;
  final String? paymentId;
  final bool? checkedIn;
  final DateTime? checkInTime;
  final bool? hasReviewed;
  final DateTime? reviewDate;
  final Map<String, dynamic>? touriste;
  final Map<String, dynamic>? activity;
  final Map<String, dynamic>? reviewReminder;

  const BookingModel({
    required this.id,
    required this.activityId,
    required this.touristeId,
    required this.organisateurId,
    required this.statut,
    required this.createdAt,
    this.updatedAt,
    required this.dateReservation,
    required this.nombreParticipants,
    required this.prixTotal,
    this.paymentStatus,
    this.paymentId,
    this.checkedIn,
    this.checkInTime,
    this.hasReviewed,
    this.reviewDate,
    this.touriste,
    this.activity,
    this.reviewReminder,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      activityId: json['activityId']?.toString() ?? json['activity_id']?.toString() ?? '',
      touristeId: json['touristeId']?.toString() ?? json['touriste_id']?.toString() ?? '',
      organisateurId: json['organisateurId']?.toString() ?? json['organisateur_id']?.toString() ?? '',
      statut: json['statut']?.toString() ?? json['status']?.toString() ?? 'pending',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
      dateReservation: DateTime.tryParse(json['dateReservation']?.toString() ?? json['date_reservation']?.toString() ?? '') ?? DateTime.now(),
      nombreParticipants: (json['nombreParticipants'] as num?)?.toInt() ?? json['nombre_participants'] ?? 1,
      prixTotal: (json['prixTotal'] as num?)?.toDouble() ?? json['prix_total']?.toDouble() ?? 0.0,
      paymentStatus: json['paymentStatus']?.toString() ?? json['payment_status'],
      paymentId: json['paymentId']?.toString() ?? json['payment_id'],
      checkedIn: json['checkedIn'] as bool? ?? json['checked_in'],
      checkInTime: json['checkInTime'] != null 
          ? DateTime.tryParse(json['checkInTime'].toString())
          : json['check_in_time'] != null
              ? DateTime.tryParse(json['check_in_time'].toString())
              : null,
      hasReviewed: json['hasReviewed'] as bool? ?? json['has_reviewed'],
      reviewDate: json['reviewDate'] != null 
          ? DateTime.tryParse(json['reviewDate'].toString())
          : json['review_date'] != null
              ? DateTime.tryParse(json['review_date'].toString())
              : null,
      touriste: json['touriste'] as Map<String, dynamic>?,
      activity: json['activity'] as Map<String, dynamic>?,
      reviewReminder: json['reviewReminder'] as Map<String, dynamic>? ?? json['review_reminder'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'activityId': activityId,
      'touristeId': touristeId,
      'organisateurId': organisateurId,
      'statut': statut,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'dateReservation': dateReservation.toIso8601String(),
      'nombreParticipants': nombreParticipants,
      'prixTotal': prixTotal,
      'paymentStatus': paymentStatus,
      'paymentId': paymentId,
      'checkedIn': checkedIn,
      'checkInTime': checkInTime?.toIso8601String(),
      'hasReviewed': hasReviewed,
      'reviewDate': reviewDate?.toIso8601String(),
      'touriste': touriste,
      'activity': activity,
      'reviewReminder': reviewReminder,
    };
  }

  BookingModel copyWith({
    String? id,
    String? activityId,
    String? touristeId,
    String? organisateurId,
    String? statut,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? dateReservation,
    int? nombreParticipants,
    double? prixTotal,
    String? paymentStatus,
    String? paymentId,
    bool? checkedIn,
    DateTime? checkInTime,
    bool? hasReviewed,
    DateTime? reviewDate,
    Map<String, dynamic>? touriste,
    Map<String, dynamic>? activity,
    Map<String, dynamic>? reviewReminder,
  }) {
    return BookingModel(
      id: id ?? this.id,
      activityId: activityId ?? this.activityId,
      touristeId: touristeId ?? this.touristeId,
      organisateurId: organisateurId ?? this.organisateurId,
      statut: statut ?? this.statut,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      dateReservation: dateReservation ?? this.dateReservation,
      nombreParticipants: nombreParticipants ?? this.nombreParticipants,
      prixTotal: prixTotal ?? this.prixTotal,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentId: paymentId ?? this.paymentId,
      checkedIn: checkedIn ?? this.checkedIn,
      checkInTime: checkInTime ?? this.checkInTime,
      hasReviewed: hasReviewed ?? this.hasReviewed,
      reviewDate: reviewDate ?? this.reviewDate,
      touriste: touriste ?? this.touriste,
      activity: activity ?? this.activity,
      reviewReminder: reviewReminder ?? this.reviewReminder,
    );
  }

  // Helper methods
  bool get isPending => statut == 'pending';
  bool get isConfirmed => statut == 'confirmed';
  bool get isCancelled => statut == 'cancelled';
  bool get isRejected => statut == 'rejected';
  bool get isCheckedIn => checkedIn == true;
  bool get hasLeftReview => hasReviewed == true;
  bool get canReview => isConfirmed && isCheckedIn && !hasLeftReview;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BookingModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'BookingModel(id: $id, status: $statut, checkedIn: $checkedIn, hasReviewed: $hasReviewed)';
  }
}
