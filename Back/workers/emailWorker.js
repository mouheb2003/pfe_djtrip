const { Worker } = require('bullmq');
const { redisClient } = require('../config/redis');
const emailService = require('../services/email');
const logger = require('../utils/logger');

/**
 * Email Worker
 * Processes email jobs asynchronously with retry logic
 */

const emailWorker = new Worker('emails', async (job) => {
  const { type, data } = job.data;
  
  logger.info('Processing email job', { jobId: job.id, type });
  
  try {
    switch (type) {
      case 'booking-confirmation':
        await emailService.sendBookingConfirmationEmail(data);
        break;
        
      case 'booking-approved':
        await emailService.sendBookingApprovedEmail(data);
        break;
        
      case 'booking-rejected':
        await emailService.sendBookingRejectedEmail(data);
        break;
        
      case 'booking-cancelled':
        await emailService.sendBookingCancelledEmail(data);
        break;
        
      case 'checkin-confirmed':
        await emailService.sendCheckInConfirmationEmail(data);
        break;
        
      case 'activity-reminder':
        await emailService.sendActivityReminderEmail(data);
        break;
        
      case 'review-reminder':
        await emailService.sendReviewReminderEmail(data);
        break;
        
      case 'password-reset':
        await emailService.sendPasswordResetEmail(data);
        break;
        
      case 'email-verification':
        await emailService.sendEmailVerification(data);
        break;
        
      default:
        throw new Error(`Unknown email type: ${type}`);
    }
    
    logger.info('Email sent successfully', { jobId: job.id, type });
    return { success: true };
  } catch (error) {
    logger.error('Email job failed', { jobId: job.id, type, error: error.message });
    throw error; // BullMQ will retry
  }
}, {
  connection: redisClient,
  concurrency: 5, // Process 5 emails concurrently
  limiter: {
    max: 100, // Max 100 emails per minute
    duration: 60000
  }
});

// Worker event listeners
emailWorker.on('completed', (job) => {
  logger.info('Email worker completed job', { jobId: job.id });
});

emailWorker.on('failed', (job, err) => {
  logger.error('Email worker failed job', { 
    jobId: job?.id, 
    error: err.message,
    attemptsMade: job?.attemptsMade
  });
});

emailWorker.on('error', (err) => {
  logger.error('Email worker error:', err.message);
});

// Graceful shutdown
async function closeWorker() {
  await emailWorker.close();
  logger.info('Email worker closed');
}

process.on('SIGINT', closeWorker);
process.on('SIGTERM', closeWorker);

module.exports = emailWorker;
