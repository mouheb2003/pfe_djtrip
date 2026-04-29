const mongoose = require("mongoose");

const notificationSchema = new mongoose.Schema(
  {
    // User who receives the notification
    user_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    // Notification type
    type: {
      type: String,
      required: true,
      enum: [
        "booking",          // Tourist: booking confirmed/rejected/cancelled
        "message",         // Both: new message received
        "review",          // Both: new review received
        "system",          // Both: system announcements
        "appeal",          // User: appeal response
        "activity",        // Organizer: activity updates
        "reminder",        // Tourist: activity reminders
        "follow",          // Both: new follower
        "payment",         // Tourist: payment confirmations
        "profile",         // Both: profile updates
        "publication",     // Both: new publication/post from followed user
        "reaction",        // Both: someone reacted to user's post/comment
        "comment",         // Both: someone commented on user's post
        "reply",           // Both: someone replied to user's comment
        "group_invitation", // Both: group invitation received
        "group_update",    // Both: group updates (member joined/left, etc.)
      ],
      index: true,
    },
    // Notification title
    title: {
      type: String,
      required: true,
      maxlength: [100, "Title cannot exceed 100 characters"],
      trim: true,
    },
    // Notification message
    message: {
      type: String,
      required: true,
      maxlength: [500, "Message cannot exceed 500 characters"],
      trim: true,
    },
    // Optional additional data (JSON)
    data: {
      type: mongoose.Schema.Types.Mixed,
      default: {},
    },
    // Read status
    is_read: {
      type: Boolean,
      default: false,
      index: true,
    },
    // Priority level
    priority: {
      type: String,
      enum: ["low", "medium", "high", "urgent"],
      default: "medium",
      index: true,
    },
    // Action URL (optional)
    action_url: {
      type: String,
      default: null,
    },
    // Action text (optional)
    action_text: {
      type: String,
      default: null,
      maxlength: [50, "Action text cannot exceed 50 characters"],
    },
    // Expiration time (auto-delete)
    expires_at: {
      type: Date,
      default: null,
    },
    // Related entities
    related_entity_type: {
      type: String,
      enum: ["booking", "activity", "message", "review", "appeal", "user", "post", "comment"],
      default: null,
    },
    related_entity_id: {
      type: mongoose.Schema.Types.ObjectId,
      refPath: "related_entity_type",
      default: null,
    },
    // For admin notifications
    target_role: {
      type: String,
      enum: ["tourist", "organizer", "admin", "all"],
      default: null,
    },
  },
  {
    timestamps: true,
    collection: "notifications",
  },
);

// Indexes for performance
notificationSchema.index({ user_id: 1, is_read: 1, created_at: -1 });
notificationSchema.index({ type: 1, created_at: -1 });
notificationSchema.index({ target_role: 1, created_at: -1 });
notificationSchema.index({ expires_at: 1 }, { expireAfterSeconds: 0 });

// Virtual for formatted creation date
notificationSchema.virtual("created_at").get(function () {
  return this.createdAt;
});

// Static method to create notification
notificationSchema.statics.createNotification = async function (notificationData) {
  try {
    const notification = new this(notificationData);
    await notification.save();

    console.log('📝 Notification created in DB:', notification._id, 'for user:', notification.user_id, 'type:', notification.type, 'title:', notification.title);

    // Send FCM push notification
    try {
      const notificationService = require("../services/notificationService");
      console.log('🔔 Attempting to send FCM push notification to user:', notification.user_id.toString(), 'type:', notification.type);
      const result = await notificationService.sendPushNotification({
        userId: notification.user_id.toString(),
        title: notification.title,
        body: notification.message,
        data: notification.data || {},
      });
      console.log('✅ FCM push notification result:', result);
    } catch (fcmError) {
      console.error("❌ Error sending FCM notification:", fcmError);
      // Don't throw - notification is already saved in DB
    }

    // Emit real-time event
    const EventEmitter = require("events");
    const emitter = new EventEmitter();
    emitter.emit("notification_created", {
      notification: notification.populate("user_id"),
      userId: notification.user_id,
    });

    return notification;
  } catch (error) {
    console.error("Error creating notification:", error);
    throw error;
  }
};

// Static method to get user notifications
notificationSchema.statics.getUserNotifications = function (userId, options = {}) {
  const query = { user_id: userId };

  // Filter by unread if requested
  if (options.unread_only) {
    query.is_read = false;
  }

  // Filter by type if requested
  if (options.type) {
    query.type = options.type;
  }

  return this.find(query)
    .sort({ created_at: -1 })
    .limit(options.limit || 50)
    .skip(options.skip || 0);
};

// Static method to mark as read
notificationSchema.statics.markAsRead = function (notificationId, userId) {
  return this.updateOne(
    { _id: notificationId, user_id: userId },
    { is_read: true }
  );
};

// Static method to mark all as read
notificationSchema.statics.markAllAsRead = function (userId) {
  return this.updateMany(
    { user_id: userId, is_read: false },
    { is_read: true }
  );
};

// Static method to get unread count
notificationSchema.statics.getUnreadCount = function (userId) {
  return this.countDocuments({ user_id: userId, is_read: false });
};

// Static method to cleanup expired notifications
notificationSchema.statics.cleanupExpired = function () {
  return this.deleteMany({
    expires_at: { $lt: new Date() }
  });
};

// Instance method to check if notification is expired
notificationSchema.methods.isExpired = function () {
  return this.expires_at && new Date() > this.expires_at;
};

const Notification = mongoose.model("Notification", notificationSchema);

module.exports = Notification;
