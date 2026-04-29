const Joi = require("joi");

const createLieuSchema = Joi.object({
  // ================= IDENTITÉ =================
  name: Joi.string().required(),
  slug: Joi.string(),
  type: Joi.string()
    .valid("beach", "hotel", "restaurant", "activity", "landmark")
    .required(),

  // ================= LOCALISATION =================
  address: Joi.string(),
  city: Joi.string(),
  country: Joi.string(),
  zipcode: Joi.string(),
  coordinates: Joi.object({
    latitude: Joi.number().min(-90).max(90),
    longitude: Joi.number().min(-180).max(180),
  }),

  // ================= MEDIA =================
  main_image: Joi.string().uri(),
  gallery: Joi.array().items(Joi.string().uri()),
  video: Joi.string().uri(),

  // ================= DESCRIPTIONS =================
  short_description: Joi.string(),
  long_description: Joi.string(),
  experience_description: Joi.string(),
  heritage_history: Joi.string(),
  highlights: Joi.array().items(Joi.string()),
  experience_highlights: Joi.array().items(Joi.string()),
  history: Joi.string(),

  // ================= SERVICES =================
  amenities: Joi.array().items(Joi.string()),
  activities: Joi.array().items(Joi.string()),
  languages_spoken: Joi.array().items(Joi.string()),
  wheelchair_access: Joi.boolean(),

  // ================= HORAIRES =================
  opening_hours: Joi.string(),
  closing_hours: Joi.string(),
  seasonal: Joi.string(),
  booking_required: Joi.boolean(),

  // ================= PRIX =================
  price_range: Joi.string(),
  price_per_adult: Joi.number().min(0),
  min_price: Joi.number().min(0),
  max_price: Joi.number().min(0),
  currency: Joi.string().default("TND"),
  discounts: Joi.string(),
  booking_link: Joi.string().uri(),
  website: Joi.string().uri(),

  // ================= AVIS =================
  rating: Joi.number().min(0).max(5).default(0),
  review_count: Joi.number().min(0).default(0),
  reviews: Joi.array().items(Joi.object({
    user: Joi.string().required(),
    comment: Joi.string(),
    rating: Joi.number().min(0).max(5).required(),
    date: Joi.date(),
  })),

  // ================= VISIBILITÉ =================
  popularity_score: Joi.number().min(0).default(0),
  is_featured: Joi.boolean().default(false),
  tags: Joi.array().items(Joi.string()),
});

const updateLieuSchema = Joi.object({
  // ================= IDENTITÉ =================
  name: Joi.string(),
  slug: Joi.string(),
  type: Joi.string().valid("beach", "hotel", "restaurant", "activity", "landmark"),

  // ================= LOCALISATION =================
  address: Joi.string(),
  city: Joi.string(),
  country: Joi.string(),
  zipcode: Joi.string(),
  coordinates: Joi.object({
    latitude: Joi.number().min(-90).max(90),
    longitude: Joi.number().min(-180).max(180),
  }),

  // ================= MEDIA =================
  main_image: Joi.string().uri(),
  gallery: Joi.array().items(Joi.string().uri()),
  video: Joi.string().uri(),

  // ================= DESCRIPTIONS =================
  short_description: Joi.string(),
  long_description: Joi.string(),
  experience_description: Joi.string(),
  heritage_history: Joi.string(),
  highlights: Joi.array().items(Joi.string()),
  experience_highlights: Joi.array().items(Joi.string()),
  history: Joi.string(),

  // ================= SERVICES =================
  amenities: Joi.array().items(Joi.string()),
  activities: Joi.array().items(Joi.string()),
  languages_spoken: Joi.array().items(Joi.string()),
  wheelchair_access: Joi.boolean(),

  // ================= HORAIRES =================
  opening_hours: Joi.string(),
  closing_hours: Joi.string(),
  seasonal: Joi.string(),
  booking_required: Joi.boolean(),

  // ================= PRIX =================
  price_range: Joi.string(),
  price_per_adult: Joi.number().min(0),
  min_price: Joi.number().min(0),
  max_price: Joi.number().min(0),
  currency: Joi.string(),
  discounts: Joi.string(),
  booking_link: Joi.string().uri(),
  website: Joi.string().uri(),

  // ================= AVIS =================
  rating: Joi.number().min(0).max(5),
  review_count: Joi.number().min(0),
  reviews: Joi.array().items(Joi.object({
    user: Joi.string().required(),
    comment: Joi.string(),
    rating: Joi.number().min(0).max(5).required(),
    date: Joi.date(),
  })),

  // ================= VISIBILITÉ =================
  popularity_score: Joi.number().min(0),
  is_featured: Joi.boolean(),
  tags: Joi.array().items(Joi.string()),
});

const reviewSchema = Joi.object({
  rating: Joi.number().min(1).max(5).required(),
  comment: Joi.string().max(500),
});

module.exports = {
  createLieuSchema,
  updateLieuSchema,
  reviewSchema,
};
