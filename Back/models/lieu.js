const mongoose = require("mongoose");

const lieuSchema = new mongoose.Schema(
  {
    // ================= IDENTITÉ =================
    name: {
      type: String,
      required: true,
    },
    slug: {
      type: String,
      unique: true,
    },
    type: {
      type: String,
      enum: ["beach", "hotel", "restaurant", "activity", "landmark"],
      required: true,
    },

    // ================= LOCALISATION =================
    address: String,
    city: String,
    country: String,
    zipcode: String,

    coordinates: {
      latitude: Number,
      longitude: Number,
    },

    telephone: String,

    // ================= MEDIA =================
    main_image: String,
    gallery: [String],
    video: String,

    // ================= DESCRIPTIONS =================
    short_description: String,
    long_description: String,
    experience_description: String,
    heritage_history: String,
    highlights: [String],
    experience_highlights: [String],
    history: String,

    // ================= SERVICES =================
    amenities: [String],
    activities: [String],
    languages_spoken: [String],
    wheelchair_access: {
      type: Boolean,
      default: false,
    },

    // ================= HORAIRES =================
    opening_hours: String,
    closing_hours: String,
    seasonal: String,
    booking_required: {
      type: Boolean,
      default: false,
    },

    // ================= PRIX =================
    price_range: String,
    price_per_adult: Number,
    min_price: Number,
    max_price: Number,
    currency: {
      type: String,
      default: "TND",
    },
    discounts: String,
    booking_link: String,
    website: String,

    // ================= AVIS =================
    rating: {
      type: Number,
      default: 0,
    },
    review_count: {
      type: Number,
      default: 0,
    },
    reviews: [
      {
        user: String,
        comment: String,
        rating: Number,
        date: {
          type: Date,
          default: Date.now,
        },
      },
    ],

    // ================= VISIBILITÉ =================
    popularity_score: {
      type: Number,
      default: 0,
    },
    is_featured: {
      type: Boolean,
      default: false,
    },
    tags: [String],
  },
  {
    timestamps: true, // createdAt / updatedAt
  }
);

module.exports = mongoose.model("Lieu", lieuSchema);

// Configuration Schema for storing API keys
const configSchema = new mongoose.Schema(
  {
    key: {
      type: String,
      required: true,
      unique: true,
    },
    value: {
      type: String,
      required: true,
    },
    description: String,
  },
  {
    timestamps: true,
  }
);

module.exports.Config = mongoose.model("Config", configSchema);
