const mongoose = require("mongoose");
const User = require("./user");

// Schéma spécifique pour Organisator
const organisatorSchema = new mongoose.Schema({
  nom_entreprise: {
    type: String,
    required: true,
  },
  numero_licence: {
    type: String,
  },
  adresse_entreprise: {
    type: String,
  },
  site_web: {
    type: String,
  },
  specialites: {
    type: [String],
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
  certifications: {
    type: [String],
    default: [],
  },
});

// Utilisation du discriminator pour hériter de User
const Organisator = User.discriminator("Organisator", organisatorSchema);

module.exports = Organisator;
