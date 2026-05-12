const Joi = require("joi");

/**
 * Activity Validators
 * Strict Joi validation schemas for activity-related endpoints
 */

// Create activity schema
const createActivitySchema = Joi.object({
  titre: Joi.string().trim().min(3).max(100).required().messages({
    "string.min": "Title must be at least 3 characters",
    "string.max": "Title cannot exceed 100 characters",
    "any.required": "Title is required",
  }),
  description: Joi.string().trim().min(10).max(2000).required().messages({
    "string.min": "Description must be at least 10 characters",
    "string.max": "Description cannot exceed 2000 characters",
    "any.required": "Description is required",
  }),
  type_activite: Joi.string()
    .valid(
      "Guided Tour",
      "Excursion",
      "Hiking",
      "Adventure",
      "Culture",
      "Gastronomy",
      "Sport",
      "Other",
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
    )
    .required()
    .messages({
      "any.required": "Activity type is required",
      "any.only": "Invalid activity type",
    }),
  categorie: Joi.string().trim().max(50).optional().default("Other"),
  location_type: Joi.string().valid("fixed", "custom", "itinerary").optional(),
  locationType: Joi.string().valid("fixed", "custom", "itinerary").optional(),
  lieu: Joi.string().trim().min(2).max(100).required().messages({
    "string.min": "Location must be at least 2 characters",
    "string.max": "Location cannot exceed 100 characters",
    "any.required": "Location is required",
  }),
  coordonnees: Joi.object({
    latitude: Joi.number().min(-90).max(90).optional(),
    longitude: Joi.number().min(-180).max(180).optional(),
  }).optional(),
  itineraire: Joi.alternatives()
    .try(Joi.string(), Joi.array().items(Joi.object().unknown(true)))
    .optional(),
  itineraire_coords: Joi.alternatives()
    .try(Joi.string(), Joi.array().items(Joi.object().unknown(true)))
    .optional(),
  itineraireCoords: Joi.alternatives()
    .try(Joi.string(), Joi.array().items(Joi.object().unknown(true)))
    .optional(),
  duree: Joi.number().min(0.1).max(24).required().messages({
    "number.min": "Duration must be at least 0.1 hour",
    "number.max": "Duration cannot exceed 24 hours",
    "any.required": "Duration is required",
  }),
  prix: Joi.number().min(0).max(10000).required().messages({
    "number.min": "Price cannot be negative",
    "number.max": "Price cannot exceed 10000",
    "any.required": "Price is required",
  }),
  capacite_max: Joi.number().integer().min(1).max(500).required().messages({
    "number.min": "Capacity must be at least 1",
    "number.max": "Capacity cannot exceed 500",
    "any.required": "Capacity is required",
  }),
  langues_disponibles: Joi.array()
    .items(Joi.string())
    .min(1)
    .max(10)
    .default(["English"])
    .optional(),
  niveau_difficulte: Joi.string()
    .valid("Easy", "Moderate", "Difficult", "Expert")
    .default("Easy")
    .optional(),
  equipements_inclus: Joi.array().items(Joi.string()).max(20).optional(),
  a_apporter: Joi.array().items(Joi.string()).max(20).optional(),
  dates_disponibles: Joi.array().items(Joi.date().iso()).optional(),
  date_debut: Joi.date().iso().required().messages({
    "any.required": "Start date is required",
  }),
  date_fin: Joi.date()
    .iso()
    .greater(Joi.ref("date_debut"))
    .required()
    .messages({
      "date.greater": "End date must be after start date",
      "any.required": "End date is required",
    }),
});

// Update activity schema
const updateActivitySchema = Joi.object({
  titre: Joi.string().trim().min(3).max(100).optional(),
  description: Joi.string().trim().min(10).max(2000).optional(),
  type_activite: Joi.string()
    .valid(
      "Guided Tour",
      "Excursion",
      "Hiking",
      "Adventure",
      "Culture",
      "Gastronomy",
      "Sport",
      "Other",
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
    )
    .optional(),
  categorie: Joi.string().trim().max(50).optional(),
  location_type: Joi.string().valid("fixed", "custom", "itinerary").optional(),
  locationType: Joi.string().valid("fixed", "custom", "itinerary").optional(),
  lieu: Joi.string().trim().min(2).max(100).optional(),
  coordonnees: Joi.object({
    latitude: Joi.number().min(-90).max(90).optional(),
    longitude: Joi.number().min(-180).max(180).optional(),
  }).optional(),
  itineraire: Joi.alternatives()
    .try(Joi.string(), Joi.array().items(Joi.object().unknown(true)))
    .optional(),
  itineraire_coords: Joi.alternatives()
    .try(Joi.string(), Joi.array().items(Joi.object().unknown(true)))
    .optional(),
  itineraireCoords: Joi.alternatives()
    .try(Joi.string(), Joi.array().items(Joi.object().unknown(true)))
    .optional(),
  duree: Joi.number().min(0.1).max(24).optional(),
  prix: Joi.number().min(0).max(10000).optional(),
  capacite_max: Joi.number().integer().min(1).max(500).optional(),
  langues_disponibles: Joi.array()
    .items(Joi.string())
    .min(1)
    .max(10)
    .optional(),
  niveau_difficulte: Joi.string()
    .valid("Easy", "Moderate", "Difficult", "Expert")
    .optional(),
  equipements_inclus: Joi.array().items(Joi.string()).max(20).optional(),
  a_apporter: Joi.array().items(Joi.string()).max(20).optional(),
  dates_disponibles: Joi.array().items(Joi.date().iso()).optional(),
  date_debut: Joi.date().iso().optional(),
  date_fin: Joi.date().iso().optional(),
  statut: Joi.string()
    .valid("active", "inactive", "archived", "completed")
    .optional(),
}).min(1); // At least one field must be updated

// Query schemas
const activityListQuerySchema = Joi.object({
  page: Joi.number().integer().min(1).default(1),
  limit: Joi.number().integer().min(1).max(100).default(20),
  type_activite: Joi.string().optional(),
  categorie: Joi.string().optional(),
  niveau_difficulte: Joi.string()
    .valid("Easy", "Moderate", "Difficult", "Expert")
    .optional(),
  statut: Joi.string()
    .valid("active", "inactive", "archived", "completed")
    .optional(),
  minPrice: Joi.number().min(0).optional(),
  maxPrice: Joi.number().min(0).optional(),
  startDate: Joi.date().iso().optional(),
  endDate: Joi.date().iso().optional(),
  search: Joi.string().max(100).optional(),
});

const validate = (schema) => {
  return (req, res, next) => {
    const { error, value } = schema.validate(req.body, {
      abortEarly: false,
      stripUnknown: true,
    });

    if (error) {
      const errors = error.details.map((detail) => ({
        field: detail.path.join("."),
        message: detail.message,
      }));

      return res.status(400).json({
        success: false,
        error: "Validation failed",
        details: errors,
      });
    }

    req.body = value;
    next();
  };
};

const validateQuery = (schema) => {
  return (req, res, next) => {
    const { error, value } = schema.validate(req.query, {
      abortEarly: false,
      stripUnknown: true,
    });

    if (error) {
      const errors = error.details.map((detail) => ({
        field: detail.path.join("."),
        message: detail.message,
      }));

      return res.status(400).json({
        success: false,
        error: "Query validation failed",
        details: errors,
      });
    }

    req.query = value;
    next();
  };
};

module.exports = {
  createActivitySchema,
  updateActivitySchema,
  activityListQuerySchema,
  validate,
  validateQuery,
};
