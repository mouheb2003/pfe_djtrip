const cron = require('node-cron');
const NoShowService = require('../services/noShowService');
const logger = require('../utils/logger');

/**
 * No-Show Detection Cron Job
 * Runs every hour to mark no-shows for ended activities
 */
class NoShowCronJob {
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
      logger.warn('No-show cron job is already running');
      return;
    }
    
    // Run every hour
    this.job = cron.schedule('0 * * * *', async () => {
      if (this.isRunning) {
        logger.warn('No-show job is already running, skipping this execution');
        return;
      }
      
      this.isRunning = true;
      const startTime = Date.now();
      
      try {
        logger.info('Starting no-show detection job');
        
        const result = await NoShowService.markNoShows();
        
        const duration = Date.now() - startTime;
        logger.info('No-show detection job completed', {
          marked: result.marked,
          activitiesChecked: result.activitiesChecked,
          duration: `${duration}ms`
        });
        
        // If no-shows were marked, you could trigger notifications here
        if (result.marked > 0) {
          // TODO: Send notifications to organizers about no-shows
          logger.info(`${result.marked} no-shows detected, notifications could be sent`);
        }
      } catch (error) {
        const duration = Date.now() - startTime;
        logger.error('No-show detection job failed', {
          error: error.message,
          duration: `${duration}ms`
        });
      } finally {
        this.isRunning = false;
      }
    });
    
    logger.info('No-show cron job started (schedule: every hour)');
  }
  
  /**
   * Stop the cron job
   */
  stop() {
    if (this.job) {
      this.job.stop();
      this.job = null;
      logger.info('No-show cron job stopped');
    }
  }
  
  /**
   * Run the job manually (for testing or immediate execution)
   */
  async runManually() {
    if (this.isRunning) {
      throw new Error('Job is already running');
    }
    
    this.isRunning = true;
    const startTime = Date.now();
    
    try {
      logger.info('Running no-show detection job manually');
      
      const result = await NoShowService.markNoShows();
      
      const duration = Date.now() - startTime;
      logger.info('Manual no-show detection completed', {
        marked: result.marked,
        activitiesChecked: result.activitiesChecked,
        duration: `${duration}ms`
      });
      
      return result;
    } catch (error) {
      const duration = Date.now() - startTime;
      logger.error('Manual no-show detection failed', {
        error: error.message,
        duration: `${duration}ms`
      });
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
const noShowCronJob = new NoShowCronJob();

module.exports = noShowCronJob;
