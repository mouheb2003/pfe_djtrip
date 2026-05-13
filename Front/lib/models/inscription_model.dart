import 'dart:convert';
import 'package:flutter/material.dart';
import 'activity_model.dart';

class InscriptionModel {
  final String id;
  final String statut; // approuvee | annulee | verifie | en_attente
  final int nombreParticipants;
  final double prixTotal;
  final DateTime? dateDemande;
  final String? messageTouriste;
  final String? messageOrganisateur;
  final Map<String, dynamic>? activite; // populated activite_id
  final Map<String, dynamic>? touriste; // populated touriste_id
  final Map<String, dynamic>? organisateur; // populated organisateur_id
  final String? qrToken;
  final DateTime? qrTokenGeneratedAt;
  final DateTime? qrTokenExpiresAt;
  final DateTime? qrUsedAt;

  const InscriptionModel({
    required this.id,
    required this.statut,
    required this.nombreParticipants,
    required this.prixTotal,
    this.dateDemande,
    this.messageTouriste,
    this.messageOrganisateur,
    this.activite,
    this.touriste,
    this.organisateur,
    this.qrToken,
    this.qrTokenGeneratedAt,
    this.qrTokenExpiresAt,
    this.qrUsedAt,
  });

  static Map<String, dynamic>? _safeMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      try {
        return raw.map((k, v) => MapEntry(k.toString(), v));
      } catch (_) {
        return null;
      }
    }

    if (raw is String) {
      final text = raw.trim();
      if (text.isEmpty) return null;
      if (!text.startsWith('{')) return {'_id': text};
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) {
          return decoded.map((k, v) => MapEntry(k.toString(), v));
        }
      } catch (_) {
        return {'_id': text};
      }
    }

    return null;
  }

  static String _normalizeStatus(dynamic rawStatus) {
    final status = rawStatus?.toString().trim().toLowerCase() ?? '';
    if (status == 'approved' ||
        status == 'confirmée' ||
        status == 'confirmed') {
      return 'approuvee';
    }
    if (status == 'pending' ||
        status == 'en attente' ||
        status.endsWith('pending_confirmation')) {
      return 'en_attente';
    }
    if (status == 'rejected' || status == 'refusée') {
      return 'refusee';
    }
    if (status == 'cancelled' || status == 'canceled' || status == 'annulée') {
      return 'annulee';
    }
    return status;
  }

  factory InscriptionModel.fromJson(Map<String, dynamic> json) {
    return InscriptionModel(
      id: json['_id'] as String? ?? '',
      statut: _normalizeStatus(json['statut']),
      nombreParticipants: (json['nombre_participants'] as num? ?? 1).toInt(),
      prixTotal: (json['prix_total'] as num? ?? 0).toDouble(),
      dateDemande: json['date_demande'] != null
          ? DateTime.tryParse(json['date_demande'].toString())
          : null,
      messageTouriste: json['message_touriste'] as String?,
      messageOrganisateur: json['message_organisateur'] as String?,
      activite: _safeMap(json['activite']),
      touriste: _safeMap(json['touriste']),
      organisateur: _safeMap(json['organisateur']),
      qrToken: json['qr_token'] as String?,
      qrTokenGeneratedAt: json['qr_token_generated_at'] != null
          ? DateTime.tryParse(json['qr_token_generated_at'].toString())
          : null,
      qrTokenExpiresAt: json['qr_token_expires_at'] != null
          ? DateTime.tryParse(json['qr_token_expires_at'].toString())
          : null,
      qrUsedAt: json['qr_used_at'] != null
          ? DateTime.tryParse(json['qr_used_at'].toString())
          : null,
    );
  }

  String get statusLabel {
    switch (statut) {
      case 'approuvee':
        return 'Confirmed';
      case 'verifie':
        return 'Used';
      case 'en_attente':
        return 'Pending';
      case 'annulee':
        return 'Cancelled';
      default:
        return statut;
    }
  }

  Color get statusColor {
    switch (statut) {
      case 'approuvee':
        return const Color(0xFF22C55E);
      case 'verifie':
        return const Color(0xFF14B8A6);
      case 'en_attente':
        return const Color(0xFFF59E0B);
      case 'annulee':
        return const Color(0xFF94A3B8);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  bool get isUpcoming => statut == 'approuvee' || statut == 'en_attente';
  bool get isPending => statut == 'en_attente';
  bool get isApproved => statut == 'approuvee';
  bool get isUsed => statut == 'verifie';
  bool get isRejected => statut == 'refusee';
  bool get isCancelled => statut == 'annulee';
  bool get isPaymentFailed => false;

  bool get canBeCancelled => isApproved || isPending;
  bool get canBeApproved => false; // No longer used with auto-approval
  bool get canBeRejected => false; // No longer used with auto-approval

  /// Check if booking can be cancelled
  /// Cancellation allowed any time before activity starts
  bool get canBeCancelledWithTime {
    if (!canBeCancelled) return false;

    final activityDate = activite?['date_debut'] ?? activite?['dateDebut'];
    if (activityDate == null) return false;

    final startDate = DateTime.tryParse(activityDate.toString());
    if (startDate == null) return false;

    final now = DateTime.now();
    final hoursBeforeStart = startDate.difference(now).inHours;

    // Cancellation allowed any time before activity starts
    return hoursBeforeStart > 0;
  }

  /// Get hours remaining until cancellation deadline
  int get hoursUntilCancellationDeadline {
    final activityDate = activite?['date_debut'] ?? activite?['dateDebut'];
    if (activityDate == null) return 0;

    final startDate = DateTime.tryParse(activityDate.toString());
    if (startDate == null) return 0;

    final now = DateTime.now();
    return startDate.difference(now).inHours;
  }

  String get qrData => 'DJTRIP_BOOKING:${qrToken ?? id}';

  ActivityModel? get activityModel {
    if (activite == null) return null;
    return ActivityModel.fromJson(activite!);
  }

  String? get organizerReason {
    final value = messageOrganisateur?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'statut': statut,
      'nombre_participants': nombreParticipants,
      'prix_total': prixTotal,
      'date_demande': dateDemande?.toIso8601String(),
      'message_touriste': messageTouriste,
      'message_organisateur': messageOrganisateur,
      'activite_id': activite,
      'touriste_id': touriste,
      'organisateur_id': organisateur,
      'qr_token': qrToken,
      'qr_token_generated_at': qrTokenGeneratedAt?.toIso8601String(),
      'qr_token_expires_at': qrTokenExpiresAt?.toIso8601String(),
      'qr_used_at': qrUsedAt?.toIso8601String(),
    };
  }
}
