const winston = require('winston');
const path = require('path');

// Define log format
const logFormat = winston.format.printf(({ level, message, timestamp, ...meta }) => {
  const metaStr = Object.keys(meta).length > 0 ? JSON.stringify(meta) : '';
  return JSON.stringify({
    timestamp,
    level,
    message,
    ...meta,
    service: 'djtrip-api',
    environment: process.env.NODE_ENV || 'development'
  });
});

// Create logger instance
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
    winston.format.errors({ stack: true }),
    logFormat
  ),
  defaultMeta: { service: 'djtrip-api' },
  transports: [
    // Write all logs with level 'error' and below to error.log
    new winston.transports.File({ 
      filename: path.join(__dirname, '../../logs/error.log'), 
      level: 'error' 
    }),
    // Write all logs to combined.log
    new winston.transports.File({ 
      filename: path.join(__dirname, '../../logs/combined.log') 
    })
  ]
});

// If we're not in production, log to the console as well
if (process.env.NODE_ENV !== 'production') {
  logger.add(new winston.transports.Console({
    format: winston.format.combine(
      winston.format.colorize(),
      winston.format.simple()
    )
  }));
}

/**
 * Middleware to add correlation ID to request
 */
const correlationMiddleware = (req, res, next) => {
  req.correlationId = req.headers['x-correlation-id'] || generateUUID();
  res.setHeader('x-correlation-id', req.correlationId);
  
  logger.info('Request started', {
    correlationId: req.correlationId,
    method: req.method,
    path: req.path,
    userId: req.user?.userId,
    ip: req.ip
  });
  
  const originalSend = res.send;
  res.send = function (data) {
    logger.info('Request completed', {
      correlationId: req.correlationId,
      statusCode: res.statusCode,
      responseTime: Date.now() - req.startTime
    });
    originalSend.call(this, data);
  };
  
  next();
};

/**
 * Generate UUID v4
 */
function generateUUID() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    const r = Math.random() * 16 | 0;
    const v = c === 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}

module.exports = logger;
module.exports.correlationMiddleware = correlationMiddleware;
module.exports.generateUUID = generateUUID;
