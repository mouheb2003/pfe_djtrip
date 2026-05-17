// ✅ ADDED
const NODE_ENV = process.env.NODE_ENV || "development";

function toSafeMessage(error) {
  if (!error) return "Internal server error";

  if (error.name === "JsonWebTokenError") return "Invalid authentication token";
  if (error.name === "TokenExpiredError") return "Authentication token expired";
  if (error.name === "ValidationError") return "Validation failed";
  if (error.name === "MongoServerError" && error.code === 11000) {
    const field = Object.keys(error.keyPattern || {})[0] || "field";
    return `This ${field} is already in use. Please try another one.`;
  }
  if (error.name === "CastError") return `Invalid ${error.path}: ${error.value}`;

  return error.message || "Internal server error";
}

function notFoundHandler(req, res) {
  return res.status(404).json({
    success: false,
    message: "Route not found",
  });
}

function globalErrorHandler(error, req, res, next) {
  if (res.headersSent) return next(error);

  const statusCode = Number(error.status || error.statusCode || 500);
  const payload = {
    success: false,
    message: toSafeMessage(error),
  };

  if (NODE_ENV !== "production" && error && error.message) {
    payload.error = error.message;
  }

  return res.status(statusCode).json(payload);
}

module.exports = {
  notFoundHandler,
  globalErrorHandler,
};
