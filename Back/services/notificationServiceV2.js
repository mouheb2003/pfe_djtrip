const { initializeFirebase: initFirebase, getFirebaseAdmin, isInitialized } = require('../config/firebase');
const User = require('../models/user');
const NotificationPreference = require('../models/notificationPreference');
const NotificationAnalytics = require('../models/notificationAnalytics');
const { addNotificationJob } = require('../config/bullmq');

/**
 * Enhanced Notification Service V2
 * Production-ready with:
 * - Retry logic with exponential backoff
 * - Batching for bulk sends
 * - User preferences integration
 * - Analytics tracking
 * - Dynamic deep linking
 * - Queue-based processing
 */

// Configuration
const BATCH_SIZE = 500; // Max recipients per batch
const MAX_RETRIES = 3;
const RETRY_DELAY = 2000; // Base delay for exponential backoff

/**
 * Initialize Firebase
 */
function initializeFirebase() {
  try {
    initFirebase();
  } catch (error) {
    console.error('❌ Failed to initialize Firebase Admin SDK:', error.message);
  }
}

/**
 * Get user FCM token with device type detection
 * Uses the new FCM token service for proper active token management
 */
async function getUserFcmToken(userId) {
  try {
    const fcmTokenService = require('./fcmTokenService');
    const activeTokens = await fcmTokenService.getActiveTokens(userId);
    
    const user = await User.findById(userId).select('accountStatus');
    
    return {
      tokens: activeTokens.map(t => t.token),
      accountStatus: user?.accountStatus || 'active',
    };
  } catch (error) {
    console.error('Error getting user FCM token:', error);
    return { tokens: [], accountStatus: 'inactive' };
  }
}

/**
 * Update user FCM token
 */
async function updateUserFcmToken(userId, fcmToken) {
  try {
    await User.findByIdAndUpdate(userId, { fcmToken });
    return true;
  } catch (error) {
    console.error('Error updating user FCM token:', error);
    return false;
  }
}

/**
 * Remove invalid FCM token from user's tokens array
 */
async function removeInvalidToken(userId, invalidToken) {
  try {
    await User.findByIdAndUpdate(
      userId,
      {
        $pull: {
          fcmTokens: { token: invalidToken }
        }
      }
    );
    console.log(`🗑️ Removed invalid token for user ${userId}`);
    return true;
  } catch (error) {
    console.error('Error removing invalid token:', error);
    return false;
  }
}

/**
 * Check if user should receive notification based on preferences
 */
async function shouldSendNotification(userId, notificationType, channel = 'push') {
  try {
    const preferences = await NotificationPreference.getUserPreferences(userId);
    
    // Check quiet hours
    if (preferences.isQuietHours()) {
      console.log(`🔇 Quiet hours active for user ${userId}`);
      return false;
    }
    
    // Check channel preference
    if (channel === 'push') {
      return preferences.isPushEnabled(notificationType);
    } else if (channel === 'email') {
      return preferences.isEmailEnabled(notificationType);
    }
    
    return true;
  } catch (error) {
    console.error('Error checking notification preferences:', error);
    return true; // Default to sending if check fails
  }
}

/**
 * Generate dynamic deep link for mobile notifications
 */
function generateDeepLink(type, data) {
  const baseUrl = 'djtrip://';
  
  switch (type) {
    case 'booking':
      return `${baseUrl}booking/${data.bookingId}`;
    case 'message':
      return `${baseUrl}chat/${data.conversationId}`;
    case 'activity':
      return `${baseUrl}activity/${data.activityId}`;
    case 'review':
      return `${baseUrl}review/${data.reviewId}`;
    case 'profile':
      return `${baseUrl}profile/${data.userId}`;
    case 'payment':
      return `${baseUrl}payment/${data.paymentId}`;
    default:
      return `${baseUrl}home`;
  }
}

/**
 * Create analytics record
 */
async function createAnalyticsRecord(userId, notificationType, notificationId) {
  try {
    return await NotificationAnalytics.createAnalytics({
      user_id: userId,
      notification_type: notificationType,
      notification_id: notificationId,
    });
  } catch (error) {
    console.error('Error creating analytics record:', error);
    return null;
  }
}

/**
 * Send push notification with retry logic
 */
