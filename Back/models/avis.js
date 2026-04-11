const mongoose = require("mongoose");

const avisSchema = new mongoose.Schema(
  {
    // Tourist who submitted this review/rating
    touriste_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Touriste",
      required: true,
    },
    // Activity reference (for activity reviews)
    activite_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Activite",
      default: null,
    },
    // Organizer reference (for organizer ratings)
    organisateur_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Organisator",
      default: null,
    },
    // Type of review: activity review or organizer rating
    type: {
      type: String,
      enum: ["activite", "organisateur"],
      required: true,
    },
    // Star rating 1-5
    note: {
      type: Number,
      required: true,
      min: [1, "Note minimum is 1"],
      max: [5, "Note maximum is 5"],
    },
    // Optional text comment
    commentaire: {
      type: String,
      maxlength: [1000, "Comment cannot exceed 1000 characters"],
      default: null,
    },
    // Optional tags (max 3)
    tags: {
      type: [String],
      default: [],
      validate: {
        validator: function(tags) {
          return tags.length <= 3;
        },
        message: "Maximum 3 tags allowed",
      },
    },
    // Link to the inscription that qualifies the tourist to review
    inscription_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Inscription",
    },
  },
  {
    timestamps: true,
  },
);

// One review per tourist per activity
avisSchema.index(
  { touriste_id: 1, activite_id: 1 },
  {
    unique: true,
    partialFilterExpression: {
      type: "activite",
      activite_id: { $ne: null },
    },
  },
);

// One rating per tourist per organizer
avisSchema.index(
  { touriste_id: 1, organisateur_id: 1 },
  {
    unique: true,
    partialFilterExpression: {
      type: "organisateur",
      organisateur_id: { $ne: null },
    },
  },
);

avisSchema.index({ activite_id: 1, type: 1 });
avisSchema.index({ organisateur_id: 1, type: 1 });

const Avis = mongoose.model("Avis", avisSchema);

module.exports = Avis;
