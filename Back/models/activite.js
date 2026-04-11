const mongoose = require("mongoose");

// Schema for tourist Activities
const activiteSchema = new mongoose.Schema(
  {
    // Activity title
    titre: {
      type: String,
      required: [true, "Activity title is required"],
      trim: true,
      maxlength: [100, "Title cannot exceed 100 characters"],
    },
    // Detailed description
    description: {
      type: String,
      required: [true, "Description is required"],
      maxlength: [2000, "Description cannot exceed 2000 characters"],
    },
    // Activity type
    type_activite: {
      type: String,
      required: [true, "Activity type is required"],
      enum: [
        "Guided Tour",
        "Excursion",
        "Hiking",
        "Adventure",
        "Culture",
        "Gastronomy",
        "Sport",
        "Other",
        // Legacy values for backward compatibility
        "Water Sports",
        "Climbing",
        "Cycling",
        "Cultural Visits",
        "Extreme Sports",
        "Courses and Workshops",
        "Relaxation and Wellness",
        "Photography",
        "Nature Observation",
        "Winter Sports",
        "Water Activities",
        "Excursions",
        "Others",
      ],
    },
    // Activity category used by home/explore filters
    categorie: {
      type: String,
      trim: true,
      default: "Other",
    },
    // Reference to the organizer
    organisateur_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Organisator",
      required: [true, "Organizer is required"],
    },
    // Activity location
    lieu: {
      type: String,
      required: [true, "Location is required"],
      trim: true,
    },
    // GPS coordinates (optional)
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
    // Activity duration (in hours)
    duree: {
      type: Number,
      required: [true, "Duration is required"],
      min: [0.1, "Minimum duration is 0.1 hour (6 minutes)"],
    },
    // Price per person (in local currency)
    prix: {
      type: Number,
      required: [true, "Price is required"],
      min: [0, "Price cannot be negative"],
    },
    // Maximum participant capacity
    capacite_max: {
      type: Number,
      required: [true, "Maximum capacity is required"],
      min: [1, "Minimum capacity is 1 person"],
    },
    // Languages available for the activity
    langues_disponibles: {
      type: [String],
      default: ["English"],
    },
    // Activity photos
    photos: {
      type: [String],
      default: [],
    },
    // Difficulty level
    niveau_difficulte: {
      type: String,
      enum: ["Easy", "Moderate", "Difficult", "Expert"],
      default: "Easy",
    },
    // Included equipment
    equipements_inclus: {
      type: [String],
      default: [],
    },
    // What to bring
    a_apporter: {
      type: [String],
      default: [],
    },
    // Available dates (array of dates)
    dates_disponibles: {
      type: [Date],
      default: [],
    },
    // Activity start date and time
    date_debut: {
      type: Date,
      required: [true, "Start date is required"],
    },
    // Activity end date and time
    date_fin: {
      type: Date,
      required: [true, "End date is required"],
    },
    // Activity status
    statut: {
      type: String,
      enum: ["active", "inactive", "archived", "completed"],
      default: "active",
    },
    // Rating system
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
    // Number of bookings
    nombre_reservations: {
      type: Number,
      default: 0,
    },
  },
  {
    timestamps: true, // Automatically adds createdAt and updatedAt
  },
);

// Indexes to improve search performance
activiteSchema.index({ type_activite: 1, statut: 1 });
activiteSchema.index({ categorie: 1, statut: 1 });
activiteSchema.index({ organisateur_id: 1 });
activiteSchema.index({ lieu: "text", titre: "text", description: "text" });
// Geospatial index for proximity queries (e.g. activities near a location)
activiteSchema.index({ "coordonnees.latitude": 1, "coordonnees.longitude": 1 });

const Activite = mongoose.model("Activite", activiteSchema);

module.exports = Activite;
