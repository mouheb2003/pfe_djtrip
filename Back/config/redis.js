const Redis = require('ioredis');

/**
 * Redis Configuration
 * Centralized Redis client configuration for caching, queues, and rate limiting
 */

// Create Redis client
const redisClient = new Redis({
  host: process.env.REDIS_HOST || 'localhost',
  port: process.env.REDIS_PORT || 6379,
  password: process.env.REDIS_PASSWORD || undefined,
  db: process.env.REDIS_DB || 0,
  maxRetriesPerRequest: 3,
  retryStrategy: (times) => {
    const delay = Math.min(times * 50, 2000);
    return delay;
  },
  enableReadyCheck: true,
  lazyConnect: true
});

// Redis connection events
redisClient.on('connect', () => {
  console.log('[Redis] Connected successfully');
});

redisClient.on('error', (error) => {
  console.error('[Redis] Connection error:', error.message);
});

redisClient.on('close', () => {
  console.warn('[Redis] Connection closed');
});

redisClient.on('reconnecting', () => {
  console.log('[Redis] Reconnecting...');
});

/**
 * Test Redis connection
 */
async function testConnection() {
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
    await redisClient.quit();
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
  testConnection,
  closeConnection
};
