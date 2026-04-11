const { Queue } = require('bullmq');
const { redisClient } = require('../config/redis');
const logger = require('../utils/logger');

/**
 * BullMQ Queue Configuration
 * Centralized queue setup for async job processing
 */

// Email Queue
const emailQueue = new Queue('emails', {
  connection: redisClient,
  defaultJobOptions: {
    attempts: 3,
    backoff: {
      type: 'exponential',
      delay: 2000
    },
    removeOnComplete: {
      count: 1000,
      age: 24 * 3600 // 24 hours
    },
    removeOnFail: {
      count: 5000,
      age: 7 * 24 * 3600 // 7 days
    }
  }
});

// Notification Queue (FCM push notifications)
const notificationQueue = new Queue('notifications', {
  connection: redisClient,
  defaultJobOptions: {
    attempts: 3,
    backoff: {
      type: 'exponential',
      delay: 2000
    },
    removeOnComplete: {
      count: 1000,
      age: 24 * 3600
    },
    removeOnFail: {
      count: 5000,
      age: 7 * 24 * 3600
    }
  }
});

// Refund Queue (payment refunds)
const refundQueue = new Queue('refunds', {
  connection: redisClient,
  defaultJobOptions: {
    attempts: 5,
    backoff: {
      type: 'exponential',
      delay: 5000
    },
    removeOnComplete: {
      count: 500,
      age: 30 * 24 * 3600 // 30 days
    },
    removeOnFail: {
      count: 1000,
      age: 90 * 24 * 3600 // 90 days
    }
  }
});

// No-Show Queue (delayed no-show detection)
const noShowQueue = new Queue('no-show', {
  connection: redisClient,
  defaultJobOptions: {
    attempts: 3,
    backoff: {
      type: 'exponential',
      delay: 10000
    },
    removeOnComplete: {
      count: 1000,
      age: 7 * 24 * 3600
    },
    removeOnFail: {
      count: 1000,
      age: 30 * 24 * 3600
    }
  }
});

// Activity Reminder Queue
const reminderQueue = new Queue('reminders', {
  connection: redisClient,
  defaultJobOptions: {
    attempts: 3,
    backoff: {
      type: 'exponential',
      delay: 3000
    },
    removeOnComplete: {
      count: 1000,
      age: 7 * 24 * 3600
    },
    removeOnFail: {
      count: 500,
      age: 30 * 24 * 3600
    }
  }
});

// Queue event listeners
const setupQueueListeners = (queue, queueName) => {
  queue.on('waiting', (job) => {
    logger.debug(`[${queueName}] Job waiting`, { jobId: job.id });
  });
  
  queue.on('active', (job) => {
    logger.info(`[${queueName}] Job started`, { jobId: job.id, name: job.name });
  });
  
  queue.on('completed', (job) => {
    logger.info(`[${queueName}] Job completed`, { jobId: job.id, name: job.name });
  });
  
  queue.on('failed', (job, err) => {
    logger.error(`[${queueName}] Job failed`, { 
      jobId: job?.id, 
      name: job?.name, 
      error: err.message 
    });
  });
  
  queue.on('stalled', (job) => {
    logger.warn(`[${queueName}] Job stalled`, { jobId: job.id, name: job.name });
  });
};

// Setup listeners for all queues
setupQueueListeners(emailQueue, 'Email');
setupQueueListeners(notificationQueue, 'Notification');
setupQueueListeners(refundQueue, 'Refund');
setupQueueListeners(noShowQueue, 'No-Show');
setupQueueListeners(reminderQueue, 'Reminder');

/**
 * Graceful shutdown for queues
 */
async function closeQueues() {
  try {
    await Promise.all([
      emailQueue.close(),
      notificationQueue.close(),
      refundQueue.close(),
      noShowQueue.close(),
      reminderQueue.close()
    ]);
    logger.info('All queues closed successfully');
  } catch (error) {
    logger.error('Error closing queues:', error.message);
  }
}

// Handle process termination
process.on('SIGINT', closeQueues);
process.on('SIGTERM', closeQueues);

module.exports = {
  emailQueue,
  notificationQueue,
  refundQueue,
  noShowQueue,
  reminderQueue,
  closeQueues
};
