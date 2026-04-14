const { Queue, Worker, QueueScheduler } = require('bullmq');
const { redisClient } = require('./redis');

/**
 * BullMQ Configuration for Notification System
 * Production-ready queue setup with Redis backend
 * Fallback mode available if Redis is not connected
 */

// Check if Redis is available
let redisAvailable = false;
let notificationQueue = null;
let notificationWorker = null;

try {
  redisClient.on('connect', () => {
    console.log('✅ Redis connected - Queue system enabled');
    redisAvailable = true;
  });

  redisClient.on('error', (err) => {
    console.warn('⚠️ Redis connection error - Queue system disabled, using fallback mode');
    redisAvailable = false;
  });

  // Test connection
  redisClient.ping((err) => {
    if (err) {
      console.warn('⚠️ Redis not available - Queue system disabled, using fallback mode');
      redisAvailable = false;
    } else {
      console.log('✅ Redis available - Queue system enabled');
      redisAvailable = true;
    }
  });
} catch (error) {
  console.warn('⚠️ Redis initialization failed - Queue system disabled, using fallback mode');
  redisAvailable = false;
}

// Queue options
const queueOptions = {
  connection: redisClient,
  defaultJobOptions: {
    attempts: 3,
    backoff: {
      type: 'exponential',
      delay: 2000,
    },
    removeOnComplete: {
      count: 1000,
      age: 3600, // 1 hour
    },
    removeOnFail: {
      count: 5000,
      age: 24 * 3600, // 24 hours
    },
  },
};

// Initialize queue only if Redis is available
if (redisAvailable) {
  try {
    notificationQueue = new Queue('notifications', queueOptions);
  } catch (error) {
    console.warn('⚠️ Failed to create queue - using fallback mode');
    redisAvailable = false;
  }
}

// Initialize worker only if Redis is available
if (redisAvailable && notificationQueue) {
  try {
    notificationWorker = new Worker(
      'notifications',
      async (job) => {
        const { type, payload } = job.data;
        
        // Import notification service dynamically to avoid circular dependencies
        const notificationService = require('../services/notificationServiceV2');
        
        switch (type) {
          case 'single':
            return await notificationService.sendPushNotification(payload);
          
          case 'bulk':
            return await notificationService.sendBulkNotification(payload);
          
          case 'batch':
            return await notificationService.sendBatchNotification(payload);
          
          default:
            throw new Error(`Unknown notification job type: ${type}`);
        }
      },
      {
        connection: redisClient,
        concurrency: 5, // Process 5 jobs concurrently
        limiter: {
          max: 100, // Max 100 jobs per 10 seconds
          duration: 10000,
        },
      }
    );

    // Worker event handlers
    notificationWorker.on('completed', (job) => {
      console.log(`✅ Notification job completed: ${job.id}`);
    });

    notificationWorker.on('failed', (job, err) => {
      console.error(`❌ Notification job failed: ${job.id}`, err.message);
    });

    notificationWorker.on('error', (err) => {
      console.error('❌ Worker error:', err);
    });
  } catch (error) {
    console.warn('⚠️ Failed to create worker - using fallback mode');
    redisAvailable = false;
  }
}

// Queue Scheduler for delayed jobs (only if Redis available)
let queueScheduler = null;
if (redisAvailable) {
  try {
    queueScheduler = new QueueScheduler('notifications', {
      connection: redisClient,
    });
  } catch (error) {
    console.warn('⚠️ Failed to create queue scheduler - delayed jobs disabled');
  }
}

/**
 * Add notification job to queue
 * Falls back to direct send if Redis is not available
 * @param {Object} jobData - Job data
 * @param {string} jobData.type - Job type (single, bulk, batch)
 * @param {Object} jobData.payload - Notification payload
 * @param {Object} options - Job options (delay, priority, etc.)
 */
async function addNotificationJob(jobData, options = {}) {
  // Fallback mode: send directly if Redis is not available
  if (!redisAvailable || !notificationQueue) {
    console.warn('⚠️ Redis not available - sending notification directly (fallback mode)');
    const notificationService = require('../services/notificationServiceV2');
    
    try {
      const { type, payload } = jobData;
      switch (type) {
        case 'single':
          return await notificationService.sendPushNotification(payload);
        case 'bulk':
          return await notificationService.sendBulkNotification(payload);
        case 'batch':
          return await notificationService.sendBatchNotification(payload);
        default:
          throw new Error(`Unknown notification job type: ${type}`);
      }
    } catch (error) {
      console.error('❌ Fallback notification send failed:', error);
      throw error;
    }
  }

  // Queue mode: add job to queue
  try {
    const job = await notificationQueue.add(jobData.type, jobData, {
      ...options,
      priority: options.priority || 'normal',
    });
    
    console.log(`📝 Notification job added: ${job.id}`);
    return job;
  } catch (error) {
    console.error('Error adding notification job:', error);
    throw error;
  }
}

/**
 * Get queue statistics
 */
async function getQueueStats() {
  if (!redisAvailable || !notificationQueue) {
    return {
      waiting: 0,
      active: 0,
      completed: 0,
      failed: 0,
      delayed: 0,
      mode: 'fallback (no Redis)',
    };
  }

  const waiting = await notificationQueue.getWaiting();
  const active = await notificationQueue.getActive();
  const completed = await notificationQueue.getCompleted();
  const failed = await notificationQueue.getFailed();
  const delayed = await notificationQueue.getDelayed();
  
  return {
    waiting: waiting.length,
    active: active.length,
    completed: completed.length,
    failed: failed.length,
    delayed: delayed.length,
    mode: 'queue (Redis)',
  };
}

/**
 * Clean up old jobs
 */
async function cleanQueue() {
  if (!redisAvailable || !notificationQueue) {
    console.log('⚠️ Queue not available - skipping cleanup');
    return;
  }
  
  await notificationQueue.clean(24 * 3600 * 1000, 5000); // Clean jobs older than 24h
  console.log('🧹 Queue cleaned');
}

/**
 * Graceful shutdown
 */
async function closeQueues() {
  if (notificationWorker) {
    await notificationWorker.close();
    console.log('✅ Notification worker closed');
  }
  
  if (queueScheduler) {
    await queueScheduler.close();
    console.log('✅ Queue scheduler closed');
  }
  
  if (notificationQueue) {
    await notificationQueue.close();
    console.log('✅ Notification queue closed');
  }
  
  if (redisClient) {
    await redisClient.quit();
    console.log('✅ Redis connection closed');
  }
  
  console.log('🔒 BullMQ shutdown complete');
}

process.on('SIGINT', closeQueues);
process.on('SIGTERM', closeQueues);

module.exports = {
  notificationQueue,
  notificationWorker,
  addNotificationJob,
  getQueueStats,
  cleanQueue,
  closeQueues,
};
