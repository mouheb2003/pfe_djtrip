const NotificationAnalytics = require('../models/notificationAnalytics');

/**
 * Notification Analytics Service
 * Tracks and analyzes notification performance
 */

/**
 * Get delivery rate for a period
 */
async function getDeliveryRate(startDate, endDate, notificationType = null) {
  return await NotificationAnalytics.getDeliveryRate(startDate, endDate, notificationType);
}

/**
 * Get open rate for a period
 */
async function getOpenRate(startDate, endDate, notificationType = null) {
  return await NotificationAnalytics.getOpenRate(startDate, endDate, notificationType);
}

/**
 * Get click rate for a period
 */
async function getClickRate(startDate, endDate, notificationType = null) {
  return await NotificationAnalytics.getClickRate(startDate, endDate, notificationType);
}

/**
 * Get analytics summary by notification type
 */
async function getSummaryByType(startDate, endDate) {
  return await NotificationAnalytics.getSummaryByType(startDate, endDate);
}

/**
 * Get user notification history
 */
async function getUserHistory(userId, options = {}) {
  return await NotificationAnalytics.getUserHistory(userId, options);
}

/**
 * Track notification delivery
 */
async function trackDelivery(analyticsId, status, error = null) {
  try {
    const analytics = await NotificationAnalytics.findById(analyticsId);
    if (analytics) {
      await analytics.recordDelivery(status, error);
    }
  } catch (error) {
    console.error('Error tracking delivery:', error);
  }
}

/**
 * Track notification open
 */
async function trackOpen(analyticsId) {
  try {
    const analytics = await NotificationAnalytics.findById(analyticsId);
    if (analytics) {
      await analytics.recordOpen();
    }
  } catch (error) {
    console.error('Error tracking open:', error);
  }
}

/**
 * Track notification click
 */
async function trackClick(analyticsId, action = null) {
  try {
    const analytics = await NotificationAnalytics.findById(analyticsId);
    if (analytics) {
      await analytics.recordClick(action);
    }
  } catch (error) {
    console.error('Error tracking click:', error);
  }
}

/**
 * Get comprehensive analytics report
 */
async function getAnalyticsReport(startDate, endDate) {
  try {
    const summaryByType = await getSummaryByType(startDate, endDate);
    const deliveryRate = await getDeliveryRate(startDate, endDate);
    const openRate = await getOpenRate(startDate, endDate);
    const clickRate = await getClickRate(startDate, endDate);
    
    return {
      summaryByType,
      overall: {
        deliveryRate,
        openRate,
        clickRate,
      },
      period: {
        startDate,
        endDate,
      },
    };
  } catch (error) {
    console.error('Error generating analytics report:', error);
    throw error;
  }
}

module.exports = {
  getDeliveryRate,
  getOpenRate,
  getClickRate,
  getSummaryByType,
  getUserHistory,
  trackDelivery,
  trackOpen,
  trackClick,
  getAnalyticsReport,
};
