const cron = require('node-cron');
const Inscription = require('../models/inscription');
const Activite = require('../models/activite');
const notificationEventBus = require('../services/notificationEventBus');
const logger = require('../utils/logger');

/**
 * Booking Reminder Cron Job
 * Runs every 15 minutes to send reminders for bookings starting within 1 hour
 */
class BookingReminderCronJob {
  constructor() {
    this.job = null;
    this.isRunning = false;
  }

  /**
   * Start the cron job
   * Schedule: Every 15 minutes
   */
  start() {
    if (this.job) {
      logger.warn('Booking reminder cron job is already running');
      return;
    }

    // Run every 15 minutes
    this.job = cron.schedule('*/15 * * * *', async () => {
      if (this.isRunning) {
        logger.warn('Booking reminder job is already running, skipping this execution');
        return;
      }

      this.isRunning = true;
      logger.info('Starting booking reminder check...');

      try {
        const reminderCount = await this.sendBookingReminders();
        logger.info(`Booking reminder check completed. Sent ${reminderCount} reminders.`);
      } catch (error) {
        logger.error('Error in booking reminder cron job:', error);
      } finally {
        this.isRunning = false;
      }
    });

    logger.info('Booking reminder cron job started (schedule: every 15 minutes)');
  }

  /**
   * Stop the cron job
   */
  stop() {
    if (this.job) {
      this.job.stop();
      this.job = null;
      logger.info('Booking reminder cron job stopped');
    }
  }

  /**
   * Send booking reminders based on user preferences
   */
  async sendBookingReminders() {
    const now = new Date();
    const oneHourFromNow = new Date(now.getTime() + 60 * 60 * 1000);
    const twentyFourHoursFromNow = new Date(now.getTime() + 24 * 60 * 60 * 1000);

    // Find approved bookings for activities starting soon
    // that haven't been reminded yet
    const bookings = await Inscription.find({
      statut: 'confirmed',
      'bookingReminder.sent': { $ne: true },
    })
      .populate('activite')
      .populate('touriste');

    let reminderCount = 0;

    for (const booking of bookings) {
      const activity = booking.activite;
      const tourist = booking.touriste;
      
      if (!activity || !activity.startDate) continue;
      if (!tourist || !tourist.reminderPreferences) continue;

      // Check if user has enabled booking reminders
      if (!tourist.reminderPreferences.bookingReminder) {
        continue;
      }

      const activityStart = new Date(activity.startDate);
      const timeUntilStart = activityStart.getTime() - now.getTime();
      const reminderTiming = tourist.reminderPreferences.reminderTiming || '1h';

      let shouldSendReminder = false;

      // Check timing based on user preference
      if (reminderTiming === '1h') {
        // Send reminder if activity starts within 1 hour (between 30-60 minutes)
        shouldSendReminder = timeUntilStart > 30 * 60 * 1000 && timeUntilStart <= 60 * 60 * 1000;
      } else if (reminderTiming === '24h') {
        // Send reminder if activity starts within 24 hours (between 23-24 hours)
        shouldSendReminder = timeUntilStart > 23 * 60 * 60 * 1000 && timeUntilStart <= 24 * 60 * 60 * 1000;
      } else if (reminderTiming === 'both') {
        // Send reminder at both 24h and 1h
        // Check if we need to send 24h reminder
        if (timeUntilStart > 23 * 60 * 60 * 1000 && timeUntilStart <= 24 * 60 * 60 * 1000) {
          shouldSendReminder = true;
        }
        // Check if we need to send 1h reminder (only if 24h was already sent)
        else if (timeUntilStart > 30 * 60 * 1000 && timeUntilStart <= 60 * 60 * 1000) {
          // For 'both' option, we need to track if 24h reminder was sent
          // For now, we'll send 1h reminder regardless (simplified logic)
          shouldSendReminder = true;
        }
      }

      if (shouldSendReminder) {
        try {
          // Emit booking reminder event
          notificationEventBus.emitBookingReminder({
            touristId: tourist._id,
            activityTitle: activity.titre,
            bookingId: booking._id,
            activityId: activity._id,
          });

          // Mark reminder as sent
          booking.bookingReminder = {
            sent: true,
            sentAt: now,
          };
          await booking.save();

          reminderCount++;
          logger.info(`Reminder sent for booking ${booking._id} (activity: ${activity.titre}, timing: ${reminderTiming})`);
        } catch (error) {
          logger.error(`Failed to send reminder for booking ${booking._id}:`, error);
        }
      }
    }

    return reminderCount;
  }

  /**
   * Run the job manually (for testing or immediate execution)
   */
  async runManually() {
    if (this.isRunning) {
      logger.warn('Booking reminder job is already running');
      return;
    }

    this.isRunning = true;
    logger.info('Running booking reminder check manually...');

    try {
      const reminderCount = await this.sendBookingReminders();
      logger.info(`Manual booking reminder check completed. Sent ${reminderCount} reminders.`);
      return reminderCount;
    } catch (error) {
      logger.error('Error in manual booking reminder check:', error);
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
const bookingReminderCronJob = new BookingReminderCronJob();

module.exports = bookingReminderCronJob;
