const NotificationPreference = require('../models/notificationPreference');

/**
 * Notification Preferences Service
 * Manages user notification preferences
 */

/**
 * Get user notification preferences
 */
async function getUserPreferences(userId) {
  return await NotificationPreference.getUserPreferences(userId);
}

/**
 * Update user notification preferences
 */
async function updateUserPreferences(userId, updates) {
  return await NotificationPreference.updateUserPreferences(userId, updates);
}

/**
 * Toggle push notifications for a specific type
 */
async function togglePushNotification(userId, notificationType, enabled) {
  const updates = {};
  updates[`preferences.${notificationType}.push`] = enabled;
  return await NotificationPreference.updateUserPreferences(userId, updates);
}

/**
 * Toggle email notifications for a specific type
 */
async function toggleEmailNotification(userId, notificationType, enabled) {
  const updates = {};
  updates[`preferences.${notificationType}.email`] = enabled;
  return await NotificationPreference.updateUserPreferences(userId, updates);
}

/**
 * Enable/disable all push notifications
 */
async function toggleAllPushNotifications(userId, enabled) {
  return await NotificationPreference.updateUserPreferences(userId, {
    push_enabled: enabled,
  });
}

/**
 * Enable/disable all email notifications
 */
async function toggleAllEmailNotifications(userId, enabled) {
  return await NotificationPreference.updateUserPreferences(userId, {
    email_enabled: enabled,
  });
}

/**
 * Set quiet hours
 */
async function setQuietHours(userId, { enabled, start, end, timezone }) {
  return await NotificationPreference.updateUserPreferences(userId, {
    quiet_hours: {
      enabled,
      start: start || '22:00',
      end: end || '08:00',
      timezone: timezone || 'UTC',
    },
  });
}

/**
 * Update device settings
 */
async function updateDeviceSettings(userId, device, settings) {
  const updates = {};
  updates[`device_settings.${device}`] = settings;
  return await NotificationPreference.updateUserPreferences(userId, updates);
}

module.exports = {
  getUserPreferences,
  updateUserPreferences,
  togglePushNotification,
  toggleEmailNotification,
  toggleAllPushNotifications,
  toggleAllEmailNotifications,
  setQuietHours,
  updateDeviceSettings,
};
