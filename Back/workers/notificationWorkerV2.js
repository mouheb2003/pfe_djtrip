const notificationEventBus = require('../services/notificationEventBus');
const notificationService = require('../services/notificationServiceV2');
const Notification = require('../models/notification');
const NotificationAnalytics = require('../models/notificationAnalytics');
const User = require('../models/user');

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
        title: 'Booking Sent',
        message: `Your booking for "${data.activityTitle}" is waiting for payment`,
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
          title: 'Booking Approved ✅',
          message: `Your booking for "${data.activityTitle}" has been confirmed`,
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
          title: 'Booking Rejected ❌',
          message: `Your booking for "${data.activityTitle}" has been rejected`,
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
          title: 'Booking Cancelled',
          message: `Your booking for "${data.activityTitle}" has been cancelled`,
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
          title: 'Booking Reminder ⏰',
          message: `"${data.activityTitle}" is starting soon`,
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
        title: 'Check-in Confirmed ✅',
        message: `Your booking for "${data.activityTitle}" is validated`,
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

      const senderName = data.senderName || 'Someone';

      // Send to recipient
      await notificationService.sendPushNotification({
        userId: data.recipientId,
        title: `New message from ${senderName}`,
        body: data.message?.substring(0, 100) || 'You have a new message',
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
        title: `New message from ${senderName}`,
        message: data.message?.substring(0, 100) || 'You have a new message',
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
      
      const commenterName = data.commenterName || 'Someone';
      
      // Send to post owner
      await notificationService.sendPushNotification({
        userId: data.postOwnerId,
        title: 'New Comment',
        body: `${commenterName} commented on your post`,
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
        title: 'New Comment',
        message: `${commenterName} commented on your post`,
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

  notificationEventBus.on('post.reaction', async (data) => {
    try {
      console.log('📨 Post reaction event:', data);
      
      const reactorName = data.reactorName || 'Someone';
      const reactionType = data.reactionType || 'like';
      
      // Send to post owner
      await notificationService.sendPushNotification({
        userId: data.postOwnerId,
        title: 'New Reaction',
        body: `${reactorName} reacted to your post`,
        data: {
          type: 'post_reaction',
          postId: data.postId,
          reactionType: reactionType,
        },
        notificationType: 'system',
        priority: 'low',
      });

      // Create DB notification
      await Notification.createNotification({
        user_id: data.postOwnerId,
        type: 'reaction',
        title: 'New Reaction',
        message: `${reactorName} reacted to your post`,
        data: {
          postId: data.postId,
          reactionType: reactionType,
        },
        priority: 'low',
        related_entity_type: 'post',
        related_entity_id: data.postId,
      });
    } catch (error) {
      console.error('Error processing post.reaction event:', error);
    }
  });

  notificationEventBus.on('comment.reply', async (data) => {
    try {
      console.log('📨 Comment reply event:', data);
      
      const replierName = data.replierName || 'Someone';
      
      // Send to parent comment author
      await notificationService.sendPushNotification({
        userId: data.parentCommentAuthorId,
        title: 'Reply to Your Comment',
        body: `${replierName} replied to your comment`,
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
        type: 'comment',
        title: 'Reply to Your Comment',
        message: `${replierName} replied to your comment`,
        data: {
          type: 'comment_reply',
          postId: data.postId,
          commentId: data.commentId,
          parentCommentId: data.parentCommentId,
        },
        priority: 'medium',
        related_entity_type: 'comment',
        related_entity_id: data.commentId,
      });
    } catch (error) {
      console.error('Error processing comment.reply event:', error);
    }
  });

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
        title: 'New Review Received ⭐',
        message: `${data.touristName} rated "${data.activityTitle}" ${data.rating}/5`,
        data: { reviewId: data.reviewId, rating: data.rating },
        priority: 'medium',
        related_entity_type: 'review',
        related_entity_id: data.reviewId,
      });
    } catch (error) {
      console.error('Error processing review.created event:', error);
    }
  });

  notificationEventBus.on('user.mentioned', async (data) => {
    try {
      console.log('📨 User mentioned event:', data);
      
      const commenterName = data.commenterName || 'Someone';
      
      // Send to mentioned user
      await notificationService.sendPushNotification({
        userId: data.mentionedUserId,
        title: 'You Were Mentioned',
        body: `${commenterName} mentioned you in a comment`,
        data: {
          type: 'user_mentioned',
          postId: data.postId,
          commentId: data.commentId,
        },
        notificationType: 'system',
        priority: 'medium',
      });

      // Create DB notification
      await Notification.createNotification({
        user_id: data.mentionedUserId,
        type: 'mention',
        title: 'You Were Mentioned',
        message: `${commenterName} mentioned you in a comment`,
        data: {
          type: 'user_mentioned',
          postId: data.postId,
          commentId: data.commentId,
        },
        priority: 'medium',
        related_entity_type: 'comment',
        related_entity_id: data.commentId,
      });
    } catch (error) {
      console.error('Error processing user.mentioned event:', error);
    }
  });

  notificationEventBus.on('comment.reaction', async (data) => {
    try {
      console.log('📨 Comment reaction event:', data);
      
      const reactorName = data.reactorName || 'Someone';
      const reactionType = data.reactionType || 'like';
      
      // Send to comment author
      await notificationService.sendPushNotification({
        userId: data.targetOwnerId,
        title: 'New Reaction',
        body: `${reactorName} reacted to your comment`,
        data: {
          type: 'comment_reaction',
          postId: data.postId,
          commentId: data.targetId,
          reactionType: reactionType,
        },
        notificationType: 'system',
        priority: 'low',
      });

      // Create DB notification
      await Notification.createNotification({
        user_id: data.targetOwnerId,
        type: 'reaction',
        title: 'New Reaction',
        message: `${reactorName} reacted to your comment`,
        data: {
          postId: data.postId,
          commentId: data.targetId,
          reactionType: reactionType,
        },
        priority: 'low',
        related_entity_type: 'comment',
        related_entity_id: data.targetId,
      });
    } catch (error) {
      console.error('Error processing comment.reaction event:', error);
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
        title: 'Leave a Review ⭐',
        message: `How was "${data.activityTitle}"? Share your experience!`,
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
      
      // Create DB notification FIRST (ensure it's saved even if account is suspended)
      try {
        await Notification.createNotification({
          user_id: data.recipientId,
          type: 'follow',
          title: data.title || 'New Follower 👋',
          message: data.body || `${data.data?.followerName || 'Someone'} started following you`,
          data: data.data || {},
          priority: 'medium',
          related_entity_type: 'user',
          related_entity_id: data.data?.followerId,
        });
        console.log('✅ DB notification created for follow');
      } catch (dbError) {
        console.error('❌ Error creating DB notification for follow:', dbError);
      }

      // Send push notification (may skip if account is suspended)
      try {
        await notificationService.sendNewFollowerNotification({
          userId: data.recipientId,
          followerName: data.data?.followerName,
          followerId: data.data?.followerId,
        });
      } catch (fcmError) {
        console.error('❌ Error sending FCM notification for follow:', fcmError);
        // Don't throw - DB notification is already saved
      }
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
        title: 'Follow Accepted 🎉',
        message: `${data.userName} accepted your follow`,
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
        title: 'Payment Successful 💳',
        message: `Your payment of ${data.amount}€ for "${data.activityTitle}" is confirmed`,
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
        title: 'Payment Failed ❌',
        message: `Payment of ${data.amount}€ for "${data.activityTitle}" failed`,
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
        title: 'Refund Processed 💰',
        message: `A refund of ${data.amount}€ has been processed`,
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
          title: 'New Activity 🎯',
          body: `${data.organizerName} published "${data.activityTitle}"`,
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
          title: 'New Activity 🎯',
          message: `${data.organizerName} published "${data.activityTitle}"`,
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
          title: 'Activity Updated ✏️',
          body: `"${data.activityTitle}" has been updated`,
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
        // 1. Send Push Notifications
        await notificationService.sendBulkNotificationQueued({
          userIds: data.bookedUserIds,
          title: 'Activity Cancelled ❌',
          body: `"${data.activityTitle}" has been cancelled. Check your email for details.`,
          data: {
            type: 'activity_cancelled',
            activityId: data.activityId,
          },
          notificationType: 'activity',
          priority: 'urgent',
        });

        // 2. Create DB notifications
        const notifications = data.bookedUserIds.map(userId => ({
          user_id: userId,
          type: 'activity',
          title: 'Activity Cancelled ❌',
          message: `"${data.activityTitle}" has been cancelled`,
          data: { activityId: data.activityId },
          priority: 'urgent',
          related_entity_type: 'activity',
          related_entity_id: data.activityId,
        }));
        
        await Notification.insertMany(notifications);

        // 3. Send Apology Emails
        const Inscription = require('../models/inscription');
        const mailService = require('../services/email');
        
        // Fetch bookings to get tourist emails and the cancellation reason
        const bookings = await Inscription.find({
          activite_id: data.activityId,
          statut: 'annulee'
        }).populate('touriste_id', 'fullname email');

        for (const booking of bookings) {
          if (booking.touriste_id && booking.touriste_id.email) {
            await mailService.sendActivityCancelledEmail({
              email: booking.touriste_id.email,
              fullname: booking.touriste_id.fullname,
              activityTitle: data.activityTitle,
              reason: booking.message_organisateur
            });
          }
        }
      }
    } catch (error) {
      console.error('Error processing activity.cancelled event:', error);
    }
  });

  // ============================================
  // APPEAL EVENTS
  // ============================================

  notificationEventBus.on('appeal.created', async (data) => {
    try {
      console.log('📨 Appeal created event:', data);
      // Prepare display values
      const sender = data.userFullName || 'Someone';
      const subject = data.subject || 'Appeal';

      // Send confirmation to the user who submitted
      try {
        await notificationService.sendAppealCreatedNotification({
          userId: data.userId,
          appealId: data.appealId,
        });
      } catch (err) {
        console.error('Error sending appeal.created push to user:', err);
      }

      // Create DB notification for the submitting user
      await Notification.createNotification({
        user_id: data.userId,
        type: 'appeal',
        title: 'Appeal Submitted 📋',
        message: `Your appeal (${subject}) has been submitted and will be processed soon`,
        data: { appealId: data.appealId },
        priority: 'high',
        related_entity_type: 'appeal',
        related_entity_id: data.appealId,
      });

      // Notify admins: create DB notifications and send push with sender + subject
      // Find admins case-insensitively (userType may be stored as 'Admin' elsewhere)
      const admins = await User.find({ userType: { $regex: /^admin$/i } }).select('_id email').lean();
      if (admins.length > 0) {
        const adminIds = admins.map(a => a._id.toString());

        // Create admin DB notifications in bulk
        const adminNotifications = admins.map(admin => ({
          user_id: admin._id,
          type: 'appeal',
          title: `New Appeal from ${sender}`,
          message: `${sender} submitted "${subject}"`,
          data: { appealId: data.appealId, userId: data.userId },
          priority: 'high',
          related_entity_type: 'appeal',
          related_entity_id: data.appealId,
        }));

        try {
          await Notification.insertMany(adminNotifications);
        } catch (dbErr) {
          console.error('Error creating admin notifications for appeal.created:', dbErr);
        }

        // Send push notification to all admins
        try {
          await notificationService.sendBulkNotificationQueued({
            userIds: adminIds,
            title: `New Appeal from ${sender}`,
            body: `${sender} submitted "${subject}"`,
            data: {
              type: 'appeal_created',
              appealId: data.appealId,
              userId: data.userId,
            },
            notificationType: 'appeal',
            priority: 'high',
          });
        } catch (pushErr) {
          console.error('Error sending push to admins for appeal.created:', pushErr);
        }
      }
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
        title: data.status === 'accepted' ? 'Appeal Accepted ✅' : 'Appeal Rejected ❌',
        message: `Your appeal has been ${data.status === 'accepted' ? 'accepted' : 'rejected'}`,
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
