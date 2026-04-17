const { initializeFirebase: initFirebase, getFirebaseAdmin, isInitialized } = require('../config/firebase');
const User = require('../models/user');

/**
 * Service de gestion des notifications push via Firebase Cloud Messaging
 * Production-ready avec gestion d'erreurs et retry
 */

/**
 * Initialise Firebase Admin SDK
 * Doit être appelé au démarrage de l'application
 * Utilise FIREBASE_KEY_BASE64 environment variable
 */
function initializeFirebase() {
  try {
    initFirebase();
  } catch (error) {
    console.error('❌ Failed to initialize Firebase Admin SDK:', error.message);
    // Ne pas crasher l'app si Firebase n'est pas configuré
  }
}

/**
 * Récupère le token FCM d'un utilisateur
 * @param {string} userId - ID de l'utilisateur
 * @returns {Promise<string|null>} Token FCM ou null
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
    console.error('Error fetching user FCM token:', error);
    return { tokens: [], accountStatus: 'inactive' };
  }
}

/**
 * Met à jour le token FCM d'un utilisateur
 * @param {string} userId - ID de l'utilisateur
 * @param {string} fcmToken - Nouveau token FCM
 * @returns {Promise<boolean>}
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
 * Envoie une notification push à un utilisateur
 * @param {Object} payload - Payload de la notification
 * @param {string} payload.userId - ID de l'utilisateur destinataire
 * @param {string} payload.title - Titre de la notification
 * @param {string} payload.body - Corps de la notification
 * @param {Object} payload.data - Données supplémentaires
 * @returns {Promise<Object>} Résultat de l'envoi
 */
async function sendPushNotification({ userId, title, body, data = {} }) {
  if (!isInitialized()) {
    console.warn('⚠️ Firebase not initialized, skipping notification');
    return { success: false, reason: 'Firebase not initialized' };
  }

  try {
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

    for (const fcmToken of tokens) {
      try {
        const message = {
          notification: {
            title,
            body,
          },
          data: {
            ...stringData,
            timestamp: new Date().toISOString(),
          },
          token: fcmToken,
        };

        const response = await admin.messaging().send(message);
        console.log(`✅ Push notification sent successfully to token ${fcmToken.substring(0, 10)}...:`, response);
        results.push({ success: true, token: fcmToken, messageId: response });
      } catch (error) {
        // Handle invalid tokens - remove them from user's tokens
        if (error.code === 'messaging/registration-token-not-registered') {
          console.warn(`⚠️ Invalid FCM token ${fcmToken.substring(0, 10)}..., removing from user:`, userId);
          await removeInvalidToken(userId, fcmToken);
          results.push({ success: false, token: fcmToken, reason: 'Invalid token removed' });
        } else {
          console.error(`❌ Error sending push notification to token ${fcmToken.substring(0, 10)}...:`, error);
          results.push({ success: false, token: fcmToken, reason: error.message });
        }
      }
    }

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
 * Envoie une notification à plusieurs utilisateurs
 * @param {Array<string>} userIds - Liste des IDs utilisateurs
 * @param {string} title - Titre de la notification
 * @param {string} body - Corps de la notification
 * @param {Object} data - Données supplémentaires
 * @returns {Promise<Object>} Résultat de l'envoi
 */
async function sendBulkNotification({ userIds, title, body, data = {} }) {
  if (!isInitialized()) {
    return { success: false, reason: 'Firebase not initialized' };
  }

  const results = {
    total: userIds.length,
    success: 0,
    failed: 0,
    details: [],
  };

  for (const userId of userIds) {
    const result = await sendPushNotification({ userId, title, body, data });
    
    if (result.success) {
      results.success++;
    } else {
      results.failed++;
    }
    
    results.details.push({ userId, result });
  }

  return results;
}

/**
 * Notification spécifique pour check-in confirmé
 * @param {string} touristId - ID du touriste
 * @param {string} activityTitle - Titre de l'activité
 * @param {string} bookingId - ID du booking
 * @param {string} activityId - ID de l'activité
 * @returns {Promise<Object>}
 */
async function sendCheckInConfirmation({ touristId, activityTitle, bookingId, activityId }) {
  return sendPushNotification({
    userId: touristId,
    title: 'Check-in confirmé ✅',
    body: `Votre réservation pour "${activityTitle}" est validée. Bonne activité !`,
    data: {
      type: 'checkin_confirmed',
      bookingId,
      activityId,
    },
  });
}

/**
 * Notification pour nouveau booking
 * @param {string} organizerId - ID de l'organisateur
 * @param {string} touristName - Nom du touriste
 * @param {string} activityTitle - Titre de l'activité
 * @param {string} bookingId - ID du booking
 * @returns {Promise<Object>}
 */
async function sendNewBookingNotification({ organizerId, touristName, activityTitle, bookingId }) {
  return sendPushNotification({
    userId: organizerId,
    title: 'Nouvelle réservation 🎫',
    body: `${touristName} a réservé "${activityTitle}"`,
    data: {
      type: 'new_booking',
      bookingId,
      screen: 'requests_tab',
      action: 'view_pending',
    },
  });
}

/**
 * Notification pour booking approuvé
 * @param {string} touristId - ID du touriste
 * @param {string} activityTitle - Titre de l'activité
 * @param {string} bookingId - ID du booking
 * @returns {Promise<Object>}
 */
async function sendBookingApprovedNotification({ touristId, activityTitle, bookingId }) {
  return sendPushNotification({
    userId: touristId,
    title: 'Réservation approuvée ✅',
    body: `Votre réservation pour "${activityTitle}" a été confirmée`,
    data: {
      type: 'booking_approved',
      bookingId,
    },
  });
}

/**
 * Notification pour booking rejeté
 * @param {string} touristId - ID du touriste
 * @param {string} activityTitle - Titre de l'activité
 * @param {string} bookingId - ID du booking
 * @returns {Promise<Object>}
 */
async function sendBookingRejectedNotification({ touristId, activityTitle, bookingId }) {
  return sendPushNotification({
    userId: touristId,
    title: 'Réservation refusée ❌',
    body: `Votre réservation pour "${activityTitle}" a été refusée`,
    data: {
      type: 'booking_rejected',
      bookingId,
    },
  });
}

/**
 * Notification de rappel de review
 * @param {string} touristId - ID du touriste
 * @param {string} activityTitle - Titre de l'activité
 * @param {string} bookingId - ID du booking
 * @returns {Promise<Object>}
 */
async function sendReviewReminder({ touristId, activityTitle, bookingId }) {
  return sendPushNotification({
    userId: touristId,
    title: 'Donnez votre avis ⭐',
    body: `Comment s'est passée "${activityTitle}" ? Laissez un review !`,
    data: {
      type: 'review_reminder',
      bookingId,
    },
  });
}

/**
 * Notification pour nouvelle activité créée par un organisateur
 * @param {string} organizerName - Nom de l'organisateur
 * @param {string} activityTitle - Titre de l'activité
 * @returns {Promise<Object>}
 */
async function sendNewActivityNotification({ organizerName, activityTitle }) {
  // Pour l'instant, nous n'envoyons pas de notification globale pour les nouvelles activités
  // Cela pourrait être implémenté plus tard avec un système de followers
  return { success: true, message: 'Activity notification not implemented yet' };
}

module.exports = {
  initializeFirebase,
  sendPushNotification,
  sendBulkNotification,
  getUserFcmToken,
  updateUserFcmToken,
  sendCheckInConfirmation,
  sendNewBookingNotification,
  sendBookingApprovedNotification,
  sendBookingRejectedNotification,
  sendReviewReminder,
  sendNewActivityNotification,
};
