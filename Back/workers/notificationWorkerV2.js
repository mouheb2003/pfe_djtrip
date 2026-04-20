const notificationEventBus = require('../services/notificationEventBus');
const notificationService = require('../services/notificationServiceV2');
const Notification = require('../models/notification');
const NotificationAnalytics = require('../models/notificationAnalytics');

/**
 * Notification Worker V2
 * Processes notification events from the event bus and triggers push notifications
 * Works with or without Redis queue system
 * 
 * This worker listens to all notification events and:
 * 1. Creates database notification record
 * 2. Triggers push notification (via queue if available, direct otherwise)
 * 3. Tracks analytics
 */

// Worker status
let workerRunning = false;

/**
 * Initialize event listeners
 */
async function initializeEventListeners() {
  if (workerRunning) {
    console.log('⚠️ Worker already running');
    return;
  }

  workerRunning = true;
  console.log('🚀 Initializing notification event listeners...');

  // ============================================
  // BOOKING EVENTS
  // ============================================

  notificationEventBus.on('booking.created', async (data) => {
    try {
      console.log('📨 Booking created event:', data);
      
      // Send to organizer
      await notificationService.sendNewBookingNotification({
        organizerId: data.organizerId,
        touristName: data.touristName,
        activityTitle: data.activityTitle,
        bookingId: data.bookingId,
      });

      // Create DB notification for tourist
      await Notification.createNotification({
        user_id: data.touristId,
        type: 'booking',
        title: 'Réservation envoyée',
        message: `Votre réservation pour "${data.activityTitle}" est en attente d'approbation`,
        data: { bookingId: data.bookingId },
        priority: 'medium',
        related_entity_type: 'booking',
        related_entity_id: data.bookingId,
      });
    } catch (error) {
      console.error('Error processing booking.created event:', error);
    }
  });

  notificationEventBus.on('booking.approved', async (data) => {
    try {
      console.log('📨 Booking approved event received:', data);
      console.log('📨 Tourist ID type:', typeof data.touristId, 'value:', data.touristId);
      console.log('📨 Booking ID type:', typeof data.bookingId, 'value:', data.bookingId);

      // Create DB notification FIRST (ensure it's saved even if account is suspended)
      try {
        const notificationData = {
          user_id: data.touristId,
          type: 'booking',
          title: 'Réservation approuvée ✅',
          message: `Votre réservation pour "${data.activityTitle}" a été confirmée`,
          data: { bookingId: data.bookingId },
          priority: 'high',
          related_entity_type: 'booking',
          related_entity_id: data.bookingId,
        };
        console.log('📨 Creating notification with data:', notificationData);

        await Notification.createNotification(notificationData);
        console.log('✅ DB notification created for booking approval');
      } catch (dbError) {
        console.error('❌ Error creating DB notification:', dbError);
      }

      // Send to tourist (may skip if account is suspended)
      try {
        await notificationService.sendBookingApprovedNotification({
          touristId: data.touristId,
          activityTitle: data.activityTitle,
          bookingId: data.bookingId,
        });
      } catch (fcmError) {
        console.error('❌ Error sending FCM notification:', fcmError);
        // Don't throw - DB notification is already saved
      }
    } catch (error) {
      console.error('Error processing booking.approved event:', error);
    }
  });

  notificationEventBus.on('booking.rejected', async (data) => {
    try {
      console.log('📨 Booking rejected event:', data);

      // Create DB notification FIRST (ensure it's saved even if account is suspended)
      try {
        await Notification.createNotification({
          user_id: data.touristId,
          type: 'booking',
          title: 'Réservation refusée ❌',
          message: `Votre réservation pour "${data.activityTitle}" a été refusée`,
          data: { bookingId: data.bookingId },
          priority: 'high',
          related_entity_type: 'booking',
          related_entity_id: data.bookingId,
        });
        console.log('✅ DB notification created for booking rejection');
      } catch (dbError) {
        console.error('❌ Error creating DB notification:', dbError);
      }

      // Send to tourist (may skip if account is suspended)
      try {
        await notificationService.sendBookingRejectedNotification({
          touristId: data.touristId,
          activityTitle: data.activityTitle,
          bookingId: data.bookingId,
        });
      } catch (fcmError) {
        console.error('❌ Error sending FCM notification:', fcmError);
        // Don't throw - DB notification is already saved
      }
    } catch (error) {
      console.error('Error processing booking.rejected event:', error);
    }
  });

  notificationEventBus.on('booking.cancelled', async (data) => {
    try {
      console.log('📨 Booking cancelled event:', data);

      // Create DB notification FIRST (ensure it's saved even if account is suspended)
      try {
        await Notification.createNotification({
          user_id: data.touristId,
          type: 'booking',
          title: 'Réservation annulée',
          message: `Votre réservation pour "${data.activityTitle}" a été annulée`,
          data: { bookingId: data.bookingId },
          priority: 'medium',
          related_entity_type: 'booking',
          related_entity_id: data.bookingId,
        });
        console.log('✅ DB notification created for booking cancellation');
      } catch (dbError) {
        console.error('❌ Error creating DB notification:', dbError);
      }
    } catch (error) {
      console.error('Error processing booking.cancelled event:', error);
    }
  });

  notificationEventBus.on('booking.reminder', async (data) => {
    try {
      console.log('📨 Booking reminder event:', data);

      // Create DB notification FIRST (ensure it's saved even if account is suspended)
      try {
        await Notification.createNotification({
          user_id: data.touristId,
          type: 'reminder',
          title: 'Rappel de réservation ⏰',
          message: `"${data.activityTitle}" commence bientôt`,
          data: { bookingId: data.bookingId, activityId: data.activityId },
          priority: 'high',
          related_entity_type: 'booking',
          related_entity_id: data.bookingId,
        });
        console.log('✅ DB notification created for booking reminder');
      } catch (dbError) {
        console.error('❌ Error creating DB notification:', dbError);
      }

      // Send to tourist (may skip if account is suspended)
      try {
        await notificationService.sendBookingReminder({
          touristId: data.touristId,
          activityTitle: data.activityTitle,
          bookingId: data.bookingId,
          activityId: data.activityId,
        });
      } catch (fcmError) {
        console.error('❌ Error sending FCM notification:', fcmError);
        // Don't throw - DB notification is already saved
      }
    } catch (error) {
      console.error('Error processing booking.reminder event:', error);
    }
  });

  notificationEventBus.on('booking.checkin', async (data) => {
    try {
      console.log('📨 Booking checkin event:', data);
      
      // Send to tourist
      await notificationService.sendCheckInConfirmation({
        touristId: data.touristId,
        activityTitle: data.activityTitle,
        bookingId: data.bookingId,
        activityId: data.activityId,
      });

      // Create DB notification
      await Notification.createNotification({
        user_id: data.touristId,
        type: 'booking',
        title: 'Check-in confirmé ✅',
        message: `Votre réservation pour "${data.activityTitle}" est validée`,
        data: { bookingId: data.bookingId, activityId: data.activityId },
        priority: 'high',
        related_entity_type: 'booking',
        related_entity_id: data.bookingId,
      });
    } catch (error) {
      console.error('Error processing booking.checkin event:', error);
    }
  });

  // ============================================
  // MESSAGE EVENTS
  // ============================================

  notificationEventBus.on('message.received', async (data) => {
    try {
      console.log('📨 Message received event:', data);
      console.log('📨 Listener called for message.received, messageId:', data.messageId);

      const senderName = data.senderName || 'Quelqu\'un';

      // Send to recipient
      await notificationService.sendPushNotification({
        userId: data.recipientId,
        title: `Nouveau message de ${senderName}`,
        body: data.message?.substring(0, 100) || 'Vous avez un nouveau message',
        data: {
          type: 'new_message',
          conversationId: data.conversationId,
          senderId: data.senderId,
        },
        notificationType: 'message',
        priority: 'medium',
      });

      // Create DB notification
      console.log('📨 Creating DB notification for messageId:', data.messageId);
      await Notification.createNotification({
        user_id: data.recipientId,
        type: 'message',
        title: `Nouveau message de ${senderName}`,
        message: data.message?.substring(0, 100) || 'Vous avez un nouveau message',
        data: {
          conversationId: data.conversationId,
          senderId: data.senderId,
        },
        priority: 'medium',
        related_entity_type: 'message',
        related_entity_id: data.messageId,
      });
      console.log('📨 DB notification created for messageId:', data.messageId);
    } catch (error) {
      console.error('Error processing message.received event:', error);
    }
  });

  // ============================================
  // COMMENT EVENTS
  // ============================================

  notificationEventBus.on('comment.created', async (data) => {
    try {
      console.log('📨 Comment created event:', data);
      
      const commenterName = data.commenterName || 'Quelqu\'un';
      
      // Send to post owner
      await notificationService.sendPushNotification({
        userId: data.postOwnerId,
        title: 'Nouveau commentaire',
        body: `${commenterName} a commenté votre publication`,
        data: {
          type: 'new_comment',
          postId: data.postId,
          commentId: data.commentId,
        },
        notificationType: 'system',
        priority: 'medium',
      });

      // Create DB notification
      await Notification.createNotification({
        user_id: data.postOwnerId,
        type: 'comment',
        title: 'Nouveau commentaire',
        message: `${commenterName} a commenté votre publication`,
        data: {
          postId: data.postId,
          commentId: data.commentId,
        },
        priority: 'medium',
        related_entity_type: 'post',
        related_entity_id: data.postId,
      });
    } catch (error) {
      console.error('Error processing comment.created event:', error);
    }
  });

  notificationEventBus.on('comment.reply', async (data) => {
    try {
      console.log('📨 Comment reply event:', data);
      
      const replierName = data.replierName || 'Quelqu\'un';
      
      // Send to parent comment author
      await notificationService.sendPushNotification({
        userId: data.parentCommentAuthorId,
        title: 'Réponse à votre commentaire',
        body: `${replierName} a répondu à votre commentaire`,
        data: {
          type: 'comment_reply',
          postId: data.postId,
          commentId: data.commentId,
          parentCommentId: data.parentCommentId,
        },
        notificationType: 'system',
        priority: 'medium',
      });

      // Create DB notification
      await Notification.createNotification({
        user_id: data.parentCommentAuthorId,
        type: 'reply',
        title: 'Réponse à votre commentaire',
        message: `${replierName} a répondu à votre commentaire`,
        data: {
          postId: data.postId,
          commentId: data.commentId,
          parentCommentId: data.parentCommentId,
        },
        priority: 'medium',
        related_entity_type: 'comment',
        related_entity_id: data.parentCommentId,
      });
    } catch (error) {
      console.error('Error processing comment.reply event:', error);
    }
  });

  // ============================================
  // REVIEW EVENTS
  // ============================================

  notificationEventBus.on('review.created', async (data) => {
    try {
      console.log('📨 Review created event:', data);
      
      // Send to organizer
      await notificationService.sendNewReviewNotification({
        organizerId: data.organizerId,
        touristName: data.touristName,
        activityTitle: data.activityTitle,
        rating: data.rating,
        reviewId: data.reviewId,
      });

      // Create DB notification
      await Notification.createNotification({
        user_id: data.organizerId,
        type: 'review',
        title: 'Nouvel avis reçu ⭐',
        message: `${data.touristName} a noté "${data.activityTitle}" ${data.rating}/5`,
        data: { reviewId: data.reviewId, rating: data.rating },
        priority: 'medium',
        related_entity_type: 'review',
        related_entity_id: data.reviewId,
      });
    } catch (error) {
      console.error('Error processing review.created event:', error);
    }
  });

  notificationEventBus.on('review.reminder', async (data) => {
    try {
      console.log('📨 Review reminder event:', data);
      
      // Send to tourist
      await notificationService.sendReviewReminder({
        touristId: data.touristId,
        activityTitle: data.activityTitle,
        bookingId: data.bookingId,
        activityId: data.activityId,
      });

      // Create DB notification
      await Notification.createNotification({
        user_id: data.touristId,
        type: 'review',
        title: 'Donnez votre avis ⭐',
        message: `Comment s'est passée "${data.activityTitle}" ? Laissez un review !`,
        data: { bookingId: data.bookingId, activityId: data.activityId },
        priority: 'medium',
        related_entity_type: 'booking',
        related_entity_id: data.bookingId,
      });
    } catch (error) {
      console.error('Error processing review.reminder event:', error);
    }
  });

  // ============================================
  // FOLLOW EVENTS
  // ============================================

  notificationEventBus.on('follow.created', async (data) => {
    try {
      console.log('📨 Follow created event:', data);
      
      // Send to user being followed
      await notificationService.sendNewFollowerNotification({
        userId: data.userId,
        followerName: data.followerName,
        followerId: data.followerId,
      });

      // Create DB notification
      await Notification.createNotification({
        user_id: data.userId,
        type: 'follow',
        title: 'Nouveau follower 👋',
        message: `${data.followerName} a commencé à vous suivre`,
        data: { followerId: data.followerId },
        priority: 'medium',
        related_entity_type: 'user',
        related_entity_id: data.followerId,
      });
    } catch (error) {
      console.error('Error processing follow.created event:', error);
    }
  });

  notificationEventBus.on('follow.accepted', async (data) => {
    try {
      console.log('📨 Follow accepted event:', data);
      
      // Send to follower
      await notificationService.sendFollowAcceptedNotification({
        followerId: data.followerId,
        userName: data.userName,
        userId: data.userId,
      });

      // Create DB notification
      await Notification.createNotification({
        user_id: data.followerId,
        type: 'follow',
        title: 'Follow accepté 🎉',
        message: `${data.userName} a accepté votre follow`,
        data: { userId: data.userId },
        priority: 'medium',
        related_entity_type: 'user',
        related_entity_id: data.userId,
      });
    } catch (error) {
      console.error('Error processing follow.accepted event:', error);
    }
  });

  // ============================================
  // PAYMENT EVENTS
  // ============================================

  notificationEventBus.on('payment.completed', async (data) => {
    try {
      console.log('📨 Payment completed event:', data);
      
      // Send to user
      await notificationService.sendPaymentCompletedNotification({
        userId: data.userId,
        amount: data.amount,
        activityTitle: data.activityTitle,
        paymentId: data.paymentId,
      });

      // Create DB notification
      await Notification.createNotification({
        user_id: data.userId,
        type: 'payment',
        title: 'Paiement réussi 💳',
        message: `Votre paiement de ${data.amount}€ pour "${data.activityTitle}" est confirmé`,
        data: { paymentId: data.paymentId, amount: data.amount },
        priority: 'urgent',
        related_entity_type: 'payment',
      });
    } catch (error) {
      console.error('Error processing payment.completed event:', error);
    }
  });

  notificationEventBus.on('payment.failed', async (data) => {
    try {
      console.log('📨 Payment failed event:', data);
      
      // Send to user
      await notificationService.sendPaymentFailedNotification({
        userId: data.userId,
        amount: data.amount,
        activityTitle: data.activityTitle,
        paymentId: data.paymentId,
      });

      // Create DB notification
      await Notification.createNotification({
        user_id: data.userId,
        type: 'payment',
        title: 'Paiement échoué ❌',
        message: `Le paiement de ${data.amount}€ pour "${data.activityTitle}" a échoué`,
        data: { paymentId: data.paymentId, amount: data.amount },
        priority: 'urgent',
        related_entity_type: 'payment',
      });
    } catch (error) {
      console.error('Error processing payment.failed event:', error);
    }
  });

  notificationEventBus.on('payment.refunded', async (data) => {
    try {
      console.log('📨 Payment refunded event:', data);
      
      // Send to user
      await notificationService.sendPaymentRefundedNotification({
        userId: data.userId,
        amount: data.amount,
        paymentId: data.paymentId,
      });

      // Create DB notification
      await Notification.createNotification({
        user_id: data.userId,
        type: 'payment',
        title: 'Remboursement effectué 💰',
        message: `Un remboursement de ${data.amount}€ a été effectué`,
        data: { paymentId: data.paymentId, amount: data.amount },
        priority: 'high',
        related_entity_type: 'payment',
      });
    } catch (error) {
      console.error('Error processing payment.refunded event:', error);
    }
  });

  // ============================================
  // ACTIVITY EVENTS
  // ============================================

  notificationEventBus.on('activity.created', async (data) => {
    try {
      console.log('📨 Activity created event:', data);
      
      // Send to followers (bulk notification)
      if (data.followerIds && data.followerIds.length > 0) {
        await notificationService.sendBulkNotificationQueued({
          userIds: data.followerIds,
          title: 'Nouvelle activité 🎯',
          body: `${data.organizerName} a publié "${data.activityTitle}"`,
          data: {
            type: 'new_activity',
            activityId: data.activityId,
          },
          notificationType: 'activity',
          priority: 'medium',
        });

        // Create DB notifications for all followers
        const notifications = data.followerIds.map(followerId => ({
          user_id: followerId,
          type: 'activity',
          title: 'Nouvelle activité 🎯',
          message: `${data.organizerName} a publié "${data.activityTitle}"`,
          data: { activityId: data.activityId },
          priority: 'medium',
          related_entity_type: 'activity',
          related_entity_id: data.activityId,
        }));
        
        await Notification.insertMany(notifications);
      }
    } catch (error) {
      console.error('Error processing activity.created event:', error);
    }
  });

  notificationEventBus.on('activity.updated', async (data) => {
    try {
      console.log('📨 Activity updated event:', data);
      
      // Notify users who booked this activity
      if (data.bookedUserIds && data.bookedUserIds.length > 0) {
        await notificationService.sendBulkNotificationQueued({
          userIds: data.bookedUserIds,
          title: 'Activité mise à jour ✏️',
          body: `"${data.activityTitle}" a été mise à jour`,
          data: {
            type: 'activity_updated',
            activityId: data.activityId,
          },
          notificationType: 'activity',
          priority: 'medium',
        });
      }
    } catch (error) {
      console.error('Error processing activity.updated event:', error);
    }
  });

  notificationEventBus.on('activity.cancelled', async (data) => {
    try {
      console.log('📨 Activity cancelled event:', data);
      
      // Notify users who booked this activity
      if (data.bookedUserIds && data.bookedUserIds.length > 0) {
        await notificationService.sendBulkNotificationQueued({
          userIds: data.bookedUserIds,
          title: 'Activité annulée ❌',
          body: `"${data.activityTitle}" a été annulée`,
          data: {
            type: 'activity_cancelled',
            activityId: data.activityId,
          },
          notificationType: 'activity',
          priority: 'urgent',
        });

        // Create DB notifications
        const notifications = data.bookedUserIds.map(userId => ({
          user_id: userId,
          type: 'activity',
          title: 'Activité annulée ❌',
          message: `"${data.activityTitle}" a été annulée`,
          data: { activityId: data.activityId },
          priority: 'urgent',
          related_entity_type: 'activity',
          related_entity_id: data.activityId,
        }));
        
        await Notification.insertMany(notifications);
      }
    } catch (error) {
      console.error('Error processing activity.cancelled event:', error);
    }
  });

  // ============================================
  // PROFILE EVENTS
  // ============================================

  notificationEventBus.on('profile.updated', async (data) => {
    try {
      console.log('📨 Profile updated event:', data);
      
      // Send to user
      await notificationService.sendProfileUpdatedNotification({
        userId: data.userId,
        userName: data.userName,
      });
    } catch (error) {
      console.error('Error processing profile.updated event:', error);
    }
  });

  notificationEventBus.on('profile.verified', async (data) => {
    try {
      console.log('📨 Profile verified event:', data);
      
      // Send to user
      await notificationService.sendProfileVerifiedNotification({
        userId: data.userId,
      });

      // Create DB notification
      await Notification.createNotification({
        user_id: data.userId,
        type: 'profile',
        title: 'Profil vérifié ✓',
        message: 'Félicitations ! Votre profil est maintenant vérifié',
        data: {},
        priority: 'high',
      });
    } catch (error) {
      console.error('Error processing profile.verified event:', error);
    }
  });

  // ============================================
  // APPEAL EVENTS
  // ============================================

  notificationEventBus.on('appeal.created', async (data) => {
    try {
      console.log('📨 Appeal created event:', data);
      
      // Send to user
      await notificationService.sendAppealCreatedNotification({
        userId: data.userId,
        appealId: data.appealId,
      });

      // Create DB notification
      await Notification.createNotification({
        user_id: data.userId,
        type: 'appeal',
        title: 'Appel soumis 📋',
        message: 'Votre appel a été soumis et sera traité sous peu',
        data: { appealId: data.appealId },
        priority: 'high',
        related_entity_type: 'appeal',
        related_entity_id: data.appealId,
      });
    } catch (error) {
      console.error('Error processing appeal.created event:', error);
    }
  });

  notificationEventBus.on('appeal.resolved', async (data) => {
    try {
      console.log('📨 Appeal resolved event:', data);
      
      // Send to user
      await notificationService.sendAppealResolvedNotification({
        userId: data.userId,
        appealId: data.appealId,
        status: data.status,
      });

      // Create DB notification
      await Notification.createNotification({
        user_id: data.userId,
        type: 'appeal',
        title: data.status === 'approved' ? 'Appel accepté ✅' : 'Appel rejeté ❌',
        message: `Votre appel a été ${data.status === 'approved' ? 'accepté' : 'rejeté'}`,
        data: { appealId: data.appealId, status: data.status },
        priority: 'urgent',
        related_entity_type: 'appeal',
        related_entity_id: data.appealId,
      });
    } catch (error) {
      console.error('Error processing appeal.resolved event:', error);
    }
  });

  // ============================================
  // SYSTEM EVENTS
  // ============================================

  notificationEventBus.on('system.announcement', async (data) => {
    try {
      console.log('📨 System announcement event:', data);
      
      // Send to all users or specific role
      if (data.userIds && data.userIds.length > 0) {
        await notificationService.sendBulkNotificationQueued({
          userIds: data.userIds,
          title: data.title,
          body: data.message,
          data: {
            type: 'system_announcement',
          },
          notificationType: 'system',
          priority: data.priority || 'high',
        });

        // Create DB notifications
        const notifications = data.userIds.map(userId => ({
          user_id: userId,
          type: 'system',
          title: data.title,
          message: data.message,
          data: data.data || {},
          priority: data.priority || 'high',
          target_role: data.targetRole,
        }));
        
        await Notification.insertMany(notifications);
      }
    } catch (error) {
      console.error('Error processing system.announcement event:', error);
    }
  });

  console.log('✅ Notification event listeners initialized');
}

/**
 * Start the worker
 */
function startWorker() {
  console.log('🚀 Starting notification worker V2...');
  
  // Initialize Firebase
  notificationService.initializeFirebase();
  
  // Initialize event listeners
  initializeEventListeners();
  
  console.log('✅ Notification worker V2 started successfully');
}

// Start worker if this file is run directly
if (require.main === module) {
  startWorker();
}

module.exports = {
  startWorker,
  initializeEventListeners,
};
