const mongoose = require("mongoose");

// Schéma pour les inscriptions aux activités
const inscriptionSchema = new mongoose.Schema(
  {
    // Référence au touriste qui s'inscrit
    touriste_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Touriste",
      required: [true, "Le touriste est requis"],
    },
    // Référence à l'activité
    activite_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Activite",
      required: [true, "L'activité est requise"],
    },
    // Référence à l'organisateur (pour faciliter les requêtes)
    organisateur_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Organisator",
      required: [true, "L'organisateur est requis"],
    },
    // Statut de l'inscription
    statut: {
      type: String,
      enum: ["en_attente", "approuvee", "refusee", "annulee"],
      default: "en_attente",
    },
    // Nombre de participants (si le touriste inscrit plusieurs personnes)
    nombre_participants: {
      type: Number,
      default: 1,
      min: [1, "Le nombre minimum de participants est 1"],
    },
    // Message du touriste (optionnel)
    message_touriste: {
      type: String,
      maxlength: 500,
    },
    // Message de l'organisateur (optionnel - pour refus ou confirmation)
    message_organisateur: {
      type: String,
      maxlength: 500,
    },
    // Date de la demande
    date_demande: {
      type: Date,
      default: Date.now,
    },
    // Date de réponse (approbation ou refus)
    date_reponse: {
      type: Date,
    },
    // Prix total au moment de l'inscription
    prix_total: {
      type: Number,
      required: true,
    },
  },
  {
    timestamps: true,
  },
);

// Index pour optimiser les recherches
inscriptionSchema.index({ touriste_id: 1, statut: 1 });
inscriptionSchema.index({ activite_id: 1, statut: 1 });
inscriptionSchema.index({ organisateur_id: 1, statut: 1 });

// Méthode pour approuver une inscription
inscriptionSchema.methods.approuver = function (messageOrganisateur) {
  this.statut = "approuvee";
  this.date_reponse = new Date();
  if (messageOrganisateur) {
    this.message_organisateur = messageOrganisateur;
  }
  return this.save();
};

// Méthode pour refuser une inscription
inscriptionSchema.methods.refuser = function (messageOrganisateur) {
  this.statut = "refusee";
  this.date_reponse = new Date();
  if (messageOrganisateur) {
    this.message_organisateur = messageOrganisateur;
  }
  return this.save();
};

// Méthode pour annuler une inscription
inscriptionSchema.methods.annuler = function () {
  this.statut = "annulee";
  return this.save();
};

const Inscription = mongoose.model("Inscription", inscriptionSchema);

module.exports = Inscription;
