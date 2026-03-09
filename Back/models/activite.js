const mongoose = require("mongoose");

// Schéma pour les Activités touristiques
const activiteSchema = new mongoose.Schema(
  {
    // Titre de l'activité
    titre: {
      type: String,
      required: [true, "Le titre de l'activité est requis"],
      trim: true,
      maxlength: [100, "Le titre ne peut pas dépasser 100 caractères"],
    },
    // Description détaillée
    description: {
      type: String,
      required: [true, "La description est requise"],
      maxlength: [2000, "La description ne peut pas dépasser 2000 caractères"],
    },
    // Type d'activité
    type_activite: {
      type: String,
      required: [true, "Le type d'activité est requis"],
      enum: [
        "Visite guidée",
        "Excursion",
        "Randonnée",
        "Aventure",
        "Culture",
        "Gastronomie",
        "Sport",
        "Autre",
        // Legacy values for backward compatibility
        "Sports nautiques",
        "Escalade",
        "Vélo",
        "Visites culturelles",
        "Sports extrêmes",
        "Cours et ateliers",
        "Détente et bien-être",
        "Photographie",
        "Observation nature",
        "Sports d'hiver",
        "Activités nautiques",
        "Excursions",
        "Autres",
      ],
    },
    // Référence à l'organisateur
    organisateur_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Organisator",
      required: [true, "L'organisateur est requis"],
    },
    // Lieu de l'activité
    lieu: {
      type: String,
      required: [true, "Le lieu est requis"],
      trim: true,
    },
    // Coordonnées GPS (optionnel)
    coordonnees: {
      latitude: {
        type: Number,
        min: -90,
        max: 90,
      },
      longitude: {
        type: Number,
        min: -180,
        max: 180,
      },
    },
    // Durée de l'activité (en heures)
    duree: {
      type: Number,
      required: [true, "La durée est requise"],
      min: [0.1, "La durée minimale est de 0.1 heure (6 minutes)"],
    },
    // Prix par personne (en devise locale)
    prix: {
      type: Number,
      required: [true, "Le prix est requis"],
      min: [0, "Le prix ne peut pas être négatif"],
    },
    // Capacité maximale de participants
    capacite_max: {
      type: Number,
      required: [true, "La capacité maximale est requise"],
      min: [1, "La capacité minimale est de 1 personne"],
    },
    // Langues disponibles pour l'activité
    langues_disponibles: {
      type: [String],
      default: ["Français"],
    },
    // Photos de l'activité
    photos: {
      type: [String],
      default: [],
    },
    // Niveau de difficulté
    niveau_difficulte: {
      type: String,
      enum: ["Facile", "Modéré", "Difficile", "Expert"],
      default: "Facile",
    },
    // Équipements inclus
    equipements_inclus: {
      type: [String],
      default: [],
    },
    // Ce qu'il faut apporter
    a_apporter: {
      type: [String],
      default: [],
    },
    // Dates disponibles (tableau de dates)
    dates_disponibles: {
      type: [Date],
      default: [],
    },
    // Date et heure de début de l'activité
    date_debut: {
      type: Date,
      required: [true, "La date de début est requise"],
    },
    // Date et heure de fin de l'activité
    date_fin: {
      type: Date,
      required: [true, "La date de fin est requise"],
    },
    // Statut de l'activité
    statut: {
      type: String,
      enum: ["active", "inactive", "archivée", "terminée"],
      default: "active",
    },
    // Système d'évaluation
    note_moyenne: {
      type: Number,
      default: 0,
      min: 0,
      max: 5,
    },
    nombre_avis: {
      type: Number,
      default: 0,
    },
    // Nombre de réservations
    nombre_reservations: {
      type: Number,
      default: 0,
    },
  },
  {
    timestamps: true, // Ajoute automatiquement createdAt et updatedAt
  },
);

// Index pour améliorer les performances de recherche
activiteSchema.index({ type_activite: 1, statut: 1 });
activiteSchema.index({ organisateur_id: 1 });
activiteSchema.index({ lieu: "text", titre: "text" });

const Activite = mongoose.model("Activite", activiteSchema);

module.exports = Activite;
