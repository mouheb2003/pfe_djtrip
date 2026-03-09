const mongoose = require("mongoose");
const User = require("./user");

// Schéma spécifique pour Organisator (Organisateur d'activités simple)
const organisatorSchema = new mongoose.Schema({
  // Lien vers l'utilisateur de base (héritage)
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "User",
  },
  // Types d'activités proposées (ex: "Sports nautiques", "Randonnée", "Visites culturelles", etc.)
  types_activites: {
    type: [String],
    default: [],
    enum: [
      "Sports nautiques",
      "Randonnée",
      "Escalade",
      "Vélo",
      "Visites culturelles",
      "Gastronomie",
      "Aventure",
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
  // Liste des activités créées par cet organisateur (références aux IDs des activités)
  liste_activites: {
    type: [mongoose.Schema.Types.ObjectId],
    ref: "Activite",
    default: [],
  },
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
  // Langues parlées pour les activités
  langues_proposees: {
    type: [String],
    default: [],
  },
  // Description de l'organisateur et de ses services
  description: {
    type: String,
    maxlength: 1000,
  },
});

// Utilisation du discriminator pour hériter de User
const Organisator = User.discriminator("Organisator", organisatorSchema);

module.exports = Organisator;
