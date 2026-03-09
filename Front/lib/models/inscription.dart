import 'activite.dart';
import 'touriste.dart';

class InscriptionTouristeInfo {
  final String id;
  final String fullname;
  final String email;
  final String? avatar;
  final String? numTel;
  final String? paysOrigine;
  final int? age;

  InscriptionTouristeInfo({
    required this.id,
    required this.fullname,
    required this.email,
    this.avatar,
    this.numTel,
    this.paysOrigine,
    this.age,
  });

  factory InscriptionTouristeInfo.fromJson(Map<String, dynamic> json) {
    return InscriptionTouristeInfo(
      id: json['_id'] ?? '',
      fullname: json['fullname'] ?? 'Touriste',
      email: json['email'] ?? '',
      avatar: json['avatar'],
      numTel: json['num_tel'],
      paysOrigine: json['pays_origine'],
      age: json['age'],
    );
  }
}

class InscriptionActiviteInfo {
  final String id;
  final String titre;
  final DateTime dateDebut;
  final DateTime dateFin;
  final String lieu;
  final double prix;
  final String description;
  final String typeActivite;
  final double duree;
  final List<String> photos;

  InscriptionActiviteInfo({
    required this.id,
    required this.titre,
    required this.dateDebut,
    required this.dateFin,
    required this.lieu,
    required this.prix,
    required this.description,
    required this.typeActivite,
    required this.duree,
    required this.photos,
  });

  factory InscriptionActiviteInfo.fromJson(Map<String, dynamic> json) {
    return InscriptionActiviteInfo(
      id: json['_id'] ?? '',
      titre: json['titre'] ?? '',
      dateDebut: json['date_debut'] != null
          ? DateTime.parse(json['date_debut'])
          : DateTime.now(),
      dateFin: json['date_fin'] != null
          ? DateTime.parse(json['date_fin'])
          : DateTime.now(),
      lieu: json['lieu'] ?? '',
      prix: (json['prix'] ?? 0).toDouble(),
      description: json['description'] ?? '',
      typeActivite: json['type_activite'] ?? 'Autre',
      duree: (json['duree'] ?? 0).toDouble(),
      photos: json['photos'] != null ? List<String>.from(json['photos']) : [],
    );
  }
}

class Inscription {
  final String id;
  final String touristeId;
  final String activiteId;
  final String organisateurId;
  final String statut; // en_attente, approuvee, refusee, annulee
  final int nombreParticipants;
  final String? messageTouriste;
  final String? messageOrganisateur;
  final DateTime dateDemande;
  final DateTime? dateReponse;
  final double prixTotal;
  final DateTime dateCreation;
  final DateTime dateModification;
  final InscriptionTouristeInfo? touriste;
  final InscriptionActiviteInfo? activite;

  Inscription({
    required this.id,
    required this.touristeId,
    required this.activiteId,
    required this.organisateurId,
    required this.statut,
    required this.nombreParticipants,
    this.messageTouriste,
    this.messageOrganisateur,
    required this.dateDemande,
    this.dateReponse,
    required this.prixTotal,
    required this.dateCreation,
    required this.dateModification,
    this.touriste,
    this.activite,
  });

  factory Inscription.fromJson(Map<String, dynamic> json) {
    // Parse touriste info
    InscriptionTouristeInfo? touristeInfo;
    String touristeId = '';
    if (json['touriste_id'] is String) {
      touristeId = json['touriste_id'];
    } else if (json['touriste_id'] is Map) {
      touristeId = json['touriste_id']['_id'] ?? '';
      try {
        touristeInfo = InscriptionTouristeInfo.fromJson(
          json['touriste_id'] as Map<String, dynamic>,
        );
      } catch (e) {
        print('Error parsing touriste info: $e');
      }
    }

    // Parse activite info
    InscriptionActiviteInfo? activiteInfo;
    String activiteId = '';
    if (json['activite_id'] is String) {
      activiteId = json['activite_id'];
    } else if (json['activite_id'] is Map) {
      activiteId = json['activite_id']['_id'] ?? '';
      try {
        activiteInfo = InscriptionActiviteInfo.fromJson(
          json['activite_id'] as Map<String, dynamic>,
        );
      } catch (e) {
        print('Error parsing activite info: $e');
      }
    }

    String organisateurId = '';
    if (json['organisateur_id'] is String) {
      organisateurId = json['organisateur_id'];
    } else if (json['organisateur_id'] is Map) {
      organisateurId = json['organisateur_id']['_id'] ?? '';
    }

    return Inscription(
      id: json['_id'] ?? '',
      touristeId: touristeId,
      activiteId: activiteId,
      organisateurId: organisateurId,
      statut: json['statut'] ?? 'en_attente',
      nombreParticipants: json['nombre_participants'] ?? 1,
      messageTouriste: json['message_touriste'],
      messageOrganisateur: json['message_organisateur'],
      dateDemande: DateTime.parse(
        json['date_demande'] ?? DateTime.now().toIso8601String(),
      ),
      dateReponse: json['date_reponse'] != null
          ? DateTime.parse(json['date_reponse'])
          : null,
      prixTotal: (json['prix_total'] ?? 0).toDouble(),
      dateCreation: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      dateModification: DateTime.parse(
        json['updatedAt'] ?? DateTime.now().toIso8601String(),
      ),
      touriste: touristeInfo,
      activite: activiteInfo,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'touriste_id': touristeId,
      'activite_id': activiteId,
      'organisateur_id': organisateurId,
      'statut': statut,
      'nombre_participants': nombreParticipants,
      'message_touriste': messageTouriste,
      'message_organisateur': messageOrganisateur,
      'date_demande': dateDemande.toIso8601String(),
      'date_reponse': dateReponse?.toIso8601String(),
      'prix_total': prixTotal,
      'createdAt': dateCreation.toIso8601String(),
      'updatedAt': dateModification.toIso8601String(),
    };
  }

  // Méthodes utiles
  bool get estEnAttente => statut == 'en_attente';
  bool get estApprouvee => statut == 'approuvee';
  bool get estRefusee => statut == 'refusee';
  bool get estAnnulee => statut == 'annulee';

  String get statutLibelle {
    switch (statut) {
      case 'en_attente':
        return 'En attente';
      case 'approuvee':
        return 'Approuvée';
      case 'refusee':
        return 'Refusée';
      case 'annulee':
        return 'Annulée';
      default:
        return statut;
    }
  }
}