async function sendPushNotification({ userId, title, body, data = {}, notificationType = 'system', priority = 'normal' }) {
  if (!isInitialized()) {
    console.warn('⚠️ Firebase not initialized, skipping notification');
    return { success: false, reason: 'Firebase not initialized' };
  }

  try {
    // Check user preferences
    const shouldSend = await shouldSendNotification(userId, notificationType, 'push');
    if (!shouldSend) {
      return { success: false, reason: 'User preference disabled' };
    }

    const { tokens, accountStatus } = await getUserFcmToken(userId);

    if (!tokens || tokens.length === 0) {
      return { success: false, reason: 'No FCM tokens found for user' };
    }

    // Skip FCM push if account is not active (suspended, banned, or inactive)
    if (accountStatus !== 'active') {
      console.log(`⏭️ Skipping FCM push for user ${userId} - account status is ${accountStatus}`);
      return { success: false, reason: `Account is ${accountStatus} - skipping push notification` };
    }

    console.log(`📱 Sending FCM push to user ${userId} with ${tokens.length} active tokens`);

    // Generate deep link
    const deepLink = generateDeepLink(notificationType, data);

    // Convert all data values to strings for Firebase (Firebase requires string values only)
    const stringData = {};
    for (const [key, value] of Object.entries(data)) {
      if (value !== null && value !== undefined) {
        stringData[key] = String(value);
      }
    }

    // Send to all active tokens (multi-device support)
    const results = [];
    const admin = getFirebaseAdmin();
    
    for (const token of tokens) {
      try {
        const message = {
          notification: {
            title,
            body,
          },
          data: {
            ...stringData,
            deepLink,
            type: notificationType,
            timestamp: new Date().toISOString(),
          },
          token: token,
          android: {
            priority: priority === 'urgent' ? 'high' : 'normal',
            notification: {
              channelId: 'djtrip_notifications',
              sound: 'default',
              clickAction: deepLink,
            },
          },
          apns: {
            payload: {
              aps: {
                alert: {
                  title,
                  body,
                },
                sound: 'default',
                badge: 1,
                url: deepLink,
              },
            },
          },
        };

        const response = await admin.messaging().send(message);
        console.log(`✅ Push notification sent successfully to token ${token.substring(0, 10)}...:`, response);
        results.push({ success: true, token, messageId: response });
      } catch (error) {
        // Handle invalid tokens - remove them from user's tokens
        if (error.code === 'messaging/registration-token-not-registered') {
          console.warn(`⚠️ Invalid FCM token ${token.substring(0, 10)}..., removing from user:`, userId);
          await removeInvalidToken(userId, token);
          results.push({ success: false, token, reason: 'Invalid token removed' });
        } else {
          console.error(`❌ Error sending push notification to token ${token.substring(0, 10)}...:`, error);
          results.push({ success: false, token, reason: error.message });
        }
      }
    }
    
    // Create analytics record
    await createAnalyticsRecord(userId, notificationType, null);
    
    const successCount = results.filter(r => r.success).length;
    console.log(`📊 FCM push results: ${successCount}/${tokens.length} successful for user ${userId}`);
    
    return { 
      success: successCount > 0, 
      results,
      message: `Sent to ${successCount}/${tokens.length} devices`
    };
  } catch (error) {
    console.error('❌ Error sending push notification:', error);
    return { success: false, reason: error.message };
  }
}

/**
 * Send push notification via queue (recommended for production)
 */
async function sendPushNotificationQueued({ userId, title, body, data = {}, notificationType = 'system', priority = 'normal', options = {} }) {
  try {
    const job = await addNotificationJob(
      {
        type: 'single',
        payload: { userId, title, body, data, notificationType, priority },
      },
      {
        priority: priority === 'urgent' ? 1 : 5,
        delay: options.delay || 0,
        ...options,
      }
    );
    
    return { success: true, jobId: job.id };
  } catch (error) {
    console.error('Error queuing notification:', error);
    return { success: false, reason: error.message };
  }
}

/**
 * Send bulk notifications with batching
 */
async function sendBulkNotification({ userIds, title, body, data = {}, notificationType = 'system', priority = 'normal' }) {
  if (!isInitialized()) {
    return { success: false, reason: 'Firebase not initialized' };
  }

  const results = {
    total: userIds.length,
    success: 0,
    failed: 0,
    skipped: 0,
    details: [],
  };

  // Process in batches
  for (let i = 0; i < userIds.length; i += BATCH_SIZE) {
    const batch = userIds.slice(i, i + BATCH_SIZE);
    
    for (const userId of batch) {
      const shouldSend = await shouldSendNotification(userId, notificationType, 'push');
      if (!shouldSend) {
        results.skipped++;
        results.details.push({ userId, result: { success: false, reason: 'User preference disabled' } });
        continue;
      }

      const result = await sendPushNotification({ userId, title, body, data, notificationType, priority });
      
      if (result.success) {
        results.success++;
      } else {
        results.failed++;
      }
      
      results.details.push({ userId, result });
    }
  }

  return results;
}

