const cron = require('node-cron');
const { expirePaidPendingInscriptions } = require('../controllers/inscription');
const logger = require('../utils/logger');

/**
 * Payment Expiration Cron Job
 * Runs every hour to cancel PAID_PENDING_CONFIRMATION inscriptions
 * that are more than 12 hours past the activity start date
 */
class PaymentExpirationCronJob {
  constructor() {
    this.job = null;
    this.isRunning = false;
  }
  
  /**
   * Start the cron job
   * Schedule: Every hour (0 * * * *)
   */
  start() {
    if (this.job) {
      logger.warn('Payment expiration cron job is already running');
      return;
    }
    
    // Run every hour
    this.job = cron.schedule('0 * * * *', async () => {
      if (this.isRunning) {
        logger.warn('Payment expiration job is already running, skipping this execution');
        return;
      }
      
      this.isRunning = true;
      logger.info('Starting payment expiration check...');
      
      try {
        const cancelledCount = await expirePaidPendingInscriptions();
        logger.info(`Payment expiration check completed. Cancelled ${cancelledCount} bookings (activities starting within 12 hours).`);
      } catch (error) {
        logger.error('Error in payment expiration cron job:', error);
      } finally {
        this.isRunning = false;
      }
    });
    
    logger.info('Payment expiration cron job started (schedule: every hour)');
  }
  
  /**
   * Stop the cron job
   */
  stop() {
    if (this.job) {
      this.job.stop();
      this.job = null;
      logger.info('Payment expiration cron job stopped');
    }
  }
  
  /**
   * Run the job manually (for testing or immediate execution)
   */
  async runManually() {
    if (this.isRunning) {
      logger.warn('Payment expiration job is already running');
      return;
    }
    
    this.isRunning = true;
    logger.info('Running payment expiration check manually...');
    
    try {
      const cancelledCount = await expirePaidPendingInscriptions();
      logger.info(`Manual payment expiration check completed. Cancelled ${cancelledCount} bookings.`);
      return cancelledCount;
    } catch (error) {
      logger.error('Error in manual payment expiration check:', error);
      throw error;
    } finally {
      this.isRunning = false;
    }
  }
  
  /**
   * Get job status
   */
  getStatus() {
    return {
      isRunning: this.isRunning,
      isScheduled: !!this.job
    };
  }
}

// Export singleton instance
const paymentExpirationCronJob = new PaymentExpirationCronJob();

module.exports = paymentExpirationCronJob;
