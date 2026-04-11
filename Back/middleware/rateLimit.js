const rateLimit = require("express-rate-limit");
const { redisClient } = require("../config/redis");

// Check if Redis is available for distributed rate limiting
// Disabled for development as Redis may not be installed locally
const useRedis = false; // Set to true when Redis is available in production

// Auth limiter - strict for login/signup
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // Max 5 attempts per 15 minutes
  message: { message: "Too many authentication attempts. Please try again in 15 minutes." },
  standardHeaders: true,
  legacyHeaders: false,
  store: useRedis ? new RedisStore({
    client: redisClient,
    prefix: "auth_limit:"
  }) : undefined,
});

// General API limiter
const apiLimiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 minute
  max: 100, // Max 100 requests per minute
  message: { message: "Too many requests. Please try again later." },
  standardHeaders: true,
  legacyHeaders: false,
  store: useRedis ? new RedisStore({
    client: redisClient,
    prefix: "api_limit:"
  }) : undefined,
});

// CRITICAL: Booking creation limiter - prevent spam bookings
const bookingLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 10, // Max 10 bookings per hour per user
  message: { message: "Too many booking attempts. Please try again later." },
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => req.user?.userId || req.ip,
  store: useRedis ? new RedisStore({
    client: redisClient,
    prefix: "booking_limit:"
  }) : undefined,
});

// CRITICAL: Booking approval limiter - prevent abuse
const approvalLimiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 minute
  max: 30, // Max 30 approvals per minute
  message: { message: "Too many approval attempts. Please slow down." },
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => req.user?.userId || req.ip,
  store: useRedis ? new RedisStore({
    client: redisClient,
    prefix: "approval_limit:"
  }) : undefined,
});

// CRITICAL: Check-in limiter - prevent fraud
const checkinLimiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 minute
  max: 20, // Max 20 check-ins per minute
  message: { message: "Too many check-in attempts. Please try again later." },
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => req.user?.userId || req.ip,
  store: useRedis ? new RedisStore({
    client: redisClient,
    prefix: "checkin_limit:"
  }) : undefined,
});

// Cancellation limiter
const cancellationLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 5, // Max 5 cancellations per hour
  message: { message: "Too many cancellation attempts. Please contact support." },
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => req.user?.userId || req.ip,
  store: useRedis ? new RedisStore({
    client: redisClient,
    prefix: "cancellation_limit:"
  }) : undefined,
});

// Activity creation limiter
const activityCreationLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 5, // Max 5 activities per hour
  message: { message: "Too many activity creation attempts. Please try again later." },
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => req.user?.userId || req.ip,
  store: useRedis ? new RedisStore({
    client: redisClient,
    prefix: "activity_limit:"
  }) : undefined,
});

// Review submission limiter
const reviewLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 10, // Max 10 reviews per hour
  message: { message: "Too many review attempts. Please try again later." },
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => req.user?.userId || req.ip,
  store: useRedis ? new RedisStore({
    client: redisClient,
    prefix: "review_limit:"
  }) : undefined,
});

module.exports = {
  authLimiter,
  apiLimiter,
  bookingLimiter,
  approvalLimiter,
  checkinLimiter,
  cancellationLimiter,
  activityCreationLimiter,
  reviewLimiter,
};
