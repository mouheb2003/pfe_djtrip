/**
 * Standardized API Response Helper
 * Ensures consistent response format across all endpoints
 */

const NODE_ENV = process.env.NODE_ENV || "development";

/**
 * Success response
 * @param {object} res - Express response object
 * @param {number} statusCode - HTTP status code
 * @param {string} message - Success message
 * @param {any} data - Response data
 * @param {object} meta - Pagination metadata
 */
exports.success = (
  res,
  statusCode = 200,
  message = "Success",
  data = null,
  meta = null,
) => {
  const response = {
    success: true,
    message,
  };

  if (data !== null) {
    response.data = data;
  }

  if (meta) {
    response.meta = meta;
  }

  return res.status(statusCode).json(response);
};

/**
 * Created response (201)
 */
exports.created = (
  res,
  message = "Resource created successfully",
  data = null,
) => {
  return exports.success(res, 201, message, data);
};

/**
 * OK response (200)
 */
exports.ok = (res, message = "Success", data = null) => {
  return exports.success(res, 200, message, data);
};

/**
 * Paginated response
 */
exports.paginated = (res, data, page, limit, total, message = "Success") => {
  const totalPages = Math.ceil(total / limit);
  const meta = {
    page: parseInt(page),
    limit: parseInt(limit),
    total: parseInt(total),
    totalPages,
    hasNextPage: page < totalPages,
    hasPrevPage: page > 1,
  };

  return exports.success(res, 200, message, data, meta);
};

/**
 * Error response
 * @param {object} res - Express response object
 * @param {number} statusCode - HTTP status code
 * @param {string} message - Error message
 * @param {any} errors - Additional error details
 */
exports.error = (
  res,
  statusCode = 500,
  message = "An error occurred",
  errors = null,
) => {
  const response = {
    success: false,
    message,
  };

  if (errors) {
    response.errors = errors;
  }

  // Include stack trace in development only
  if (NODE_ENV === "development") {
    response.stack = new Error().stack;
  }

  return res.status(statusCode).json(response);
};

/**
 * Bad request response (400)
 */
exports.badRequest = (res, message = "Bad request", errors = null) => {
  return exports.error(res, 400, message, errors);
};

/**
 * Unauthorized response (401)
 */
exports.unauthorized = (res, message = "Unauthorized access") => {
  return exports.error(res, 401, message);
};

/**
 * Forbidden response (403)
 */
exports.forbidden = (res, message = "Access forbidden") => {
  return exports.error(res, 403, message);
};

/**
 * Not found response (404)
 */
exports.notFound = (res, message = "Resource not found") => {
  return exports.error(res, 404, message);
};

/**
 * Conflict response (409)
 */
exports.conflict = (res, message = "Resource already exists") => {
  return exports.error(res, 409, message);
};

/**
 * Internal server error response (500)
 */
exports.serverError = (res, message = "Internal server error") => {
  return exports.error(res, 500, message);
};

/**
 * Service unavailable response (503)
 */
exports.serviceUnavailable = (
  res,
  message = "Service temporarily unavailable",
) => {
  return exports.error(res, 503, message);
};
