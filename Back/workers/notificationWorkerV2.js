const notificationEventBus = require('../services/notificationEventBus');
const notificationService = require('../services/notificationServiceV2');
const Notification = require('../models/notification');
const User = require('../models/user');
const Inscription = require('../models/inscription');

/**
 * Notification Worker V2
 * - Creates DB notification records
 * - Sends dedicated push via notificationService (NOT via Notification.createNotification to avoid double push)
 * - All Notification.createNotification calls use skipPush: true
 */

let workerRunning = false;

async function initializeEventListeners() {
  if (workerRunning) {
    console.log('⚠️ Worker already running, skipping re-initialization');
    return;
  }
  workerRunning = true;
  console.log('🚀 Initializing notification event listeners...');

  // ============================================
  // BOOKING EVENTS
  // ============================================

  notificationEventBus.on('booking.created', async (data) => {
    try {
      console.log('📨 booking.created event:', data);

      // 1. DB notification for organizer (new booking request)
      await Notification.createNotification({
        user_id: data.organizerId,
        type: 'booking',
        title: 'New Booking Request 📋',
        message: `${data.touristName} wants to book "${data.activityTitle}"`,
        data: { bookingId: data.bookingId, touristId: data.touristId },
        priority: 'high',
        related_entity_type: 'booking',
        related_entity_id: data.bookingId,
        skipPush: true, // push sent separately below
      });

      // 2. DB notification for tourist (confirmation that request was sent)
      await Notification.createNotification({
        user_id: data.touristId,
        type: 'booking',
        title: 'Booking Request Sent ✅',
        message: `Your booking for "${data.activityTitle}" is pending organizer approval`,
        data: { bookingId: data.bookingId },
        priority: 'medium',
        related_entity_type: 'booking',
        related_entity_id: data.bookingId,
        skipPush: true,
      });

      // 3. Push notifications
      // 3a. Push to tourist confirming request was sent
      await notificationService.sendBookingRequestSentNotification({
        touristId: data.touristId,
        activityTitle: data.activityTitle,
        bookingId: data.bookingId,
      });

      // 3b. Push to organizer for new booking request
      await notificationService.sendNewBookingNotification({
        organizerId: data.organizerId,
        touristName: data.touristName,
        activityTitle: data.activityTitle,
        bookingId: data.bookingId,
      });

      // 4. Check if pending count > 5, send special push alert
      try {
        const pendingCount = await Inscription.countDocuments({
          organisateur_id: data.organizerId,
          statut: 'pending',
        });
        console.log(`📊 Organizer ${data.organizerId} has ${pendingCount} pending bookings`);

        if (pendingCount > 5) {
          await notificationService.sendPushNotification({
            userId: data.organizerId,
            title: '⚠️ Pending Requests Alert',
            body: `You have ${pendingCount} booking requests waiting for your approval!`,
            data: {
              type: 'pending_bookings_alert',
              count: pendingCount,
            },
            notificationType: 'booking',
            priority: 'high',
          });

          // Also save this alert in DB
          await Notification.createNotification({
            user_id: data.organizerId,
            type: 'booking',
            title: '⚠️ Pending Requests Alert',
            message: `You have ${pendingCount} booking requests waiting for your approval!`,
            data: { count: pendingCount, type: 'pending_bookings_alert' },
            priority: 'urgent',
            skipPush: true,
          });
        }
      } catch (countError) {
        console.error('❌ Error checking pending count:', countError);
      }

    } catch (error) {
      console.error('Error processing booking.created event:', error);
    }
  });

  notificationEventBus.on('booking.approved', async (data) => {
    try {
      console.log('📨 booking.approved event:', data);

      // 1. DB notification for tourist
      await Notification.createNotification({
        user_id: data.touristId,
        type: 'booking',
        title: 'Booking Approved ✅',
        message: `Your booking for "${data.activityTitle}" has been confirmed`,
        data: { bookingId: data.bookingId },
        priority: 'high',
        related_entity_type: 'booking',
        related_entity_id: data.bookingId,
        skipPush: true,
      });

      // 2. Push to tourist
      await notificationService.sendBookingApprovedNotification({
        touristId: data.touristId,
        activityTitle: data.activityTitle,
        bookingId: data.bookingId,
      });

    } catch (error) {
      console.error('Error processing booking.approved event:', error);
    }
  });

  notificationEventBus.on('booking.rejected', async (data) => {
    try {
      console.log('📨 booking.rejected event:', data);

      // 1. DB notification for tourist
      await Notification.createNotification({
        user_id: data.touristId,
        type: 'booking',
        title: 'Booking Rejected ❌',
        message: `Your booking for "${data.activityTitle}" has been rejected`,
        data: { bookingId: data.bookingId },
        priority: 'high',
        related_entity_type: 'booking',
        related_entity_id: data.bookingId,
        skipPush: true,
      });

      // 2. Push to tourist
      await notificationService.sendBookingRejectedNotification({
        touristId: data.touristId,
        activityTitle: data.activityTitle,
        bookingId: data.bookingId,
      });

    } catch (error) {
      console.error('Error processing booking.rejected event:', error);
    }
  });

  notificationEventBus.on('booking.cancelled', async (data) => {
    try {
      console.log('📨 booking.cancelled event:', data);

      // 1. DB for tourist
      await Notification.createNotification({
        user_id: data.touristId,
        type: 'booking',
        title: 'Booking Cancelled',
        message: `Your booking for "${data.activityTitle}" has been cancelled`,
        data: { bookingId: data.bookingId },
        priority: 'medium',
        related_entity_type: 'booking',
        related_entity_id: data.bookingId,
        skipPush: true,
      });

      // 2. DB for organizer
      await Notification.createNotification({
        user_id: data.organizerId,
        type: 'booking',
        title: 'Booking Cancelled ⚠️',
        message: `A booking for "${data.activityTitle}" was cancelled. Reason: ${data.reason || 'Not provided'}`,
        data: { bookingId: data.bookingId },
        priority: 'high',
        related_entity_type: 'booking',
        related_entity_id: data.bookingId,
        skipPush: true,
      });

      // 3. Push to organizer
      await notificationService.sendBookingCancelledNotification({
        organizerId: data.organizerId,
        activityTitle: data.activityTitle,
        bookingId: data.bookingId,
        reason: data.reason,
      });

    } catch (error) {
      console.error('Error processing booking.cancelled event:', error);
    }
  });

  notificationEventBus.on('booking.reminder', async (data) => {
    try {
      console.log('📨 booking.reminder event:', data);

      await Notification.createNotification({
        user_id: data.touristId,
        type: 'reminder',
        title: 'Booking Reminder ⏰',
        message: `"${data.activityTitle}" is starting soon`,
        data: { bookingId: data.bookingId, activityId: data.activityId },
        priority: 'high',
        related_entity_type: 'booking',
        related_entity_id: data.bookingId,
        skipPush: true,
      });

      await notificationService.sendBookingReminder({
        touristId: data.touristId,
        activityTitle: data.activityTitle,
        bookingId: data.bookingId,
        activityId: data.activityId,
      });

    } catch (error) {
      console.error('Error processing booking.reminder event:', error);
    }
  });

  notificationEventBus.on('booking.checkin', async (data) => {
    try {
      console.log('📨 booking.checkin event:', data);
      const isSuccess = data.status !== 'failed';

      if (isSuccess) {
        // Send email confirmation to participant (Tourist or External)
        try {
          const booking = await Inscription.findById(data.bookingId)
            .populate('touriste_id', 'fullname email')
            .populate('activite_id', 'titre');

          if (booking) {
            const email = booking.isExternal ? booking.externalEmail : booking.touriste_id?.email;
            const fullname = booking.isExternal ? booking.externalName : booking.touriste_id?.fullname || "Traveler";
            const activityTitle = booking.activite_id?.titre || data.activityTitle || "Activity";

            if (email) {
              const mailService = require('../services/email');
              await mailService.sendCheckInConfirmationEmail({
                email,
                fullname,
                activityTitle,
                bookingCode: booking.qr_token || data.bookingId,
                checkedInAt: booking.qr_used_at || new Date(),
              });
              console.log(`✅ Check-in confirmation email sent to ${email}`);
            }
          }
        } catch (mailErr) {
          console.error('❌ Failed to send check-in confirmation email:', mailErr.message);
        }

        if (data.touristId) {
          await Notification.createNotification({
            user_id: data.touristId,
            type: 'booking',
            title: 'Check-in Confirmed ✅',
            message: `Your booking for "${data.activityTitle}" is validated`,
            data: { bookingId: data.bookingId, activityId: data.activityId },
            priority: 'high',
            related_entity_type: 'booking',
            related_entity_id: data.bookingId,
            skipPush: true,
          });

          await notificationService.sendCheckInConfirmation({
            touristId: data.touristId,
            activityTitle: data.activityTitle,
            bookingId: data.bookingId,
            activityId: data.activityId,
          });
        }
      } else {
        if (data.touristId) {
          await Notification.createNotification({
            user_id: data.touristId,
            type: 'booking',
            title: 'Check-in Failed ❌',
            message: `Check-in for "${data.activityTitle}" failed: ${data.reason || 'Invalid QR'}`,
            data: { bookingId: data.bookingId, status: 'failed' },
            priority: 'high',
            related_entity_type: 'booking',
            related_entity_id: data.bookingId,
            skipPush: true,
          });

          await notificationService.sendCheckInFailedNotification({
            touristId: data.touristId,
            activityTitle: data.activityTitle,
            bookingId: data.bookingId,
            reason: data.reason,
          });
        }
      }

    } catch (error) {
      console.error('Error processing booking.checkin event:', error);
    }
  });

  // ============================================
  // MESSAGE EVENTS
  // ============================================

  notificationEventBus.on('message.received', async (data) => {
    try {
      console.log('📨 message.received event:', data);
      const senderName = data.senderName || 'Someone';

      await Notification.createNotification({
        user_id: data.recipientId,
        type: 'message',
        title: `New message from ${senderName}`,
        message: data.message?.substring(0, 100) || 'You have a new message',
        data: { conversationId: data.conversationId, senderId: data.senderId },
        priority: 'medium',
        related_entity_type: 'message',
        related_entity_id: data.messageId,
        skipPush: true,
      });

      await notificationService.sendPushNotification({
        userId: data.recipientId,
        title: `New message from ${senderName}`,
        body: data.message?.substring(0, 100) || 'You have a new message',
        data: { type: 'new_message', conversationId: data.conversationId, senderId: data.senderId },
        notificationType: 'message',
        priority: 'medium',
      });

    } catch (error) {
      console.error('Error processing message.received event:', error);
    }
  });

  // ============================================
  // COMMENT EVENTS
  // ============================================

  notificationEventBus.on('comment.created', async (data) => {
    try {
      console.log('📨 comment.created event:', data);
      const commenterName = data.commenterName || 'Someone';

      if (!data.isSelfComment && data.postOwnerId) {
        await Notification.createNotification({
          user_id: data.postOwnerId,
          type: 'comment',
          title: 'New Comment',
          message: `${commenterName} commented on your post`,
          data: { postId: data.postId, commentId: data.commentId },
          priority: 'medium',
          related_entity_type: 'post',
          related_entity_id: data.postId,
          skipPush: true,
        });

        await notificationService.sendPushNotification({
          userId: data.postOwnerId,
          title: 'New Comment',
          body: `${commenterName} commented on your post`,
          data: { type: 'new_comment', postId: data.postId, commentId: data.commentId },
          notificationType: 'system',
          priority: 'medium',
        });
      }

      // Notify users mentioned in the post
      if (data.postMentions && Array.isArray(data.postMentions)) {
        for (const mentionedId of data.postMentions) {
          // Don't notify the mentioned user if they are the ones who commented, or if they are the post owner (already notified)
          if (String(mentionedId) !== String(data.postOwnerId)) {
            await Notification.createNotification({
              user_id: mentionedId,
              type: 'comment',
              title: 'New Comment',
              message: `${commenterName} commented on a post where you are mentioned`,
              data: { postId: data.postId, commentId: data.commentId, type: 'comment_mentioned' },
              priority: 'medium',
              related_entity_type: 'post',
              related_entity_id: data.postId,
              skipPush: true,
            });

            await notificationService.sendPushNotification({
              userId: mentionedId,
              title: 'New Comment',
              body: `${commenterName} commented on a post where you are mentioned`,
              data: { type: 'comment_mentioned', postId: data.postId, commentId: data.commentId },
              notificationType: 'system',
              priority: 'medium',
            });
          }
        }
      }

    } catch (error) {
      console.error('Error processing comment.created event:', error);
    }
  });

  notificationEventBus.on('post.reaction', async (data) => {
    try {
      console.log('📨 post.reaction event:', data);
      const reactorName = data.reactorName || 'Someone';
      const reactionType = data.reactionType || 'like';

      if (!data.isSelfReaction && data.postOwnerId) {
        await Notification.createNotification({
          user_id: data.postOwnerId,
          type: 'reaction',
          title: 'New Reaction',
          message: `${reactorName} reacted to your post`,
          data: { postId: data.postId, reactionType },
          priority: 'low',
          related_entity_type: 'post',
          related_entity_id: data.postId,
          skipPush: true,
        });

        await notificationService.sendPushNotification({
          userId: data.postOwnerId,
          title: 'New Reaction',
          body: `${reactorName} reacted to your post`,
          data: { type: 'post_reaction', postId: data.postId, reactionType },
          notificationType: 'system',
          priority: 'low',
        });
      }

      // Notify users mentioned in the post
      if (data.postMentions && Array.isArray(data.postMentions)) {
        for (const mentionedId of data.postMentions) {
          if (String(mentionedId) !== String(data.postOwnerId)) {
            await Notification.createNotification({
              user_id: mentionedId,
              type: 'reaction',
              title: 'New Reaction',
              message: `${reactorName} reacted to a post where you are mentioned`,
              data: { postId: data.postId, reactionType, type: 'reaction_mentioned' },
              priority: 'low',
              related_entity_type: 'post',
              related_entity_id: data.postId,
              skipPush: true,
            });

            await notificationService.sendPushNotification({
              userId: mentionedId,
              title: 'New Reaction',
              body: `${reactorName} reacted to a post where you are mentioned`,
              data: { type: 'reaction_mentioned', postId: data.postId, reactionType },
              notificationType: 'system',
              priority: 'low',
            });
          }
        }
      }

    } catch (error) {
      console.error('Error processing post.reaction event:', error);
    }
  });

  notificationEventBus.on('comment.reply', async (data) => {
    try {
      console.log('📨 comment.reply event:', data);
      const replierName = data.replierName || 'Someone';

      await Notification.createNotification({
        user_id: data.parentCommentAuthorId,
        type: 'comment',
        title: 'Reply to Your Comment',
        message: `${replierName} replied to your comment`,
        data: { type: 'comment_reply', postId: data.postId, commentId: data.commentId, parentCommentId: data.parentCommentId },
        priority: 'medium',
        related_entity_type: 'comment',
        related_entity_id: data.commentId,
        skipPush: true,
      });

      await notificationService.sendPushNotification({
        userId: data.parentCommentAuthorId,
        title: 'Reply to Your Comment',
        body: `${replierName} replied to your comment`,
        data: { type: 'comment_reply', postId: data.postId, commentId: data.commentId },
        notificationType: 'system',
        priority: 'medium',
      });

    } catch (error) {
      console.error('Error processing comment.reply event:', error);
    }
  });

  notificationEventBus.on('comment.reaction', async (data) => {
    try {
      console.log('📨 comment.reaction event:', data);
      const reactorName = data.reactorName || 'Someone';
      const reactionType = data.reactionType || 'like';

      await Notification.createNotification({
        user_id: data.targetOwnerId,
        type: 'reaction',
        title: 'New Reaction',
        message: `${reactorName} reacted to your comment`,
        data: { postId: data.postId, commentId: data.targetId, reactionType },
        priority: 'low',
        related_entity_type: 'comment',
        related_entity_id: data.targetId,
        skipPush: true,
      });

      await notificationService.sendPushNotification({
        userId: data.targetOwnerId,
        title: 'New Reaction',
        body: `${reactorName} reacted to your comment`,
        data: { type: 'comment_reaction', postId: data.postId, commentId: data.targetId, reactionType },
        notificationType: 'system',
        priority: 'low',
      });

    } catch (error) {
      console.error('Error processing comment.reaction event:', error);
    }
  });

  // ============================================
  // REVIEW EVENTS
  // ============================================

  notificationEventBus.on('review.created', async (data) => {
    try {
      console.log('📨 review.created event:', data);

      await Notification.createNotification({
        user_id: data.organizerId,
        type: 'review',
        title: 'New Review Received ⭐',
        message: `${data.touristName} rated "${data.activityTitle}" ${data.rating}/5`,
        data: { reviewId: data.reviewId, rating: data.rating },
        priority: 'medium',
        related_entity_type: 'review',
        related_entity_id: data.reviewId,
        skipPush: true,
      });

      await notificationService.sendNewReviewNotification({
        organizerId: data.organizerId,
        touristName: data.touristName,
        activityTitle: data.activityTitle,
        rating: data.rating,
        reviewId: data.reviewId,
      });

    } catch (error) {
      console.error('Error processing review.created event:', error);
    }
  });

  notificationEventBus.on('review.reminder', async (data) => {
    try {
      console.log('📨 review.reminder event:', data);

      await Notification.createNotification({
        user_id: data.touristId,
        type: 'review',
        title: 'Leave a Review ⭐',
        message: `How was "${data.activityTitle}"? Share your experience!`,
        data: { bookingId: data.bookingId, activityId: data.activityId },
        priority: 'medium',
        related_entity_type: 'booking',
        related_entity_id: data.bookingId,
        skipPush: true,
      });

      await notificationService.sendReviewReminder({
        touristId: data.touristId,
        activityTitle: data.activityTitle,
        bookingId: data.bookingId,
        activityId: data.activityId,
      });

    } catch (error) {
      console.error('Error processing review.reminder event:', error);
    }
  });

  // ============================================
  // USER MENTION EVENTS
  // ============================================

  notificationEventBus.on('user.mentioned', async (data) => {
    try {
      console.log('📨 user.mentioned event:', data);
      const commenterName = data.commenterName || 'Someone';

      await Notification.createNotification({
        user_id: data.mentionedUserId,
        type: 'comment',
        title: 'You Were Mentioned',
        message: `${commenterName} mentioned you in a comment`,
        data: { type: 'user_mentioned', postId: data.postId, commentId: data.commentId },
        priority: 'medium',
        related_entity_type: 'comment',
        related_entity_id: data.commentId,
        skipPush: true,
      });

      await notificationService.sendPushNotification({
        userId: data.mentionedUserId,
        title: 'You Were Mentioned',
        body: `${commenterName} mentioned you in a comment`,
        data: { type: 'user_mentioned', postId: data.postId, commentId: data.commentId },
        notificationType: 'system',
        priority: 'medium',
      });

    } catch (error) {
      console.error('Error processing user.mentioned event:', error);
    }
  });

  notificationEventBus.on('post.mentioned', async (data) => {
    try {
      console.log('📨 post.mentioned event:', data);
      const authorName = data.authorName || 'Someone';

      await Notification.createNotification({
        user_id: data.mentionedUserId,
        type: 'post',
        title: 'You Were Mentioned in a Post 🏷️',
        message: `${authorName} tagged/mentioned you in a post`,
        data: { type: 'post_mentioned', postId: data.postId },
        priority: 'high',
        related_entity_type: 'post',
        related_entity_id: data.postId,
        skipPush: true,
      });

      await notificationService.sendPushNotification({
        userId: data.mentionedUserId,
        title: 'You Were Mentioned in a Post 🏷️',
        body: `${authorName} tagged/mentioned you in a post`,
        data: { type: 'post_mentioned', postId: data.postId },
        notificationType: 'system',
        priority: 'high',
      });

    } catch (error) {
      console.error('Error processing post.mentioned event:', error);
    }
  });

  // ============================================
  // FOLLOW EVENTS
  // ============================================

  notificationEventBus.on('follow.created', async (data) => {
    try {
      console.log('📨 follow.created event:', data);

      await Notification.createNotification({
        user_id: data.recipientId,
        type: 'follow',
        title: data.title || 'New Follower 👋',
        message: data.body || `${data.data?.followerName || 'Someone'} started following you`,
        data: data.data || {},
        priority: 'medium',
        related_entity_type: 'user',
        related_entity_id: data.data?.followerId,
        skipPush: true,
      });

      await notificationService.sendNewFollowerNotification({
        userId: data.recipientId,
        followerName: data.data?.followerName,
        followerId: data.data?.followerId,
      });

    } catch (error) {
      console.error('Error processing follow.created event:', error);
    }
  });

  notificationEventBus.on('follow.accepted', async (data) => {
    try {
      console.log('📨 follow.accepted event:', data);

      await Notification.createNotification({
        user_id: data.followerId,
        type: 'follow',
        title: 'Follow Accepted 🎉',
        message: `${data.userName} accepted your follow`,
        data: { userId: data.userId },
        priority: 'medium',
        related_entity_type: 'user',
        related_entity_id: data.userId,
        skipPush: true,
      });

      await notificationService.sendFollowAcceptedNotification({
        followerId: data.followerId,
        userName: data.userName,
        userId: data.userId,
      });

    } catch (error) {
      console.error('Error processing follow.accepted event:', error);
    }
  });

  // ============================================
  // ACTIVITY EVENTS
  // ============================================

  notificationEventBus.on('activity.created', async (data) => {
    try {
      console.log('📨 activity.created event:', data);
      if (data.followerIds && data.followerIds.length > 0) {
        await notificationService.sendBulkNotificationQueued({
          userIds: data.followerIds,
          title: 'New Activity 🎯',
          body: `${data.organizerName} published "${data.activityTitle}"`,
          data: { type: 'new_activity', activityId: data.activityId },
          notificationType: 'activity',
          priority: 'medium',
        });

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
      console.log('📨 activity.updated event:', data);
      if (data.bookedUserIds && data.bookedUserIds.length > 0) {
        await notificationService.sendBulkNotificationQueued({
          userIds: data.bookedUserIds,
          title: 'Activity Updated ✏️',
          body: `"${data.activityTitle}" has been updated`,
          data: { type: 'activity_updated', activityId: data.activityId },
          notificationType: 'activity',
          priority: 'medium',
        });

        const notifications = data.bookedUserIds.map(userId => ({
          user_id: userId,
          type: 'activity',
          title: 'Activity Updated ✏️',
          message: `"${data.activityTitle}" has been updated`,
          data: { activityId: data.activityId },
          priority: 'medium',
          related_entity_type: 'activity',
          related_entity_id: data.activityId,
        }));
        await Notification.insertMany(notifications);
      }
    } catch (error) {
      console.error('Error processing activity.updated event:', error);
    }
  });

  notificationEventBus.on('activity.cancelled', async (data) => {
    try {
      console.log('📨 activity.cancelled event:', data);
      if (data.bookedUserIds && data.bookedUserIds.length > 0) {
        await notificationService.sendBulkNotificationQueued({
          userIds: data.bookedUserIds,
          title: 'Activity Cancelled ❌',
          body: `"${data.activityTitle}" has been cancelled. Check your email for details.`,
          data: { type: 'activity_cancelled', activityId: data.activityId },
          notificationType: 'activity',
          priority: 'urgent',
        });

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

        // Send emails
        const mailService = require('../services/email');
        const bookings = await Inscription.find({
          activite_id: data.activityId,
          statut: 'cancelled',
        }).populate('touriste_id', 'fullname email');

        for (const booking of bookings) {
          const email = booking.isExternal ? booking.externalEmail : booking.touriste_id?.email;
          const fullname = booking.isExternal ? booking.externalName : booking.touriste_id?.fullname;

          if (email) {
            await mailService.sendActivityCancelledEmail({
              email,
              fullname: fullname || "Traveler",
              activityTitle: data.activityTitle,
              reason: data.reason || booking.message_organisateur,
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
      console.log('📨 appeal.created event:', data);
      const sender = data.userFullName || 'Someone';
      const subject = data.subject || 'Appeal';

      // DB + push for user who submitted
      await Notification.createNotification({
        user_id: data.userId,
        type: 'appeal',
        title: 'Appeal Submitted 📋',
        message: `Your appeal (${subject}) has been submitted and will be processed soon`,
        data: { appealId: data.appealId },
        priority: 'high',
        related_entity_type: 'appeal',
        related_entity_id: data.appealId,
        skipPush: true,
      });

      await notificationService.sendAppealCreatedNotification({ userId: data.userId, appealId: data.appealId });

      // Admins
      const admins = await User.find({ userType: { $regex: /^admin$/i } }).select('_id').lean();
      if (admins.length > 0) {
        const adminIds = admins.map(a => a._id.toString());

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
        await Notification.insertMany(adminNotifications);

        await notificationService.sendBulkNotificationQueued({
          userIds: adminIds,
          title: `New Appeal from ${sender}`,
          body: `${sender} submitted "${subject}"`,
          data: { type: 'appeal_created', appealId: data.appealId, userId: data.userId },
          notificationType: 'appeal',
          priority: 'high',
        });
      }
    } catch (error) {
      console.error('Error processing appeal.created event:', error);
    }
  });

  notificationEventBus.on('appeal.resolved', async (data) => {
    try {
      console.log('📨 appeal.resolved event:', data);

      await Notification.createNotification({
        user_id: data.userId,
        type: 'appeal',
        title: data.status === 'accepted' ? 'Appeal Accepted ✅' : 'Appeal Rejected ❌',
        message: `Your appeal has been ${data.status === 'accepted' ? 'accepted' : 'rejected'}`,
        data: { appealId: data.appealId, status: data.status },
        priority: 'urgent',
        related_entity_type: 'appeal',
        related_entity_id: data.appealId,
        skipPush: true,
      });

      await notificationService.sendAppealResolvedNotification({ userId: data.userId, appealId: data.appealId, status: data.status });

    } catch (error) {
      console.error('Error processing appeal.resolved event:', error);
    }
  });

  // ============================================
  // SYSTEM EVENTS
  // ============================================

  notificationEventBus.on('system.announcement', async (data) => {
    try {
      console.log('📨 system.announcement event:', data);
      if (data.userIds && data.userIds.length > 0) {
        await notificationService.sendBulkNotificationQueued({
          userIds: data.userIds,
          title: data.title,
          body: data.message,
          data: { type: 'system_announcement' },
          notificationType: 'system',
          priority: data.priority || 'high',
        });

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
  initializeEventListeners();
  console.log('✅ Notification worker V2 started successfully');
}

if (require.main === module) {
  startWorker();
}

module.exports = { startWorker, initializeEventListeners };
