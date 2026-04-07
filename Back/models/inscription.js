const mongoose = require("mongoose");

// Schema for activity registrations
const inscriptionSchema = new mongoose.Schema(
  {
    // Reference to the tourist registering
    touriste_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Touriste",
      required: [true, "Tourist is required"],
    },
    // Reference to the activity
    activite_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Activite",
      required: [true, "Activity is required"],
    },
    // Reference to the organizer (to facilitate queries)
    organisateur_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Organisator",
      required: [true, "Organizer is required"],
    },
    // Registration status
    statut: {
      type: String,
      enum: ["en_attente", "approuvee", "refusee", "annulee", "verifie"],
      default: "en_attente",
    },
    // Number of participants (if the tourist registers multiple people)
    nombre_participants: {
      type: Number,
      default: 1,
      min: [1, "Minimum number of participants is 1"],
    },
    // Tourist's message (optional)
    message_touriste: {
      type: String,
      maxlength: 500,
    },
    // Organizer's message (optional - for rejection or confirmation)
    message_organisateur: {
      type: String,
      maxlength: 500,
    },
    // Date of the registration request
    date_demande: {
      type: Date,
      default: Date.now,
    },
    // Response date (approval or rejection)
    date_reponse: {
      type: Date,
    },
    // Total price at the time of registration
    prix_total: {
      type: Number,
      required: true,
    },
  },
  {
    timestamps: true,
  },
);

// Index to optimize searches
inscriptionSchema.index({ touriste_id: 1, statut: 1 });
inscriptionSchema.index({ activite_id: 1, statut: 1 });
inscriptionSchema.index({ organisateur_id: 1, statut: 1 });

// Method to approve a registration
inscriptionSchema.methods.approuver = function (messageOrganisateur) {
  this.statut = "approuvee";
  this.date_reponse = new Date();
  if (messageOrganisateur) {
    this.message_organisateur = messageOrganisateur;
  }
  return this.save();
};

// Method to reject a registration
inscriptionSchema.methods.refuser = function (messageOrganisateur) {
  this.statut = "refusee";
  this.date_reponse = new Date();
  if (messageOrganisateur) {
    this.message_organisateur = messageOrganisateur;
  }
  return this.save();
};

// Method to cancel a registration
inscriptionSchema.methods.annuler = function () {
  this.statut = "annulee";
  return this.save();
};

const Inscription = mongoose.model("Inscription", inscriptionSchema);

module.exports = Inscription;
