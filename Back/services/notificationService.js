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
    const user = await User.findById(userId).select('fcmToken');
    return user?.fcmToken || null;
  } catch (error) {
    console.error('Error fetching user FCM token:', error);
    return null;
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
    const fcmToken = await getUserFcmToken(userId);

    if (!fcmToken) {
      return { success: false, reason: 'No FCM token found for user' };
    }

    const message = {
      notification: {
        title,
        body,
      },
      data: {
        ...data,
        timestamp: new Date().toISOString(),
      },
      token: fcmToken,
      android: {
        priority: 'high',
        notification: {
          channelId: 'djtrip_notifications',
          sound: 'default',
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
      },
    };

    const admin = getFirebaseAdmin();
    const response = await admin.messaging().send(message);

    console.log('✅ Push notification sent successfully:', response);
    return { success: true, messageId: response };
  } catch (error) {
    // Gérer les tokens invalides
    if (error.code === 'messaging/registration-token-not-registered') {
      console.warn('⚠️ Invalid FCM token, removing from user:', userId);
      await updateUserFcmToken(userId, null);
      return { success: false, reason: 'Invalid token removed' };
    }

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
};
