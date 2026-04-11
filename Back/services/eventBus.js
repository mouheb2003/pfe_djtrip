const { emailQueue, notificationQueue } = require('../queues');
const logger = require('../utils/logger');

/**
 * Event Bus Service
 * Centralized event-driven notification system
 * Routes events to appropriate queues (email, notification, etc.)
 */

const EventTypes = {
  BOOKING_CREATED: 'booking.created',
  BOOKING_APPROVED: 'booking.approved',
  BOOKING_REJECTED: 'booking.rejected',
  BOOKING_CANCELLED: 'booking.cancelled',
  CHECKIN_CONFIRMED: 'checkin.confirmed',
  ACTIVITY_REMINDER: 'activity.reminder',
  REVIEW_REMINDER: 'review.reminder',
  NO_SHOW_DETECTED: 'no_show.detected'
};

/**
 * Emit an event to the appropriate queues
 */
async function emitEvent(eventType, data) {
  try {
    logger.info('Event emitted', { eventType, data });
    
    switch (eventType) {
      case EventTypes.BOOKING_CREATED:
        // Send email to organizer
        await emailQueue.add('booking-created', {
          type: 'booking-confirmation',
          data
        });
        
        // Send notification to organizer
        await notificationQueue.add('booking-created', {
          type: 'booking-created',
          data
        });
        break;
        
      case EventTypes.BOOKING_APPROVED:
        // Send email to tourist with QR
        await emailQueue.add('booking-approved', {
          type: 'booking-approved',
          data
        });
        
        // Send notification to tourist
        await notificationQueue.add('booking-approved', {
          type: 'booking-approved',
          data
        });
        break;
        
      case EventTypes.BOOKING_REJECTED:
        // Send email to tourist
        await emailQueue.add('booking-rejected', {
          type: 'booking-rejected',
          data
        });
        
        // Send notification to tourist
        await notificationQueue.add('booking-rejected', {
          type: 'booking-rejected',
          data
        });
        break;
        
      case EventTypes.BOOKING_CANCELLED:
        // Send email to organizer
        await emailQueue.add('booking-cancelled', {
          type: 'booking-cancelled',
          data
        });
        
        // Send notification to organizer
        await notificationQueue.add('booking-cancelled', {
          type: 'booking-cancelled',
          data
        });
        
        // Queue refund processing if applicable
        if (data.refundAmount > 0) {
          const { refundQueue } = require('../queues');
          await refundQueue.add('process-refund', {
            type: 'refund',
            data: {
              bookingId: data.bookingId,
              refundAmount: data.refundAmount,
              touristId: data.touristId
            }
          }, {
            delay: 5000 // Process refund after 5 seconds
          });
        }
        break;
        
      case EventTypes.CHECKIN_CONFIRMED:
        // Send email to tourist
        await emailQueue.add('checkin-confirmed', {
          type: 'checkin-confirmed',
          data
        });
        
        // Send notification to tourist
        await notificationQueue.add('checkin-confirmed', {
          type: 'checkin-confirmed',
          data
        });
        break;
        
      case EventTypes.ACTIVITY_REMINDER:
        // Send email reminder
        await emailQueue.add('activity-reminder', {
          type: 'activity-reminder',
          data
        });
        
        // Send notification reminder
        await notificationQueue.add('activity-reminder', {
          type: 'activity-reminder',
          data
        });
        break;
        
      case EventTypes.REVIEW_REMINDER:
        // Send email reminder
        await emailQueue.add('review-reminder', {
          type: 'review-reminder',
          data
        });
        
        // Send notification reminder
        await notificationQueue.add('review-reminder', {
          type: 'review-reminder',
          data
        });
        break;
        
      case EventTypes.NO_SHOW_DETECTED:
        // Send notification to organizer
        await notificationQueue.add('no-show-detected', {
          type: 'no-show-detected',
          data
        });
        break;
        
      default:
        logger.warn('Unknown event type', { eventType });
    }
  } catch (error) {
    logger.error('Failed to emit event', { eventType, error: error.message });
    throw error;
  }
}

/**
 * Helper functions for common events
 */
async function emitBookingCreated(bookingId, organizerId, touristId, activityTitle) {
  return emitEvent(EventTypes.BOOKING_CREATED, {
    bookingId,
    organizerId,
    touristId,
    activityTitle
  });
}

async function emitBookingApproved(bookingId, touristId, activityTitle, qrToken) {
  return emitEvent(EventTypes.BOOKING_APPROVED, {
    bookingId,
    touristId,
    activityTitle,
    qrToken
  });
}

async function emitBookingRejected(bookingId, touristId, activityTitle, reason) {
  return emitEvent(EventTypes.BOOKING_REJECTED, {
    bookingId,
    touristId,
    activityTitle,
    reason
  });
}

async function emitBookingCancelled(bookingId, organizerId, touristId, activityTitle, reason, refundAmount) {
  return emitEvent(EventTypes.BOOKING_CANCELLED, {
    bookingId,
    organizerId,
    touristId,
    activityTitle,
    reason,
    refundAmount
  });
}

async function emitCheckinConfirmed(bookingId, touristId, activityTitle, checkinTime) {
  return emitEvent(EventTypes.CHECKIN_CONFIRMED, {
    bookingId,
    touristId,
    activityTitle,
    checkinTime
  });
}

async function emitActivityReminder(bookingId, touristId, activityTitle, activityDate) {
  return emitEvent(EventTypes.ACTIVITY_REMINDER, {
    bookingId,
    touristId,
    activityTitle,
    activityDate
  });
}

async function emitReviewReminder(bookingId, touristId, activityTitle) {
  return emitEvent(EventTypes.REVIEW_REMINDER, {
    bookingId,
    touristId,
    activityTitle
  });
}

async function emitNoShowDetected(bookingId, organizerId, touristId, activityTitle) {
  return emitEvent(EventTypes.NO_SHOW_DETECTED, {
    bookingId,
    organizerId,
    touristId,
    activityTitle
  });
}

module.exports = {
  EventTypes,
  emitEvent,
  emitBookingCreated,
  emitBookingApproved,
  emitBookingRejected,
  emitBookingCancelled,
  emitCheckinConfirmed,
  emitActivityReminder,
  emitReviewReminder,
  emitNoShowDetected
};
