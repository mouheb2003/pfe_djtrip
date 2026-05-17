const Joi = require("joi");

const ACTIVITY_TYPES = [
  "Guided Tour",
  "Excursion",
  "Hiking",
  "Adventure",
  "Culture",
  "Gastronomy",
  "Sport",
  "Other",
  // Legacy values
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
];

const DIFFICULTY_LEVELS = ["Easy", "Moderate", "Difficult", "Expert"];

// Schema for creating an activity (all required fields must be provided)
const createActiviteSchema = Joi.object({
  titre: Joi.string().max(100).required().messages({
    "any.required": "Title is required",
    "string.max": "Title cannot exceed 100 characters",
  }),
  description: Joi.string().max(2000).required().messages({
    "any.required": "Description is required",
  }),
  type_activite: Joi.string()
    .valid(...ACTIVITY_TYPES)
    .optional(),
  typeActivite: Joi.string()
    .valid(...ACTIVITY_TYPES)
    .optional(),
  lieu: Joi.string().required().messages({
    "any.required": "Location is required",
  }),
  location_type: Joi.string()
    .valid(...["fixed", "custom", "itinerary"])
    .optional(),
  locationType: Joi.string()
    .valid(...["fixed", "custom", "itinerary"])
    .optional(),
  itineraire: Joi.alternatives()
    .try(Joi.string(), Joi.array().items(Joi.object().unknown(true)))
    .optional(),
  itineraire_coords: Joi.alternatives()
    .try(Joi.string(), Joi.array().items(Joi.object().unknown(true)))
    .optional(),
  itineraireCoords: Joi.alternatives()
    .try(Joi.string(), Joi.array().items(Joi.object().unknown(true)))
    .optional(),
  duree: Joi.number().min(0.1).required().messages({
    "any.required": "Duration is required",
    "number.min": "Minimum duration is 0.1 hours",
  }),
  prix: Joi.number().min(0).required().messages({
    "any.required": "Price is required",
    "number.min": "Price cannot be negative",
  }),
  capacite_max: Joi.number().integer().min(1).optional(),
  capaciteMax: Joi.number().integer().min(1).optional(),
  date_debut: Joi.alternatives()
    .try(Joi.date().iso(), Joi.string())
    .required()
    .messages({
      "any.required": "Start date is required",
    }),
  dateDebut: Joi.alternatives().try(Joi.date().iso(), Joi.string()).optional(),
  date_fin: Joi.alternatives().try(Joi.date().iso(), Joi.string()).optional(),
  dateFin: Joi.alternatives().try(Joi.date().iso(), Joi.string()).optional(),
  niveau_difficulte: Joi.string()
    .valid(...DIFFICULTY_LEVELS)
    .optional(),
  langues_disponibles: Joi.alternatives()
    .try(Joi.array().items(Joi.string()), Joi.string())
    .optional(),
  equipements_inclus: Joi.alternatives()
    .try(Joi.array().items(Joi.string()), Joi.string())
    .optional(),
  a_apporter: Joi.alternatives()
    .try(Joi.array().items(Joi.string()), Joi.string())
    .optional(),
  dates_disponibles: Joi.alternatives()
    .try(Joi.array(), Joi.string())
    .optional(),
  coordonnees: Joi.alternatives()
    .try(
      Joi.object({
        latitude: Joi.number().min(-90).max(90),
        longitude: Joi.number().min(-180).max(180),
      }),
      Joi.string(),
    )
    .optional(),
  statut: Joi.string()
    .valid("active", "inactive", "archived", "completed", "cancelled")
    .optional(),
  keepExistingPhotos: Joi.alternatives()
    .try(Joi.boolean(), Joi.string())
    .optional(),
  ai_generated_image_url: Joi.string().optional(),
  aiGeneratedImageUrl: Joi.string().optional(),
})
  .or("type_activite", "typeActivite")
  .or("capacite_max", "capaciteMax");

// Schema for updating (all fields optional but validated if present)
const updateActiviteSchema = Joi.object({
  titre: Joi.string().max(100).optional(),
  description: Joi.string().max(2000).optional(),
  type_activite: Joi.string()
    .valid(...ACTIVITY_TYPES)
    .optional(),
  typeActivite: Joi.string()
    .valid(...ACTIVITY_TYPES)
    .optional(),
  lieu: Joi.string().optional(),
  location_type: Joi.string()
    .valid(...["fixed", "custom", "itinerary"])
    .optional(),
  locationType: Joi.string()
    .valid(...["fixed", "custom", "itinerary"])
    .optional(),
  itineraire: Joi.alternatives()
    .try(Joi.string(), Joi.array().items(Joi.object().unknown(true)))
    .optional(),
  itineraire_coords: Joi.alternatives()
    .try(Joi.string(), Joi.array().items(Joi.object().unknown(true)))
    .optional(),
  itineraireCoords: Joi.alternatives()
    .try(Joi.string(), Joi.array().items(Joi.object().unknown(true)))
    .optional(),
  duree: Joi.number().min(0.1).optional(),
  prix: Joi.number().min(0).optional(),
  capacite_max: Joi.number().integer().min(1).optional(),
  capaciteMax: Joi.number().integer().min(1).optional(),
  date_debut: Joi.alternatives().try(Joi.date().iso(), Joi.string()).optional(),
  dateDebut: Joi.alternatives().try(Joi.date().iso(), Joi.string()).optional(),
  date_fin: Joi.alternatives().try(Joi.date().iso(), Joi.string()).optional(),
  dateFin: Joi.alternatives().try(Joi.date().iso(), Joi.string()).optional(),
  niveau_difficulte: Joi.string()
    .valid(...DIFFICULTY_LEVELS)
    .optional(),
  langues_disponibles: Joi.alternatives()
    .try(Joi.array().items(Joi.string()), Joi.string())
    .optional(),
  equipements_inclus: Joi.alternatives()
    .try(Joi.array().items(Joi.string()), Joi.string())
    .optional(),
  a_apporter: Joi.alternatives()
    .try(Joi.array().items(Joi.string()), Joi.string())
    .optional(),
  dates_disponibles: Joi.alternatives()
    .try(Joi.array(), Joi.string())
    .optional(),
  coordonnees: Joi.alternatives()
    .try(
      Joi.object({
        latitude: Joi.number().min(-90).max(90),
        longitude: Joi.number().min(-180).max(180),
      }),
      Joi.string(),
    )
    .optional(),
  statut: Joi.string()
    .valid("active", "inactive", "archived", "completed", "cancelled")
    .optional(),
  keepExistingPhotos: Joi.alternatives()
    .try(Joi.boolean(), Joi.string())
    .optional(),
  ai_generated_image_url: Joi.string().optional(),
  aiGeneratedImageUrl: Joi.string().optional(),
  existing_photo_urls: Joi.alternatives()
    .try(Joi.array().items(Joi.string()), Joi.string())
    .optional(),
  existingPhotoUrls: Joi.alternatives()
    .try(Joi.array().items(Joi.string()), Joi.string())
    .optional(),
});

module.exports = { createActiviteSchema, updateActiviteSchema };
