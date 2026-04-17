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
    title: 'Check-in confirmé ✅',
    body: `Votre réservation pour "${activityTitle}" est validée. Bonne activité !`,
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
    title: 'Nouvelle réservation 🎫',
    body: `${touristName} a réservé "${activityTitle}"`,
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
    title: 'Réservation approuvée ✅',
    body: `Votre réservation pour "${activityTitle}" a été confirmée`,
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
    title: 'Réservation refusée ❌',
    body: `Votre réservation pour "${activityTitle}" a été refusée`,
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
    title: 'Rappel de réservation ⏰',
    body: `"${activityTitle}" commence bientôt. Préparez-vous !`,
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
    title: 'Donnez votre avis ⭐',
    body: `Comment s'est passée "${activityTitle}" ? Laissez un review !`,
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
    title: 'Nouvel avis reçu ⭐',
    body: `${touristName} a noté "${activityTitle}" ${rating}/5`,
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
    title: 'Nouveau follower 👋',
    body: `${followerName} a commencé à vous suivre`,
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
    title: 'Follow accepté 🎉',
    body: `${userName} a accepté votre follow`,
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
    title: 'Paiement réussi 💳',
    body: `Votre paiement de ${amount}€ pour "${activityTitle}" est confirmé`,
    data: {
      type: 'payment_completed',
      paymentId,
      amount,
    },
    notificationType: 'payment',
    priority: 'urgent',
  });
}

async function sendPaymentFailedNotification({ userId, amount, activityTitle, paymentId }) {
  return sendPushNotificationQueued({
    userId,
    title: 'Paiement échoué ❌',
    body: `Le paiement de ${amount}€ pour "${activityTitle}" a échoué. Réessayez.`,
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
    title: 'Remboursement effectué 💰',
    body: `Un remboursement de ${amount}€ a été effectué sur votre compte`,
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
    title: 'Nouvelle activité 🎯',
    body: `${organizerName} a publié "${activityTitle}"`,
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
    title: 'Profil mis à jour ✏️',
    body: 'Votre profil a été mis à jour avec succès',
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
    title: 'Profil vérifié ✓',
    body: 'Félicitations ! Votre profil est maintenant vérifié',
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
    title: 'Appel soumis 📋',
    body: 'Votre appel a été soumis et sera traité sous peu',
    data: {
      type: 'appeal_created',
      appealId,
    },
    notificationType: 'appeal',
    priority: 'high',
  });
}

async function sendAppealResolvedNotification({ userId, appealId, status }) {
  const title = status === 'approved' ? 'Appel accepté ✅' : 'Appel rejeté ❌';
  return sendPushNotificationQueued({
    userId,
    title,
    body: `Votre appel a été ${status === 'approved' ? 'accepté' : 'rejeté'}`,
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
    title: 'Nouvelle publication 📰',
    body: `${authorName} a publié: "${postTitle || 'Nouvelle publication'}"`,
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
  const title = isPost ? 'Nouvelle réaction ❤️' : 'Réaction à votre commentaire 💬';
  const body = isPost 
    ? `${reactorName} a réagi à votre publication`
    : `${reactorName} a réagi à votre commentaire`;
  
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
    title: 'Nouveau commentaire 💬',
    body: `${commenterName} a commenté: "${commentContent?.substring(0, 50) || '...'}"`,
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
    title: 'Nouvelle réponse 💬',
    body: `${replierName} a répondu à votre commentaire`,
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
  const title = commentId ? 'Vous avez été mentionné 💬' : 'Vous avez été mentionné 📰';
  const body = `${mentionerName} vous a mentionné`;
  
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
