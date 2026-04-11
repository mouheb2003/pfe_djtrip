const crypto = require('crypto');

// Redis client will be initialized when Redis is available
let redisClient = null;

/**
 * Initialize Redis client for idempotency
 */
function initRedis(client) {
  redisClient = client;
}

/**
 * Generate UUID v4 for idempotency keys
 */
function generateUUID() {
  return crypto.randomUUID();
}

/**
 * Idempotency middleware
 * Prevents duplicate requests by caching responses based on idempotency key
 */
const idempotency = async (req, res, next) => {
  const idempotencyKey = req.headers['x-idempotency-key'];
  
  // If no idempotency key, skip (optional idempotency)
  if (!idempotencyKey) {
    return next();
  }
  
  // Validate UUID v4 format
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  if (!uuidRegex.test(idempotencyKey)) {
    return res.status(400).json({
      success: false,
      error: 'Invalid idempotency key format. Must be UUID v4.'
    });
  }
  
  // If Redis not available, skip idempotency (graceful degradation)
  if (!redisClient) {
    console.warn('[Idempotency] Redis not available, skipping idempotency check');
    return next();
  }
  
  const cacheKey = `idempotency:${req.method}:${req.path}:${idempotencyKey}`;
  
  try {
    // Check if request was already processed
    const cached = await redisClient.get(cacheKey);
    
    if (cached) {
      const cachedResponse = JSON.parse(cached);
      console.log('[Idempotency] Returning cached response', { 
        cacheKey, 
        statusCode: cachedResponse.status 
      });
      
      return res.status(cachedResponse.status).json(cachedResponse.body);
    }
    
    // Intercept response to cache it
    const originalSend = res.send;
    const originalJson = res.json;
    
    res.json = function (body) {
      const responseToCache = {
        status: res.statusCode,
        body: typeof body === 'string' ? JSON.parse(body) : body
      };
      
      // Cache for 24 hours
      redisClient.setex(
        cacheKey,
        86400, // 24 hours
        JSON.stringify(responseToCache)
      ).catch(err => {
        console.error('[Idempotency] Failed to cache response:', err.message);
      });
      
      return originalJson.call(this, body);
    };
    
    res.send = function (body) {
      const responseToCache = {
        status: res.statusCode,
        body: typeof body === 'string' ? JSON.parse(body) : body
      };
      
      redisClient.setex(
        cacheKey,
        86400,
        JSON.stringify(responseToCache)
      ).catch(err => {
        console.error('[Idempotency] Failed to cache response:', err.message);
      });
      
      return originalSend.call(this, body);
    };
    
    next();
  } catch (error) {
    console.error('[Idempotency] Error:', error.message);
    // On error, proceed without idempotency (graceful degradation)
    next();
  }
};

/**
 * Clear idempotency cache for a specific key
 */
async function clearIdempotencyKey(method, path, idempotencyKey) {
  if (!redisClient) return false;
  
  const cacheKey = `idempotency:${method}:${path}:${idempotencyKey}`;
  try {
    await redisClient.del(cacheKey);
    return true;
  } catch (error) {
    console.error('[Idempotency] Failed to clear cache:', error.message);
    return false;
  }
}

/**
 * Clear all idempotency keys for a path
 */
async function clearPathIdempotency(method, path) {
  if (!redisClient) return false;
  
  try {
    const pattern = `idempotency:${method}:${path}:*`;
    const keys = await redisClient.keys(pattern);
    
    if (keys.length > 0) {
      await redisClient.del(keys);
    }
    
    return keys.length;
  } catch (error) {
    console.error('[Idempotency] Failed to clear path cache:', error.message);
    return false;
  }
}

module.exports = {
  idempotency,
  initRedis,
  generateUUID,
  clearIdempotencyKey,
  clearPathIdempotency
};