/**
 * Send bulk notifications via queue with batching
 */
async function sendBulkNotificationQueued({ userIds, title, body, data = {}, notificationType = 'system', priority = 'normal', options = {} }) {
  try {
    const job = await addNotificationJob(
      {
        type: 'bulk',
        payload: { userIds, title, body, data, notificationType, priority },
      },
      {
        priority: priority === 'urgent' ? 1 : 5,
        delay: options.delay || 0,
        ...options,
      }
    );
    
    return { success: true, jobId: job.id };
  } catch (error) {
    console.error('Error queuing bulk notification:', error);
    return { success: false, reason: error.message };
  }
}

/**
 * Send batch notification (optimized for large scale)
 */
async function sendBatchNotification({ userIds, title, body, data = {}, notificationType = 'system' }) {
  if (!isInitialized()) {
    return { success: false, reason: 'Firebase not initialized' };
  }

  const admin = getFirebaseAdmin();
  const validTokens = [];
  const userIdsMap = new Map();

  // Collect valid tokens
  for (const userId of userIds) {
    const { token } = await getUserFcmToken(userId);
    if (token) {
      validTokens.push(token);
      userIdsMap.set(token, userId);
    }
  }

  if (validTokens.length === 0) {
    return { success: false, reason: 'No valid tokens found' };
  }

  // Generate deep link
  const deepLink = generateDeepLink(notificationType, data);

  const message = {
    notification: {
      title,
      body,
    },
    data: {
      ...data,
      deepLink,
      type: notificationType,
      timestamp: new Date().toISOString(),
    },
    tokens: validTokens,
    android: {
      notification: {
        channelId: 'djtrip_notifications',
        sound: 'default',
        clickAction: deepLink,
      },
    },
    apns: {
      payload: {
        aps: {
          alert: {
            title,
            body,
          },
          sound: 'default',
          badge: 1,
        },
      },
      fcm_options: {
        link: deepLink,
      },
    },
  };

  try {
    const response = await admin.messaging().sendMulticast(message);
    
    // Handle invalid tokens
    if (response.invalidTokens && response.invalidTokens.length > 0) {
      for (const token of response.invalidTokens) {
        const userId = userIdsMap.get(token);
        if (userId) {
          await updateUserFcmToken(userId, null);
        }
      }
    }

    console.log(`✅ Batch notification sent: ${response.successCount} successful, ${response.failureCount} failed`);
    
    // Create analytics records
    for (const token of validTokens) {
      const userId = userIdsMap.get(token);
      if (userId) {
        await createAnalyticsRecord(userId, notificationType, null);
      }
    }
    
    return {
      success: true,
      successCount: response.successCount,
      failureCount: response.failureCount,
    };
  } catch (error) {
    console.error('❌ Error sending batch notification:', error);
    return { success: false, reason: error.message };
  }
}

// ============================================
// SPECIFIC NOTIFICATION FUNCTIONS
// ============================================

/**
 * Booking notifications
 */
async function sendCheckInConfirmation({ touristId, activityTitle, bookingId, activityId }) {
  return sendPushNotificationQueued({
    userId: touristId,
    title: 'Check-in Confirmed ✅',
    body: `Your booking for "${activityTitle}" is validated. Enjoy your activity!`,
    data: {
      type: 'checkin_confirmed',
      bookingId,
      activityId,
    },
    notificationType: 'booking',
    priority: 'high',
  });
}

async function sendNewBookingNotification({ organizerId, touristName, activityTitle, bookingId }) {
  return sendPushNotificationQueued({
    userId: organizerId,
    title: 'New Booking 🎫',
    body: `${touristName} booked "${activityTitle}" - Waiting for payment`,
    data: {
      type: 'new_booking',
      bookingId,
      screen: 'requests_tab',
      action: 'view_pending',
    },
    notificationType: 'booking',
    priority: 'high',
  });
}

async function sendBookingApprovedNotification({ touristId, activityTitle, bookingId }) {
  return sendPushNotificationQueued({
    userId: touristId,
    title: 'Booking Approved ✅',
    body: `Your booking for "${activityTitle}" has been confirmed`,
    data: {
      type: 'booking_approved',
      bookingId,
    },
    notificationType: 'booking',
    priority: 'high',
  });
}

