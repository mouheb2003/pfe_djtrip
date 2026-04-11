const { Worker } = require('bullmq');
const { redisClient } = require('../config/redis');
const notificationService = require('../services/notificationService');
const logger = require('../utils/logger');

/**
 * Notification Worker
 * Processes FCM push notification jobs asynchronously with retry logic
 */

const notificationWorker = new Worker('notifications', async (job) => {
  const { type, data } = job.data;
  
  logger.info('Processing notification job', { jobId: job.id, type });
  
  try {
    switch (type) {
      case 'booking-created':
        await notificationService.notifyOrganizerNewBooking(
          data.organizerId, 
          data.bookingId
        );
        break;
        
      case 'booking-approved':
        await notificationService.notifyTouristApproved(data.bookingId);
        break;
        
      case 'booking-rejected':
        await notificationService.notifyTouristRejected(data.bookingId);
        break;
        
      case 'booking-cancelled':
        await notificationService.notifyOrganizerCancelled(
          data.organizerId,
          data.bookingId
        );
        break;
        
      case 'checkin-confirmed':
        await notificationService.notifyTouristCheckIn(data.bookingId);
        break;
        
      case 'activity-reminder':
        await notificationService.sendActivityReminder(data.bookingId);
        break;
        
      case 'review-reminder':
        await notificationService.sendReviewReminder(data.bookingId);
        break;
        
      case 'no-show-detected':
        await notificationService.notifyOrganizerNoShow(
          data.organizerId,
          data.bookingId
        );
        break;
        
      default:
        throw new Error(`Unknown notification type: ${type}`);
    }
    
    logger.info('Notification sent successfully', { jobId: job.id, type });
    return { success: true };
  } catch (error) {
    logger.error('Notification job failed', { jobId: job.id, type, error: error.message });
    throw error; // BullMQ will retry
  }
}, {
  connection: redisClient,
  concurrency: 10, // Process 10 notifications concurrently
  limiter: {
    max: 500, // Max 500 notifications per minute
    duration: 60000
  }
});

// Worker event listeners
notificationWorker.on('completed', (job) => {
  logger.info('Notification worker completed job', { jobId: job.id });
});

notificationWorker.on('failed', (job, err) => {
  logger.error('Notification worker failed job', { 
    jobId: job?.id, 
    error: err.message,
    attemptsMade: job?.attemptsMade
  });
});

notificationWorker.on('error', (err) => {
  logger.error('Notification worker error:', err.message);
});

// Graceful shutdown
async function closeWorker() {
  await notificationWorker.close();
  logger.info('Notification worker closed');
}

process.on('SIGINT', closeWorker);
process.on('SIGTERM', closeWorker);

module.exports = notificationWorker;
