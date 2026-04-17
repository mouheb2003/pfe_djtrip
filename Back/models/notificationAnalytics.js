const mongoose = require('mongoose');

/**
 * Notification Analytics Model
 * Tracks notification delivery, open rates, and click rates
 */

const notificationAnalyticsSchema = new mongoose.Schema(
  {
    notification_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Notification',
      index: true,
    },
    user_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    notification_type: {
      type: String,
      required: true,
      enum: [
        'booking',
        'message',
        'review',
        'system',
        'appeal',
        'activity',
        'reminder',
        'follow',
        'payment',
        'profile',
      ],
      index: true,
    },
    // Delivery tracking
    delivery_status: {
      type: String,
      enum: ['queued', 'sent', 'delivered', 'failed', 'bounced'],
      default: 'queued',
      index: true,
    },
    delivery_attempts: {
      type: Number,
      default: 0,
    },
    delivery_error: {
      type: String,
      default: null,
    },
    delivered_at: {
      type: Date,
      default: null,
    },
    // Engagement tracking
    opened: {
      type: Boolean,
      default: false,
      index: true,
    },
    opened_at: {
      type: Date,
      default: null,
    },
    clicked: {
      type: Boolean,
      default: false,
      index: true,
    },
    clicked_at: {
      type: Date,
      default: null,
    },
    action_taken: {
      type: String,
      default: null,
    },
    // Device info
    device_type: {
      type: String,
      enum: ['android', 'ios', 'web', 'unknown'],
      default: 'unknown',
    },
    // Time to engagement (in seconds)
    time_to_open: {
      type: Number,
      default: null,
    },
    time_to_click: {
      type: Number,
      default: null,
    },
    // Additional metadata
    metadata: {
      type: mongoose.Schema.Types.Mixed,
      default: {},
    },
  },
  {
    timestamps: true,
    collection: 'notification_analytics',
  }
);

// Indexes for performance and analytics queries
notificationAnalyticsSchema.index({ user_id: 1, created_at: -1 });
notificationAnalyticsSchema.index({ notification_type: 1, created_at: -1 });
notificationAnalyticsSchema.index({ delivery_status: 1, created_at: -1 });
notificationAnalyticsSchema.index({ opened: 1, created_at: -1 });
notificationAnalyticsSchema.index({ clicked: 1, created_at: -1 });

/**
 * Record delivery
 */
notificationAnalyticsSchema.methods.recordDelivery = async function (status, error = null) {
  this.delivery_status = status;
  this.delivery_attempts += 1;
  
  if (error) {
    this.delivery_error = error;
  }
  
  if (status === 'delivered') {
    this.delivered_at = new Date();
  }
  
  return this.save();
};

/**
 * Record open event
 */
notificationAnalyticsSchema.methods.recordOpen = async function () {
  if (this.opened) return this;
  
  this.opened = true;
  this.opened_at = new Date();
  
  if (this.delivered_at) {
    this.time_to_open = Math.floor((this.opened_at - this.delivered_at) / 1000);
  }
  
  return this.save();
};

/**
 * Record click event
 */
notificationAnalyticsSchema.methods.recordClick = async function (action = null) {
  if (this.clicked) return this;
  
  this.clicked = true;
  this.clicked_at = new Date();
  this.action_taken = action;
  
  if (this.delivered_at) {
    this.time_to_click = Math.floor((this.clicked_at - this.delivered_at) / 1000);
  }
  
  return this.save();
};

/**
 * Get delivery rate for a period
 */
notificationAnalyticsSchema.statics.getDeliveryRate = async function (startDate, endDate, notificationType = null) {
  const query = {
    created_at: { $gte: startDate, $lte: endDate },
  };
  
  if (notificationType) {
    query.notification_type = notificationType;
  }
  
  const total = await this.countDocuments(query);
  const delivered = await this.countDocuments({ ...query, delivery_status: 'delivered' });
  
  return total > 0 ? (delivered / total) * 100 : 0;
};

/**
 * Get open rate for a period
 */
notificationAnalyticsSchema.statics.getOpenRate = async function (startDate, endDate, notificationType = null) {
  const query = {
    created_at: { $gte: startDate, $lte: endDate },
    delivery_status: 'delivered',
  };
  
  if (notificationType) {
    query.notification_type = notificationType;
  }
  
  const total = await this.countDocuments(query);
  const opened = await this.countDocuments({ ...query, opened: true });
  
  return total > 0 ? (opened / total) * 100 : 0;
};

/**
 * Get click rate for a period
 */
notificationAnalyticsSchema.statics.getClickRate = async function (startDate, endDate, notificationType = null) {
  const query = {
    created_at: { $gte: startDate, $lte: endDate },
    delivery_status: 'delivered',
  };
  
  if (notificationType) {
    query.notification_type = notificationType;
  }
  
  const total = await this.countDocuments(query);
  const clicked = await this.countDocuments({ ...query, clicked: true });
  
  return total > 0 ? (clicked / total) * 100 : 0;
};

/**
 * Get analytics summary by notification type
 */
notificationAnalyticsSchema.statics.getSummaryByType = async function (startDate, endDate) {
  const pipeline = [
    {
      $match: {
        created_at: { $gte: startDate, $lte: endDate },
      },
    },
    {
      $group: {
        _id: '$notification_type',
        total: { $sum: 1 },
        delivered: {
          $sum: { $cond: [{ $eq: ['$delivery_status', 'delivered'] }, 1, 0] },
        },
        opened: {
          $sum: { $cond: ['$opened', 1, 0] },
        },
        clicked: {
          $sum: { $cond: ['$clicked', 1, 0] },
        },
        avg_time_to_open: {
          $avg: '$time_to_open',
        },
        avg_time_to_click: {
          $avg: '$time_to_click',
        },
      },
    },
    {
      $sort: { total: -1 },
    },
  ];
  
  return this.aggregate(pipeline);
};

/**
 * Create analytics record
 */
notificationAnalyticsSchema.statics.createAnalytics = async function (data) {
  return this.create(data);
};

/**
 * Get user notification history
 */
notificationAnalyticsSchema.statics.getUserHistory = async function (userId, options = {}) {
  const {
    limit = 50,
    skip = 0,
    type = null,
    status = null,
  } = options;
  
  const query = { user_id: userId };
  
  if (type) query.notification_type = type;
  if (status) query.delivery_status = status;
  
  return this.find(query)
    .sort({ created_at: -1 })
    .limit(limit)
    .skip(skip);
};

const NotificationAnalytics = mongoose.model(
  'NotificationAnalytics',
  notificationAnalyticsSchema
);

module.exports = NotificationAnalytics;