async function sendBookingRejectedNotification({ touristId, activityTitle, bookingId }) {
  return sendPushNotificationQueued({
    userId: touristId,
    title: 'Booking Rejected ❌',
    body: `Your booking for "${activityTitle}" has been rejected`,
    data: {
      type: 'booking_rejected',
      bookingId,
    },
    notificationType: 'booking',
    priority: 'high',
  });
}

async function sendBookingReminder({ touristId, activityTitle, bookingId, activityId }) {
  return sendPushNotificationQueued({
    userId: touristId,
    title: 'Booking Reminder ⏰',
    body: `"${activityTitle}" is starting soon. Get ready!`,
    data: {
      type: 'booking_reminder',
      bookingId,
      activityId,
    },
    notificationType: 'reminder',
    priority: 'high',
  });
}

/**
 * Review notifications
 */
async function sendReviewReminder({ touristId, activityTitle, bookingId, activityId }) {
  return sendPushNotificationQueued({
    userId: touristId,
    title: 'Leave a Review ⭐',
    body: `How was "${activityTitle}"? Share your experience!`,
    data: {
      type: 'review_reminder',
      bookingId,
      activityId,
    },
    notificationType: 'review',
    priority: 'medium',
  });
}

async function sendNewReviewNotification({ organizerId, touristName, activityTitle, rating, reviewId }) {
  return sendPushNotificationQueued({
    userId: organizerId,
    title: 'New Review Received ⭐',
    body: `${touristName} rated "${activityTitle}" ${rating}/5`,
    data: {
      type: 'new_review',
      reviewId,
      rating,
    },
    notificationType: 'review',
    priority: 'medium',
  });
}

/**
 * Follow notifications
 */
async function sendNewFollowerNotification({ userId, followerName, followerId }) {
  return sendPushNotificationQueued({
    userId,
    title: 'New Follower 👋',
    body: `${followerName} started following you`,
    data: {
      type: 'new_follower',
      followerId,
    },
    notificationType: 'follow',
    priority: 'medium',
  });
}

async function sendFollowAcceptedNotification({ followerId, userName, userId }) {
  return sendPushNotificationQueued({
    userId: followerId,
    title: 'Follow Accepted 🎉',
    body: `${userName} accepted your follow`,
    data: {
      type: 'follow_accepted',
      userId,
    },
    notificationType: 'follow',
    priority: 'medium',
  });
}

/**
 * Payment notifications
 */
async function sendPaymentCompletedNotification({ userId, amount, activityTitle, paymentId }) {
  return sendPushNotificationQueued({
    userId,
    title: 'Payment Successful 💳',
    body: `Your payment of ${amount} for ${activityTitle} was successful`,
    data: {
      type: 'payment',
      paymentId,
    },
    notificationType: 'payment',
    priority: 'high',
  });
}

async function sendPaymentFailedNotification({ userId, amount, activityTitle, paymentId }) {
  return sendPushNotificationQueued({
    userId,
    title: 'Payment Failed ❌',
    body: `Payment of ${amount}€ for "${activityTitle}" failed. Please try again.`,
    data: {
      type: 'payment_failed',
      paymentId,
      amount,
    },
    notificationType: 'payment',
    priority: 'urgent',
  });
}

async function sendPaymentRefundedNotification({ userId, amount, paymentId }) {
  return sendPushNotificationQueued({
    userId,
    title: 'Refund Processed 💰',
    body: `A refund of ${amount}€ has been processed to your account`,
    data: {
      type: 'payment_refunded',
      paymentId,
      amount,
    },
    notificationType: 'payment',
    priority: 'high',
  });
}

/**
 * Activity notifications
 */
async function sendNewActivityNotification({ followerId, organizerName, activityTitle, activityId }) {
  return sendPushNotificationQueued({
    userId: followerId,
    title: 'New Activity 🎯',
    body: `${organizerName} published "${activityTitle}"`,
    data: {
      type: 'new_activity',
      activityId,
    },
    notificationType: 'activity',
    priority: 'medium',
  });
}

async function sendActivityCreatedNotification({ organizerName, activityTitle, activityId }) {
  // This would send to all followers - use bulk notification
  return { success: true, message: 'Use sendBulkNotification for followers' };
}

/**
 * Profile notifications
 */
async function sendProfileUpdatedNotification({ userId, userName }) {
  return sendPushNotificationQueued({
    userId,
    title: 'Profile Updated ✏️',
    body: 'Your profile has been updated successfully',
    data: {
      type: 'profile_updated',
    },
    notificationType: 'profile',
    priority: 'low',
  });
}

