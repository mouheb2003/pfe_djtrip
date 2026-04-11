import 'package:equatable/equatable.dart';

/// Modèle de base pour un booking qui peut être reviewé
class BookingReviewModel extends Equatable {
  final String id;
  final String activityId;
  final String activityTitle;
  final DateTime endDate;
  final bool isReviewed;
  final bool isCheckedIn;
  final String? activityImageUrl;
  final int? participantCount;

  const BookingReviewModel({
    required this.id,
    required this.activityId,
    required this.activityTitle,
    required this.endDate,
    required this.isReviewed,
    required this.isCheckedIn,
    this.activityImageUrl,
    this.participantCount,
  });

  /// Crée une instance depuis une réponse API JSON
  factory BookingReviewModel.fromJson(Map<String, dynamic> json) {
    return BookingReviewModel(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      activityId: json['activityId'] as String? ?? 
                  json['activite_id'] as String? ?? 
                  json['activity']?['_id'] as String? ?? '',
      activityTitle: json['activityTitle'] as String? ?? 
                     json['activity']?['titre'] as String? ?? 
                     'Unknown Activity',
      endDate: json['endDate'] != null 
          ? DateTime.parse(json['endDate'] as String)
          : DateTime.parse(json['activity']?['date_fin'] as String? ?? 
                          DateTime.now().toIso8601String()),
      isReviewed: json['isReviewed'] as bool? ?? 
                  json['hasReviewed'] as bool? ?? false,
      isCheckedIn: json['isCheckedIn'] as bool? ?? 
                   json['checkedIn'] as bool? ?? 
                   (json['qr_used_at'] != null),
      activityImageUrl: json['activityImageUrl'] as String? ?? 
                       json['activity']?['image_url'] as String?,
      participantCount: json['participantCount'] as int? ?? 
                       json['nombre_participants'] as int?,
    );
  }

  /// Convertit en JSON pour l'API
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'activityId': activityId,
      'activityTitle': activityTitle,
      'endDate': endDate.toIso8601String(),
      'isReviewed': isReviewed,
      'isCheckedIn': isCheckedIn,
      'activityImageUrl': activityImageUrl,
      'participantCount': participantCount,
    };
  }

  /// Convertit en JSON pour la persistance locale
  Map<String, dynamic> toStorageJson() {
    return {
      'id': id,
      'activityId': activityId,
      'activityTitle': activityTitle,
      'endDate': endDate.toIso8601String(),
      'isReviewed': isReviewed,
      'isCheckedIn': isCheckedIn,
      'activityImageUrl': activityImageUrl,
      'participantCount': participantCount,
    };
  }

  /// Crée une instance depuis le stockage local
  factory BookingReviewModel.fromStorageJson(Map<String, dynamic> json) {
    return BookingReviewModel(
      id: json['id'] as String,
      activityId: json['activityId'] as String,
      activityTitle: json['activityTitle'] as String,
      endDate: DateTime.parse(json['endDate'] as String),
      isReviewed: json['isReviewed'] as bool,
      isCheckedIn: json['isCheckedIn'] as bool,
      activityImageUrl: json['activityImageUrl'] as String?,
      participantCount: json['participantCount'] as int?,
    );
  }

  /// Copie avec certains champs modifiés
  BookingReviewModel copyWith({
    String? id,
    String? activityId,
    String? activityTitle,
    DateTime? endDate,
    bool? isReviewed,
    bool? isCheckedIn,
    String? activityImageUrl,
    int? participantCount,
  }) {
    return BookingReviewModel(
      id: id ?? this.id,
      activityId: activityId ?? this.activityId,
      activityTitle: activityTitle ?? this.activityTitle,
      endDate: endDate ?? this.endDate,
      isReviewed: isReviewed ?? this.isReviewed,
      isCheckedIn: isCheckedIn ?? this.isCheckedIn,
      activityImageUrl: activityImageUrl ?? this.activityImageUrl,
      participantCount: participantCount ?? this.participantCount,
    );
  }

  @override
  List<Object?> get props => [
        id,
        activityId,
        activityTitle,
        endDate,
        isReviewed,
        isCheckedIn,
        activityImageUrl,
        participantCount,
      ];
}
