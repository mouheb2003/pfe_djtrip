const mongoose = require("mongoose");

const lieuSchema = new mongoose.Schema(
  {
    titre: {
      type: String,
      required: true,
    },
    sousTitre: {
      type: String,
      required: true,
    },
    description: {
      type: String,
      required: true,
    },
    imagePortrait: {
      type: String,
      required: true,
    },
    imagePaysage: {
      type: String,
    },
    images: [
      {
        type: String,
      },
    ],
    noteMoyenne: {
      type: Number,
      default: 0,
    },
    nombreAvis: {
      type: Number,
      default: 0,
    },
    categorie: {
      type: String,
      enum: ["Beaches", "Museums", "Villages", "Nature", "Other"],
      required: true,
    },
    topDestination: {
      type: Boolean,
      default: false,
    },
    meilleurePeriode: {
      type: String,
    },
    dureeVisite: {
      type: String,
    },
    prix: {
      type: String, // e.g. "FREE" or "15 TND"
      default: "FREE",
    },
    coordonnees: {
      latitude: Number,
      longitude: Number,
    },
    tags: [
      {
        type: String, // e.g. "Street Art", "Architecture", "Guided Tours"
      },
    ],
    activiteLiee: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Activite",
    },
  },
  { timestamps: true },
);

module.exports = mongoose.model("Lieu", lieuSchema);