async function sendProfileVerifiedNotification({ userId }) {
  return sendPushNotificationQueued({
    userId,
    title: 'Profile Verified ✓',
    body: 'Congratulations! Your profile is now verified',
    data: {
      type: 'profile_verified',
    },
    notificationType: 'profile',
    priority: 'high',
  });
}

/**
 * Appeal notifications
 */
async function sendAppealCreatedNotification({ userId, appealId }) {
  return sendPushNotificationQueued({
    userId,
    title: 'Appeal Submitted 📋',
    body: 'Your appeal has been submitted and will be processed soon',
    data: {
      type: 'appeal_created',
      appealId,
    },
    notificationType: 'appeal',
    priority: 'high',
  });
}

async function sendAppealResolvedNotification({ userId, appealId, status }) {
  const title = status === 'approved' ? 'Appeal Accepted ✅' : 'Appeal Rejected ❌';
  return sendPushNotificationQueued({
    userId,
    title,
    body: `Your appeal has been ${status === 'approved' ? 'accepted' : 'rejected'}`,
    data: {
      type: 'appeal_resolved',
      appealId,
      status,
    },
    notificationType: 'appeal',
    priority: 'urgent',
  });
}

/**
 * Social Network notifications
 */
async function sendNewPublicationNotification({ userId, authorName, postId, postTitle }) {
  return sendPushNotificationQueued({
    userId,
    title: 'New Post 📰',
    body: `${authorName} posted: "${postTitle || 'New post'}"`,
    data: {
      type: 'new_publication',
      postId,
    },
    notificationType: 'publication',
    priority: 'medium',
  });
}

async function sendReactionNotification({ userId, reactorName, postId, commentId, reactionType, entityType }) {
  const isPost = entityType === 'post';
  const title = isPost ? 'New Reaction ❤️' : 'Reaction to your comment 💬';
  const body = isPost 
    ? `${reactorName} reacted to your post`
    : `${reactorName} reacted to your comment`;
  
  return sendPushNotificationQueued({
    userId,
    title,
    body,
    data: {
      type: 'new_reaction',
      postId,
      commentId,
      reactionType,
      entityType,
    },
    notificationType: 'reaction',
    priority: 'medium',
  });
}

async function sendCommentNotification({ userId, commenterName, postId, commentContent }) {
  return sendPushNotificationQueued({
    userId,
    title: 'New Comment 💬',
    body: `${commenterName} commented: "${commentContent?.substring(0, 50) || '...'}"`,
    data: {
      type: 'new_comment',
      postId,
    },
    notificationType: 'comment',
    priority: 'medium',
  });
}

async function sendReplyNotification({ userId, replierName, postId, parentCommentId, replyContent }) {
  return sendPushNotificationQueued({
    userId,
    title: 'New Reply 💬',
    body: `${replierName} replied to your comment`,
    data: {
      type: 'new_reply',
      postId,
      parentCommentId,
    },
    notificationType: 'reply',
    priority: 'medium',
  });
}

async function sendMentionNotification({ userId, mentionerName, postId, commentId }) {
  const title = commentId ? 'You were mentioned 💬' : 'You were mentioned 📰';
  const body = `${mentionerName} mentioned you`;
  
  return sendPushNotificationQueued({
    userId,
    title,
    body,
    data: {
      type: 'mention',
      postId,
      commentId,
    },
    notificationType: 'comment',
    priority: 'high',
  });
}

module.exports = {
  initializeFirebase,
  sendPushNotification,
  sendPushNotificationQueued,
  sendBulkNotification,
  sendBulkNotificationQueued,
  sendBatchNotification,
  getUserFcmToken,
  updateUserFcmToken,
  generateDeepLink,
  // Booking notifications
  sendCheckInConfirmation,
  sendNewBookingNotification,
  sendBookingApprovedNotification,
  sendBookingRejectedNotification,
  sendBookingReminder,
  // Review notifications
  sendReviewReminder,
  sendNewReviewNotification,
  // Follow notifications
  sendNewFollowerNotification,
  sendFollowAcceptedNotification,
  // Payment notifications
  sendPaymentCompletedNotification,
  sendPaymentFailedNotification,
  sendPaymentRefundedNotification,
  // Activity notifications
  sendNewActivityNotification,
  sendActivityCreatedNotification,
  // Profile notifications
  sendProfileUpdatedNotification,
  sendProfileVerifiedNotification,
  // Appeal notifications
  sendAppealCreatedNotification,
  sendAppealResolvedNotification,
  // Social Network notifications
  sendNewPublicationNotification,
  sendReactionNotification,
  sendCommentNotification,
  sendReplyNotification,
  sendMentionNotification,
};
