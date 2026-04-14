const NotificationPreference = require('../models/notificationPreference');
const notificationPreferencesService = require('../services/notificationPreferencesService');

/**
 * Notification Preferences Controller
 * Endpoints for managing user notification preferences
 */

// GET /notifications/preferences
exports.getUserPreferences = async (req, res) => {
  try {
    const userId = req.user.userId;
    
    const preferences = await notificationPreferencesService.getUserPreferences(userId);
    
    res.status(200).json({
      success: true,
      preferences,
    });
  } catch (error) {
    console.error('Error getting user preferences:', error);
    res.status(500).json({
      success: false,
      message: 'Error retrieving preferences',
      error: error.message,
    });
  }
};

// PUT /notifications/preferences
exports.updateUserPreferences = async (req, res) => {
  try {
    const userId = req.user.userId;
    const updates = req.body;
    
    const preferences = await notificationPreferencesService.updateUserPreferences(
      userId,
      updates
    );
    
    res.status(200).json({
      success: true,
      preferences,
      message: 'Preferences updated successfully',
    });
  } catch (error) {
    console.error('Error updating user preferences:', error);
    res.status(500).json({
      success: false,
      message: 'Error updating preferences',
      error: error.message,
    });
  }
};

// PUT /notifications/preferences/push/:type
exports.togglePushNotification = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { type } = req.params;
    const { enabled } = req.body;
    
    const preferences = await notificationPreferencesService.togglePushNotification(
      userId,
      type,
      enabled
    );
    
    res.status(200).json({
      success: true,
      preferences,
      message: `Push notifications for ${type} ${enabled ? 'enabled' : 'disabled'}`,
    });
  } catch (error) {
    console.error('Error toggling push notification:', error);
    res.status(500).json({
      success: false,
      message: 'Error toggling push notification',
      error: error.message,
    });
  }
};

// PUT /notifications/preferences/email/:type
exports.toggleEmailNotification = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { type } = req.params;
    const { enabled } = req.body;
    
    const preferences = await notificationPreferencesService.toggleEmailNotification(
      userId,
      type,
      enabled
    );
    
    res.status(200).json({
      success: true,
      preferences,
      message: `Email notifications for ${type} ${enabled ? 'enabled' : 'disabled'}`,
    });
  } catch (error) {
    console.error('Error toggling email notification:', error);
    res.status(500).json({
      success: false,
      message: 'Error toggling email notification',
      error: error.message,
    });
  }
};

// PUT /notifications/preferences/all-push
exports.toggleAllPushNotifications = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { enabled } = req.body;
    
    const preferences = await notificationPreferencesService.toggleAllPushNotifications(
      userId,
      enabled
    );
    
    res.status(200).json({
      success: true,
      preferences,
      message: `All push notifications ${enabled ? 'enabled' : 'disabled'}`,
    });
  } catch (error) {
    console.error('Error toggling all push notifications:', error);
    res.status(500).json({
      success: false,
      message: 'Error toggling all push notifications',
      error: error.message,
    });
  }
};

// PUT /notifications/preferences/all-email
exports.toggleAllEmailNotifications = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { enabled } = req.body;
    
    const preferences = await notificationPreferencesService.toggleAllEmailNotifications(
      userId,
      enabled
    );
    
    res.status(200).json({
      success: true,
      preferences,
      message: `All email notifications ${enabled ? 'enabled' : 'disabled'}`,
    });
  } catch (error) {
    console.error('Error toggling all email notifications:', error);
    res.status(500).json({
      success: false,
      message: 'Error toggling all email notifications',
      error: error.message,
    });
  }
};

// PUT /notifications/preferences/quiet-hours
exports.setQuietHours = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { enabled, start, end, timezone } = req.body;
    
    const preferences = await notificationPreferencesService.setQuietHours(userId, {
      enabled,
      start,
      end,
      timezone,
    });
    
    res.status(200).json({
      success: true,
      preferences,
      message: 'Quiet hours updated successfully',
    });
  } catch (error) {
    console.error('Error setting quiet hours:', error);
    res.status(500).json({
      success: false,
      message: 'Error setting quiet hours',
      error: error.message,
    });
  }
};

// PUT /notifications/preferences/device/:device
exports.updateDeviceSettings = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { device } = req.params;
    const settings = req.body;
    
    const preferences = await notificationPreferencesService.updateDeviceSettings(
      userId,
      device,
      settings
    );
    
    res.status(200).json({
      success: true,
      preferences,
      message: `Device settings for ${device} updated successfully`,
    });
  } catch (error) {
    console.error('Error updating device settings:', error);
    res.status(500).json({
      success: false,
      message: 'Error updating device settings',
      error: error.message,
    });
  }
};
