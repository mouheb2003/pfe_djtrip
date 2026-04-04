import 'package:flutter/material.dart';
import 'dart:convert';

class InscriptionModel {
  final String id;
  final String statut; // en_attente | approuvee | refusee | annulee
  final int nombreParticipants;
  final double prixTotal;
  final DateTime? dateDemande;
  final String? messageTouriste;
  final Map<String, dynamic>? activite; // populated activite_id
  final Map<String, dynamic>? touriste; // populated touriste_id
  final Map<String, dynamic>? organisateur; // populated organisateur_id

  const InscriptionModel({
    required this.id,
    required this.statut,
    required this.nombreParticipants,
    required this.prixTotal,
    this.dateDemande,
    this.messageTouriste,
    this.activite,
    this.touriste,
    this.organisateur,
  });

  static Map<String, dynamic>? _safeMap(dynamic raw) {
    // If raw is already a Map, convert directly — NO JSON roundtrip.
    // A roundtrip through jsonDecode/jsonEncode crashes on emoji/special chars.
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      try {
        return raw.map((k, v) => MapEntry(k.toString(), v));
      } catch (_) {
        return null;
      }
    }

    // Only attempt JSON decoding if the value is a String (e.g. ObjectId reference).
    if (raw is String) {
      final text = raw.trim();
      if (text.isEmpty) return null;
      // If it doesn't look like JSON, treat it as an ObjectId string.
      if (!text.startsWith('{')) return {'_id': text};
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) {
          return decoded.map((k, v) => MapEntry(k.toString(), v));
        }
      } catch (_) {
        // Not valid JSON — treat as plain ObjectId string.
        return {'_id': text};
      }
    }

    return null;
  }

  factory InscriptionModel.fromJson(Map<String, dynamic> json) {
    return InscriptionModel(
      id: json['_id'] as String? ?? '',
      statut: json['statut'] as String? ?? 'en_attente',
      nombreParticipants: (json['nombre_participants'] as num? ?? 1).toInt(),
      prixTotal: (json['prix_total'] as num? ?? 0).toDouble(),
      dateDemande: json['date_demande'] != null
          ? DateTime.tryParse(json['date_demande'])
          : null,
      messageTouriste: json['message_touriste'] as String?,
      activite: _safeMap(json['activite_id']),
      touriste: _safeMap(json['touriste_id']),
      organisateur: _safeMap(json['organisateur_id']),
    );
  }

  String get statusLabel {
    switch (statut) {
      case 'approuvee':
        return 'Approved';
      case 'en_attente':
        return 'Pending';
      case 'refusee':
        return 'Rejected';
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
      case 'en_attente':
        return const Color(0xFFF59E0B);
      case 'refusee':
        return const Color(0xFFEF4444);
      case 'annulee':
        return const Color(0xFF94A3B8);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  bool get isUpcoming => statut == 'approuvee' || statut == 'en_attente';

  bool get isPending => statut == 'en_attente';
  bool get isApproved => statut == 'approuvee';
  bool get isRejected => statut == 'refusee';
  bool get isCancelled => statut == 'annulee';

  bool get canBeCancelled => isPending || isApproved;
  bool get canBeApproved => isPending;
  bool get canBeRejected => isPending;

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'statut': statut,
      'nombre_participants': nombreParticipants,
      'prix_total': prixTotal,
      'date_demande': dateDemande?.toIso8601String(),
      'message_touriste': messageTouriste,
      'activite_id': activite,
      'touriste_id': touriste,
      'organisateur_id': organisateur,
    };
  }
}
