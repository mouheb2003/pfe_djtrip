const EventEmitter = require('events');

/**
 * Event Bus for Notification System
 * Central hub for all notification events in the application
 * 
 * Event Types:
 * - booking.created, booking.approved, booking.rejected, booking.cancelled, booking.reminder
 * - booking.checkin
 * - message.received
 * - review.created, review.reminder
 * - follow.created, follow.accepted
 * - payment.completed, payment.failed, payment.refunded
 * - activity.created, activity.updated, activity.cancelled
 * - profile.updated, profile.verified
 * - appeal.created, appeal.resolved
 * - system.announcement
 */

class NotificationEventBus extends EventEmitter {
  constructor() {
    super();
    this.setMaxListeners(50); // Allow many listeners for different notification types
  }

  /**
   * Emit booking events
   */
  emitBookingCreated(data) {
    this.emit('booking.created', data);
  }

  emitBookingApproved(data) {
    this.emit('booking.approved', data);
  }

  emitBookingRejected(data) {
    this.emit('booking.rejected', data);
  }

  emitBookingCancelled(data) {
    this.emit('booking.cancelled', data);
  }

  emitBookingReminder(data) {
    this.emit('booking.reminder', data);
  }

  emitBookingCheckIn(data) {
    this.emit('booking.checkin', data);
  }

  /**
   * Emit message events
   */
  emitMessageReceived(data) {
    this.emit('message.received', data);
  }

  /**
   * Emit comment events
   */
  emitCommentCreated(data) {
    this.emit('comment.created', data);
  }

  emitCommentReply(data) {
    this.emit('comment.reply', data);
  }

  emitUserMentioned(data) {
    this.emit('user.mentioned', data);
  }

  /**
   * Emit post reaction events
   */
  emitPostReaction(data) {
    this.emit('post.reaction', data);
  }

  /**
   * Emit review events
   */
  emitReviewCreated(data) {
    this.emit('review.created', data);
  }

  emitReviewReminder(data) {
    this.emit('review.reminder', data);
  }

  /**
   * Emit follow events
   */
  emitFollowCreated(data) {
    this.emit('follow.created', data);
  }

  emitFollowAccepted(data) {
    this.emit('follow.accepted', data);
  }

  /**
   * Emit payment events
   */
  emitPaymentCompleted(data) {
    this.emit('payment.completed', data);
  }

  emitPaymentFailed(data) {
    this.emit('payment.failed', data);
  }

  emitPaymentRefunded(data) {
    this.emit('payment.refunded', data);
  }

  /**
   * Emit activity events
   */
  emitActivityCreated(data) {
    this.emit('activity.created', data);
  }

  emitActivityUpdated(data) {
    this.emit('activity.updated', data);
  }

  emitActivityCancelled(data) {
    this.emit('activity.cancelled', data);
  }

  /**
   * Emit profile events
   */
  emitProfileUpdated(data) {
    this.emit('profile.updated', data);
  }

  emitProfileVerified(data) {
    this.emit('profile.verified', data);
  }

  /**
   * Emit appeal events
   */
  emitAppealCreated(data) {
    this.emit('appeal.created', data);
  }

  emitAppealResolved(data) {
    this.emit('appeal.resolved', data);
  }

  /**
   * Emit system events
   */
  emitSystemAnnouncement(data) {
    this.emit('system.announcement', data);
  }
}

// Singleton instance
const notificationEventBus = new NotificationEventBus();

module.exports = notificationEventBus;
