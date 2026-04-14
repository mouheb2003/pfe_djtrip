const express = require('express');
const router = express.Router();
const {
  getUserPreferences,
  updateUserPreferences,
  togglePushNotification,
  toggleEmailNotification,
  toggleAllPushNotifications,
  toggleAllEmailNotifications,
  setQuietHours,
  updateDeviceSettings,
} = require('../controllers/notificationPreferences');
const { verifyToken } = require('../middleware/auth');

// All routes require authentication
router.use(verifyToken);

// GET /notifications/preferences - Get user preferences
router.get('/preferences', getUserPreferences);

// PUT /notifications/preferences - Update user preferences
router.put('/preferences', updateUserPreferences);

// PUT /notifications/preferences/push/:type - Toggle push notification for specific type
router.put('/preferences/push/:type', togglePushNotification);

// PUT /notifications/preferences/email/:type - Toggle email notification for specific type
router.put('/preferences/email/:type', toggleEmailNotification);

// PUT /notifications/preferences/all-push - Toggle all push notifications
router.put('/preferences/all-push', toggleAllPushNotifications);

// PUT /notifications/preferences/all-email - Toggle all email notifications
router.put('/preferences/all-email', toggleAllEmailNotifications);

// PUT /notifications/preferences/quiet-hours - Set quiet hours
router.put('/preferences/quiet-hours', setQuietHours);

// PUT /notifications/preferences/device/:device - Update device settings
router.put('/preferences/device/:device', updateDeviceSettings);

module.exports = router;
