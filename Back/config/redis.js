const Redis = require('ioredis');

/**
 * Redis Configuration
 * Centralized Redis client configuration for caching, queues, and rate limiting
 */

const redisEnabled = (process.env.REDIS_ENABLED || 'true').toLowerCase() !== 'false';
const maxReconnectAttempts = Number(process.env.REDIS_MAX_RECONNECT_ATTEMPTS || 8);
let reconnectExhaustedLogged = false;
let lastRedisErrorMessage = '';

// Create Redis client
const redisClient = new Redis({
  host: process.env.REDIS_HOST || 'localhost',
  port: process.env.REDIS_PORT || 6379,
  password: process.env.REDIS_PASSWORD || undefined,
  db: process.env.REDIS_DB || 0,
  maxRetriesPerRequest: 3,
  retryStrategy: (times) => {
    if (!redisEnabled) {
      return null;
    }

    if (times > maxReconnectAttempts) {
      if (!reconnectExhaustedLogged) {
        reconnectExhaustedLogged = true;
        console.warn(`[Redis] Reconnect attempts exceeded (${maxReconnectAttempts}) - stopping retries`);
      }
      return null;
    }

    const delay = Math.min(times * 50, 2000);
    return delay;
  },
  enableReadyCheck: true,
  lazyConnect: true
});

// Redis connection events
redisClient.on('connect', () => {
  reconnectExhaustedLogged = false;
  console.log('[Redis] Connected successfully');
});

redisClient.on('error', (error) => {
  const message = error?.message || 'Unknown Redis error';

  // Avoid flooding logs with the same repeating error.
  if (message !== lastRedisErrorMessage) {
    lastRedisErrorMessage = message;
    console.error('[Redis] Connection error:', message);
  }
});

redisClient.on('close', () => {
  console.warn('[Redis] Connection closed');
});

redisClient.on('reconnecting', (ms) => {
  console.log(`[Redis] Reconnecting in ${ms}ms...`);
});

/**
 * Test Redis connection
 */
async function testConnection() {
  if (!redisEnabled) {
    console.warn('[Redis] Disabled via REDIS_ENABLED=false');
    return false;
  }

  try {
    await redisClient.ping();
    console.log('[Redis] Connection test successful');
    return true;
  } catch (error) {
    console.error('[Redis] Connection test failed:', error.message);
    return false;
  }
}

/**
 * Graceful shutdown
 */
async function closeConnection() {
  try {
    if (redisClient.status !== 'end') {
      await redisClient.quit();
    }
    console.log('[Redis] Connection closed gracefully');
  } catch (error) {
    console.error('[Redis] Error closing connection:', error.message);
  }
}

// Handle process termination
process.on('SIGINT', closeConnection);
process.on('SIGTERM', closeConnection);

module.exports = {
  redisClient,
  redisEnabled,
  testConnection,
  closeConnection
};
