const notificationAnalyticsService = require('../services/notificationAnalyticsService');

/**
 * Notification Analytics Controller
 * Endpoints for notification analytics and reporting
 */

// GET /notifications/analytics/report
exports.getAnalyticsReport = async (req, res) => {
  try {
    const { startDate, endDate, type } = req.query;
    
    const start = startDate ? new Date(startDate) : new Date(Date.now() - 30 * 24 * 60 * 60 * 1000); // Default: 30 days ago
    const end = endDate ? new Date(endDate) : new Date();
    
    let report;
    
    if (type) {
      // Get specific type analytics
      const deliveryRate = await notificationAnalyticsService.getDeliveryRate(start, end, type);
      const openRate = await notificationAnalyticsService.getOpenRate(start, end, type);
      const clickRate = await notificationAnalyticsService.getClickRate(start, end, type);
      
      report = {
        type,
        deliveryRate,
        openRate,
        clickRate,
        period: { startDate: start, endDate: end },
      };
    } else {
      // Get comprehensive report
      report = await notificationAnalyticsService.getAnalyticsReport(start, end);
    }
    
    res.status(200).json({
      success: true,
      report,
    });
  } catch (error) {
    console.error('Error getting analytics report:', error);
    res.status(500).json({
      success: false,
      message: 'Error retrieving analytics report',
      error: error.message,
    });
  }
};

// GET /notifications/analytics/user-history
exports.getUserHistory = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { type, status, limit, skip } = req.query;
    
    const history = await notificationAnalyticsService.getUserHistory(userId, {
      type,
      status,
      limit: parseInt(limit) || 50,
      skip: parseInt(skip) || 0,
    });
    
    res.status(200).json({
      success: true,
      history,
    });
  } catch (error) {
    console.error('Error getting user history:', error);
    res.status(500).json({
      success: false,
      message: 'Error retrieving user history',
      error: error.message,
    });
  }
};

// POST /notifications/analytics/track/:analyticsId/open
exports.trackOpen = async (req, res) => {
  try {
    const { analyticsId } = req.params;
    
    await notificationAnalyticsService.trackOpen(analyticsId);
    
    res.status(200).json({
      success: true,
      message: 'Open tracked successfully',
    });
  } catch (error) {
    console.error('Error tracking open:', error);
    res.status(500).json({
      success: false,
      message: 'Error tracking open',
      error: error.message,
    });
  }
};

// POST /notifications/analytics/track/:analyticsId/click
exports.trackClick = async (req, res) => {
  try {
    const { analyticsId } = req.params;
    const { action } = req.body;
    
    await notificationAnalyticsService.trackClick(analyticsId, action);
    
    res.status(200).json({
      success: true,
      message: 'Click tracked successfully',
    });
  } catch (error) {
    console.error('Error tracking click:', error);
    res.status(500).json({
      success: false,
      message: 'Error tracking click',
      error: error.message,
    });
  }
};

// GET /notifications/analytics/summary
exports.getSummary = async (req, res) => {
  try {
    const { startDate, endDate } = req.query;
    
    const start = startDate ? new Date(startDate) : new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    const end = endDate ? new Date(endDate) : new Date();
    
    const summary = await notificationAnalyticsService.getSummaryByType(start, end);
    
    res.status(200).json({
      success: true,
      summary,
      period: { startDate: start, endDate: end },
    });
  } catch (error) {
    console.error('Error getting summary:', error);
    res.status(500).json({
      success: false,
      message: 'Error retrieving summary',
      error: error.message,
    });
  }
};
