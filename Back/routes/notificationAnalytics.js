const express = require('express');
const router = express.Router();
const {
  getAnalyticsReport,
  getUserHistory,
  trackOpen,
  trackClick,
  getSummary,
} = require('../controllers/notificationAnalytics');
const { verifyToken } = require('../middleware/auth');

// All routes require authentication
router.use(verifyToken);

// GET /notifications/analytics/report - Get analytics report
router.get('/analytics/report', getAnalyticsReport);

// GET /notifications/analytics/user-history - Get user notification history
router.get('/analytics/user-history', getUserHistory);

// GET /notifications/analytics/summary - Get analytics summary
router.get('/analytics/summary', getSummary);

// POST /notifications/analytics/track/:analyticsId/open - Track notification open
router.post('/analytics/track/:analyticsId/open', trackOpen);

// POST /notifications/analytics/track/:analyticsId/click - Track notification click
router.post('/analytics/track/:analyticsId/click', trackClick);

module.exports = router;
