const Joi = require('joi');

/**
 * Booking Validators
 * Strict Joi validation schemas for booking-related endpoints
 */

// Create booking schema
const createBookingSchema = Joi.object({
  activite_id: Joi.string()
    .pattern(/^[0-9a-fA-F]{24}$/)
    .required()
    .messages({
      'string.pattern.base': 'Invalid activity ID format',
      'any.required': 'Activity ID is required'
    }),
  nombre_participants: Joi.number()
    .integer()
    .min(1)
    .max(50)
    .required()
    .messages({
      'number.min': 'Minimum 1 participant',
      'number.max': 'Maximum 50 participants',
      'any.required': 'Number of participants is required'
    }),
  message_touriste: Joi.string()
    .max(500)
    .allow('')
    .optional()
    .messages({
      'string.max': 'Message cannot exceed 500 characters'
    })
});

// Approve booking schema
const approveBookingSchema = Joi.object({
  message_organisateur: Joi.string()
    .max(500)
    .allow('')
    .optional()
    .messages({
      'string.max': 'Message cannot exceed 500 characters'
    })
});

// Reject booking schema
const rejectBookingSchema = Joi.object({
  message_organisateur: Joi.string()
    .max(500)
    .allow('')
    .optional()
    .messages({
      'string.max': 'Message cannot exceed 500 characters'
    })
});

// Cancel booking schema
const cancelBookingSchema = Joi.object({
  reason: Joi.string()
    .max(500)
    .required()
    .messages({
      'string.max': 'Reason cannot exceed 500 characters',
      'any.required': 'Cancellation reason is required'
    })
});

// Validate QR schema
const validateQrSchema = Joi.object({
  qrData: Joi.string()
    .required()
    .messages({
      'any.required': 'QR data is required'
    })
});

// Verify booking schema
const verifyBookingSchema = Joi.object({
  deviceId: Joi.string()
    .optional(),
  location: Joi.object({
    latitude: Joi.number()
      .min(-90)
      .max(90)
      .required(),
    longitude: Joi.number()
      .min(-180)
      .max(180)
      .required()
  }).optional()
});

/**
 * Validation middleware factory
 */
const validate = (schema) => {
  return (req, res, next) => {
    const { error, value } = schema.validate(req.body, {
      abortEarly: false, // Return all errors
      stripUnknown: true // Remove unknown fields
    });
    
    if (error) {
      const errors = error.details.map(detail => ({
        field: detail.path.join('.'),
        message: detail.message
      }));
      
      return res.status(400).json({
        success: false,
        error: 'Validation failed',
        details: errors
      });
    }
    
    req.body = value; // Use sanitized values
    next();
  };
};

/**
 * Query parameter validation
 */
const validateQuery = (schema) => {
  return (req, res, next) => {
    const { error, value } = schema.validate(req.query, {
      abortEarly: false,
      stripUnknown: true
    });
    
    if (error) {
      const errors = error.details.map(detail => ({
        field: detail.path.join('.'),
        message: detail.message
      }));
      
      return res.status(400).json({
        success: false,
        error: 'Query validation failed',
        details: errors
      });
    }
    
    req.query = value;
    next();
  };
};

// Query schemas
const bookingListQuerySchema = Joi.object({
  page: Joi.number().integer().min(1).default(1),
  limit: Joi.number().integer().min(1).max(100).default(20),
  statut: Joi.string().valid('en_attente', 'approuvee', 'refusee', 'annulee', 'verifie').optional(),
  startDate: Joi.date().iso().optional(),
  endDate: Joi.date().iso().optional()
});

module.exports = {
  createBookingSchema,
  approveBookingSchema,
  rejectBookingSchema,
  cancelBookingSchema,
  validateQrSchema,
  verifyBookingSchema,
  bookingListQuerySchema,
  validate,
  validateQuery
};
