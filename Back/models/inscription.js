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
    // Signed QR token issued when the booking is approved
    qr_token: {
      type: String,
    },
    // When the QR token was generated
    qr_token_generated_at: {
      type: Date,
    },
    // When the QR token expires (usually around activity end time)
    qr_token_expires_at: {
      type: Date,
    },
    // When the booking was checked in / marked as used
    qr_used_at: {
      type: Date,
    },
    // Review tracking
    hasReviewed: {
      type: Boolean,
      default: false,
    },
    reviewDate: {
      type: Date,
    },
    // Review reminder system
    reviewReminder: {
      remindAt: {
        type: Date,
      },
      reminderCount: {
        type: Number,
        default: 0,
      },
      lastReminder: {
        type: Date,
      },
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
inscriptionSchema.index({ qr_token: 1 }, { sparse: true });

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

// Method to mark a booking as used after check-in
inscriptionSchema.methods.marquerCommeUtilise = function () {
  this.statut = "verifie";
  this.qr_used_at = new Date();
  return this.save();
};

// Method to mark as reviewed
inscriptionSchema.methods.marquerCommeReviewed = function () {
  this.hasReviewed = true;
  this.reviewDate = new Date();
  return this.save();
};

// Method to set review reminder
inscriptionSchema.methods.setReviewReminder = function (remindAt) {
  this.reviewReminder = {
    remindAt: remindAt,
    reminderCount: (this.reviewReminder?.reminderCount || 0) + 1,
    lastReminder: new Date(),
  };
  return this.save();
};

// Method to check if review reminder should be shown
inscriptionSchema.methods.shouldShowReviewReminder = function () {
  if (this.hasReviewed) return false;
  if (this.statut !== "approuvee") return false;
  if (!this.qr_used_at) return false; // Not checked in
  
  const now = new Date();
  const activityEnd = this.qr_token_expires_at;
  if (!activityEnd) return false;
  
  // Check if within 7 days of activity end
  const deadline = new Date(activityEnd.getTime() + 7 * 24 * 60 * 60 * 1000);
  if (now > deadline) return false;
  
  // Check reminder timing
  if (this.reviewReminder?.remindAt) {
    return now >= this.reviewReminder.remindAt && this.reviewReminder.reminderCount < 3;
  }
  
  return true;
};

const Inscription = mongoose.model("Inscription", inscriptionSchema);

module.exports = Inscription;
