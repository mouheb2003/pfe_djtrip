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
    // GPS coordinates (conditional based on location_type)
    coordonnees: {
      latitude: {
        type: Number,
        min: -90,
        max: 90,
        validate: {
          validator: function (value) {
            // Required for fixed location
            if (
              this.location_type === "fixed" &&
              (value === undefined || value === null)
            ) {
              return false;
            }
            return true;
          },
          message: "Coordinates are required for fixed location",
        },
      },
      longitude: {
        type: Number,
        min: -180,
        max: 180,
        validate: {
          validator: function (value) {
            // Required for fixed location
            if (
              this.location_type === "fixed" &&
              (value === undefined || value === null)
            ) {
              return false;
            }
            return true;
          },
          message: "Coordinates are required for fixed location",
        },
      },
    },
    // Location type - fixed, custom, or itinerary
    location_type: {
      type: String,
      enum: ["fixed", "custom", "itinerary"],
      default: "fixed",
    },
    // NEW: Itinerary items (array of structured objects)
    itineraire: {
      type: [
        {
          title: {
            type: String,
            trim: true,
            maxlength: [100, "Title cannot exceed 100 characters"],
          },
          description: {
            type: String,
            trim: true,
            maxlength: [500, "Description cannot exceed 500 characters"],
          },
          address: {
            type: String,
            trim: true,
          },
          lat: {
            type: Number,
            min: -90,
            max: 90,
          },
          lng: {
            type: Number,
            min: -180,
            max: 180,
          },
          // Optional: order of the item in the itinerary
          order: {
            type: Number,
            default: 0,
          },
        },
      ],
      default: [],
      validate: {
        validator: function (value) {
          // For itinerary type, allow empty array during transitions but warn
          // Validation of non-empty itinerary should be done at API level (frontend validation)
          if (
            this.location_type === "itinerary" &&
            (!value || value.length === 0)
          ) {
            console.warn(
              "⚠️ Itinerary type with empty items - this may be a type transition state",
            );
            // Allow it - frontend should validate
            return true;
          }
          return true;
        },
        message:
          "Itinerary type should have at least one item (frontend validation will catch this)",
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
    // Bookmark functionality
    bookmarked_by: {
      type: [
        {
          type: mongoose.Schema.Types.ObjectId,
          ref: "User",
          index: true,
        },
      ],
      default: [],
    },
    bookmarks_count: {
      type: Number,
      default: 0,
      min: 0,
    },
  },
  {
    timestamps: true, // Automatically adds createdAt and updatedAt
  },
);

// PRE-SAVE VALIDATION AND DATA CLEANING
activiteSchema.pre("save", async function () {
  const locationType = this.location_type;

  // Clean data based on location type
  switch (locationType) {
    case "fixed":
      // Fixed location: require coordinates, remove itinerary
      if (
        !this.coordonnees ||
        this.coordonnees.latitude === undefined ||
        this.coordonnees.longitude === undefined
      ) {
        throw new Error("Coordinates are required for fixed location");
      }
      // Remove itinerary data for fixed locations
      this.itineraire = [];
      break;

    case "custom":
      // Custom location: only lieu required, remove itinerary and coordinates
      // Remove coordinates for custom locations (optional)
      if (this.coordonnees) {
        this.coordonnees = undefined;
      }
      // Remove itinerary data for custom locations
      this.itineraire = [];
      break;

    case "itinerary":
      // Itinerary: require at least one item, remove single coordinates
      if (!this.itineraire || this.itineraire.length === 0) {
        throw new Error(
          "At least one itinerary item is required for itinerary type",
        );
      }
      // Remove single coordinates for itinerary locations
      if (this.coordonnees) {
        this.coordonnees = undefined;
      }
      // Generate composite lieu from itinerary items
      if (this.itineraire && this.itineraire.length > 0) {
        const addresses = this.itineraire
          .map((item) => item.address)
          .filter((addr) => addr);
        if (addresses.length > 0) {
          this.lieu = `Multi-location tour: ${addresses.join(" to ")}`;
        }
      }
      break;

    default:
      throw new Error("Invalid location type");
  }
});

// PRE-UPDATE VALIDATION AND DATA CLEANING
activiteSchema.pre(
  ["updateOne", "updateMany", "findOneAndUpdate"],
  function () {
    const update = this.getUpdate();
    const locationType = update.$set?.location_type || update.location_type;

    if (locationType) {
      switch (locationType) {
        case "fixed":
          // Remove itinerary data for fixed locations
          if (update.$set) {
            update.$set.itineraire = [];
          } else {
            update.itineraire = [];
          }
          break;

        case "custom":
          // Remove itinerary and coordinates for custom locations
          if (update.$set) {
            update.$set.itineraire = [];
            update.$set.coordonnees = undefined;
          } else {
            update.itineraire = [];
            update.coordonnees = undefined;
          }
          break;

        case "itinerary":
          // Remove single coordinates for itinerary locations
          if (update.$set) {
            update.$set.coordonnees = undefined;
          } else {
            update.coordonnees = undefined;
          }
          break;
      }
    }
  },
);

// Indexes to improve search performance
activiteSchema.index({ organisateur_id: 1 });
activiteSchema.index({ lieu: "text", titre: "text", description: "text" });

// Geospatial index for proximity queries (only for fixed locations)
activiteSchema.index({ "coordonnees.latitude": 1, "coordonnees.longitude": 1 });

// Index for itinerary locations
activiteSchema.index({ "itineraire.lat": 1, "itineraire.lng": 1 });

const Activite = mongoose.model("Activite", activiteSchema);

module.exports = Activite;
