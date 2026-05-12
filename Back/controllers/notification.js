const Notification = require("../models/notification");
const User = require("../models/user");
const { createActivityLog } = require("../services/activityLogService");
const notificationService = require("../services/notificationServiceV2");

// ─── POST /notifications ───────────────────────────────────────────────────────
// Create a new notification (internal use)
exports.createNotification = async (req, res) => {
  try {
    const {
      user_id,
      type,
      title,
      message,
      data = {},
      priority = "medium",
      action_url,
      action_text,
      related_entity_type,
      related_entity_id,
      target_role,
      expires_at,
    } = req.body;

    const notification = await Notification.createNotification({
      user_id,
      type,
      title,
      message,
      data,
      priority,
      action_url,
      action_text,
      related_entity_type,
      related_entity_id,
      target_role,
      expires_at: expires_at ? new Date(expires_at) : null,
    });

    res.status(201).json({
      success: true,
      notification,
    });
  } catch (error) {
    console.error("Error creating notification:", error);
    res.status(500).json({
      success: false,
      message: "Error creating notification",
      error: error.message,
    });
  }
};

// ─── GET /notifications ───────────────────────────────────────────────────────
// Get user notifications (filtered to display-worthy types only)
exports.getUserNotifications = async (req, res) => {
  try {
    const userId = req.user.userId;
    const {
      type,
      unread_only = false,
      limit = 20,
      skip = 0,
    } = req.query;

    // Only allow fetching these notification types for display
    const allowedTypes = ['message', 'approval', 'appeal', 'booking'];
    const queryType = type && allowedTypes.includes(type) ? type : null;

    const notifications = await Notification.getUserNotifications(userId, {
      type: queryType,
      unread_only: unread_only === "true",
      limit: parseInt(limit),
      skip: parseInt(skip),
      allowedTypes, // Pass allowed types to filter in DB query
    });

    // Get total count for pagination
    const totalCount = await Notification.countDocuments({ user_id: userId, type: { $in: allowedTypes } });

    res.status(200).json({
      success: true,
      notifications,
      pagination: {
        total: totalCount,
        limit: parseInt(limit),
        skip: parseInt(skip),
        hasMore: parseInt(skip) + notifications.length < totalCount,
      },
    });
  } catch (error) {
    console.error("Error getting notifications:", error);
    res.status(500).json({
      success: false,
      message: "Error retrieving notifications",
      error: error.message,
    });
  }
};

// ─── PATCH /notifications/:id/read ─────────────────────────────────────────────
// Mark notification as read
exports.markAsRead = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user.userId;

    const result = await Notification.markAsRead(id, userId);
    
    if (result.matchedCount === 0) {
      return res.status(404).json({
        success: false,
        message: "Notification not found",
      });
    }

    res.status(200).json({
      success: true,
      message: "Notification marked as read",
    });
  } catch (error) {
    console.error("Error marking notification as read:", error);
    res.status(500).json({
      success: false,
      message: "Error marking notification as read",
      error: error.message,
    });
  }
};

// ─── PATCH /notifications/read-all ─────────────────────────────────────────────
// Mark all notifications as read
exports.markAllAsRead = async (req, res) => {
  try {
    const userId = req.user.userId;

    const result = await Notification.markAllAsRead(userId);

    res.status(200).json({
      success: true,
      message: "All notifications marked as read",
      modifiedCount: result.modifiedCount,
    });
  } catch (error) {
    console.error("Error marking all notifications as read:", error);
    res.status(500).json({
      success: false,
      message: "Error marking notifications as read",
      error: error.message,
    });
  }
};

// ─── GET /notifications/unread-count ───────────────────────────────────────────
// Get unread notifications count
exports.getUnreadCount = async (req, res) => {
  try {
    const userId = req.user.userId;

    const count = await Notification.getUnreadCount(userId);

    res.status(200).json({
      success: true,
      unread_count: count,
    });
  } catch (error) {
    console.error("Error getting unread count:", error);
    res.status(500).json({
      success: false,
      message: "Error getting unread count",
      error: error.message,
    });
  }
};

// ─── GET /notifications/total-count ────────────────────────────────────────────
// Get total notifications count (all notifications including pushed and not pushed)
exports.getTotalCount = async (req, res) => {
  try {
    const userId = req.user.userId;

    // Count all notifications for this user (both pushed and not pushed, both read and unread)
    const totalCount = await Notification.countDocuments({ user_id: userId });

    res.status(200).json({
      success: true,
      total_count: totalCount,
    });
  } catch (error) {
    console.error("Error getting total count:", error);
    res.status(500).json({
      success: false,
      message: "Error getting total notification count",
      error: error.message,
    });
  }
};

// ─── DELETE /notifications/:id ─────────────────────────────────────────────────────
// Delete a notification
exports.deleteNotification = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user.userId;
    const userType = req.user.userType || null;

    // Allow admins to delete any notification; regular users only their own
    const query = userType === 'Admin' ? { _id: id } : { _id: id, user_id: userId };

    const result = await Notification.deleteOne(query);

    if (result.deletedCount === 0) {
      return res.status(404).json({
        success: false,
        message: "Notification not found",
      });
    }

    res.status(200).json({
      success: true,
      message: "Notification deleted",
    });
  } catch (error) {
    console.error("Error deleting notification:", error);
    res.status(500).json({
      success: false,
      message: "Error deleting notification",
      error: error.message,
    });
  }
};

// ─── POST /notifications/bulk ───────────────────────────────────────────────────
// Create multiple notifications (for system events)
exports.createBulkNotifications = async (req, res) => {
  try {
    const { notifications } = req.body;

    if (!Array.isArray(notifications)) {
      return res.status(400).json({
        success: false,
        message: "Notifications must be an array",
      });
    }

    const createdNotifications = [];
    for (const notificationData of notifications) {
      try {
        const notification = await Notification.createNotification(notificationData);
        createdNotifications.push(notification);
      } catch (error) {
        console.error("Error creating notification:", error);
      }
    }

    res.status(201).json({
      success: true,
      created_count: createdNotifications.length,
      notifications: createdNotifications,
    });
  } catch (error) {
    console.error("Error creating bulk notifications:", error);
    res.status(500).json({
      success: false,
      message: "Error creating notifications",
      error: error.message,
    });
  }
};

// ─── GET /admin/notifications ───────────────────────────────────────────────────
// Get all notifications (admin)
exports.getAllNotifications = async (req, res) => {
  try {
    const {
      type,
      target_role,
      limit = 50,
      skip = 0,
    } = req.query;

    let query = {};
    if (type) query.type = type;
    if (target_role) query.target_role = target_role;

    const notifications = await Notification.find(query)
      .populate("user_id", "fullname email")
      .sort({ created_at: -1 })
      .limit(parseInt(limit))
      .skip(parseInt(skip));

    const total = await Notification.countDocuments(query);

    res.status(200).json({
      success: true,
      notifications,
      pagination: {
        total: total,
        limit: parseInt(limit),
        skip: parseInt(skip),
        hasMore: parseInt(skip) + notifications.length < total,
      },
    });
  } catch (error) {
    console.error("Error getting all notifications:", error);
    res.status(500).json({
      success: false,
      message: "Error retrieving notifications",
      error: error.message,
    });
  }
};

// ─── Helper Functions ───────────────────────────────────────────────────────────────

// Trigger notification for booking events
exports.triggerBookingNotification = async (booking, type, additionalData = {}) => {
  try {
    const user = booking.touriste_id || booking.user_id;
    if (!user) return;

    let title, message, actionUrl, actionText;

    switch (type) {
      case "confirmed":
        title = "Booking Confirmed";
        message = `Your booking for "${booking.activite_id?.titre || "activity"}" has been confirmed.`;
        actionUrl = `/bookings/${booking._id}`;
        actionText = "View Booking";
        break;
      case "rejected":
        title = "Booking Rejected";
        message = `Your booking for "${booking.activite_id?.titre || "activity"}" has been rejected.`;
        actionUrl = `/bookings/${booking._id}`;
        actionText = "View Details";
        break;
      case "cancelled":
        title = "Booking Cancelled";
        message = `Your booking for "${booking.activite_id?.titre || "activity"}" has been cancelled.`;
        actionUrl = `/bookings/${booking._id}`;
        actionText = "View Details";
        break;
      case "reminder":
        title = "Activity Reminder";
        message = `Your activity "${booking.activite_id?.titre || "activity"}" starts in 2 hours.`;
        actionUrl = `/activities/${booking.activite_id}`;
        actionText = "View Activity";
        break;
      default:
        return;
    }

    await Notification.createNotification({
      user_id: user._id,
      type: "booking",
      title,
      message,
      data: { booking_id: booking._id, ...additionalData },
      priority: type === "reminder" ? "high" : "medium",
      action_url: actionUrl,
      action_text: actionText,
      related_entity_type: "booking",
      related_entity_id: booking._id,
      target_role: "tourist",
    });
  } catch (error) {
    console.error("Error triggering booking notification:", error);
  }
};

// Trigger notification for new messages
exports.triggerMessageNotification = async (message, recipientId) => {
  try {
    const senderName = message.sender_id?.fullname || "Someone";
    
    await Notification.createNotification({
      user_id: recipientId,
      type: "message",
      title: `New message from ${senderName}`,
      message: message.content?.substring(0, 100) || "You have a new message",
      data: { 
        message_id: message._id,
        conversation_id: message.conversation_id,
        sender_id: message.sender_id,
      },
      action_url: `/messages/${message.conversation_id}`,
      action_text: "View Message",
      related_entity_type: "message",
      related_entity_id: message._id,
      priority: "medium",
    });
  } catch (error) {
    console.error("Error triggering message notification:", error);
  }
};

// Trigger notification for new reviews
exports.triggerReviewNotification = async (review, recipientId) => {
  try {
    const reviewerName = review.touriste_id?.fullname || "Someone";
    const entityName = review.activite_id?.titre || review.organisateur_id?.fullname || "activity";
    
    await Notification.createNotification({
      user_id: recipientId,
      type: "review",
      title: `New Review Received`,
      message: `${reviewerName} left a ${review.note}-star review for ${entityName}`,
      data: { 
        review_id: review._id,
        rating: review.note,
        comment: review.commentaire,
      },
      action_url: `/reviews/${review._id}`,
      action_text: "View Review",
      related_entity_type: "review",
      related_entity_id: review._id,
      priority: "medium",
    });
  } catch (error) {
    console.error("Error triggering review notification:", error);
  }
};

// Trigger notification for system events
exports.triggerSystemNotification = async (title, message, options = {}) => {
  try {
    const {
      target_role = "all",
      priority = "medium",
      action_url,
      action_text,
      expires_at,
    } = options;

    // Get all active users
    const users = await User.find({ 
      accountStatus: "active",
      notifications_email: true 
    }).select("_id");

    const notifications = users.map(user => ({
      user_id: user._id,
      type: "system",
      title,
      message,
      data: options.data || {},
      priority,
      action_url,
      action_text,
      target_role,
      expires_at: expires_at ? new Date(expires_at) : null,
    }));

    // Create notifications in bulk
    await Notification.insertMany(notifications);
  } catch (error) {
    console.error("Error triggering system notification:", error);
  }
};

// Cleanup expired notifications (run daily)
exports.cleanupExpiredNotifications = async () => {
  try {
    await Notification.cleanupExpired();
    console.log("Expired notifications cleaned up");
  } catch (error) {
    console.error("Error cleaning up expired notifications:", error);
  }
};

// ─── SOCIAL NETWORK NOTIFICATIONS ───────────────────────────────────────────────

// Trigger notification for new publication
exports.triggerPublicationNotification = async (userId, authorName, postId, postTitle) => {
  try {
    await Notification.createNotification({
      user_id: userId,
      type: "publication",
      title: "Nouvelle publication ",
      message: `${authorName} a publié: "${postTitle || 'Nouvelle publication'}"`,
      data: {
        type: "new_publication",
        postId,
      },
      related_entity_type: "post",
      related_entity_id: postId,
      priority: "medium",
    });

    // Send FCM push notification
    await notificationService.sendNewPublicationNotification({
      userId,
      authorName,
      postId,
      postTitle,
    });
  } catch (error) {
    console.error("Error triggering publication notification:", error);
  }
};

// Trigger notification for reaction
exports.triggerReactionNotification = async (userId, reactorName, postId, commentId, reactionType, entityType) => {
  try {
    const isPost = entityType === 'post';
    const title = isPost ? 'New Reaction ' : 'Reaction to your comment ';
    const message = isPost 
      ? `${reactorName} reacted to your post`
      : `${reactorName} reacted to your comment`;

    await Notification.createNotification({
      user_id: userId,
      type: "reaction",
      title,
      message,
      data: {
        type: "new_reaction",
        postId,
        commentId,
        reactionType,
        entityType,
      },
      related_entity_type: isPost ? "post" : "comment",
      related_entity_id: isPost ? postId : commentId,
      priority: "medium",
    });

    // Send FCM push notification
    await notificationService.sendReactionNotification({
      userId,
      reactorName,
      postId,
      commentId,
      reactionType,
      entityType,
    });
  } catch (error) {
    console.error("Error triggering reaction notification:", error);
  }
};

// Trigger notification for comment
exports.triggerCommentNotification = async (userId, commenterName, postId, commentContent) => {
  try {
    await Notification.createNotification({
      user_id: userId,
      type: "comment",
      title: "New Comment ",
      message: `${commenterName} commented: "${commentContent?.substring(0, 50) || '...'}"`,
      data: {
        type: "new_comment",
        postId,
      },
      related_entity_type: "post",
      related_entity_id: postId,
      priority: "medium",
    });

    // Send FCM push notification
    await notificationService.sendCommentNotification({
      userId,
      commenterName,
      postId,
      commentContent,
    });
  } catch (error) {
    console.error("Error triggering comment notification:", error);
  }
};

// Trigger notification for reply
exports.triggerReplyNotification = async (userId, replierName, postId, parentCommentId, replyContent) => {
  try {
    await Notification.createNotification({
      user_id: userId,
      type: "reply",
      title: "New Reply ",
      message: `${replierName} replied to your comment`,
      data: {
        type: "new_reply",
        postId,
        parentCommentId,
      },
      related_entity_type: "comment",
      related_entity_id: parentCommentId,
      priority: "medium",
    });

    // Send FCM push notification
    await notificationService.sendReplyNotification({
      userId,
      replierName,
      postId,
      parentCommentId,
      replyContent,
    });
  } catch (error) {
    console.error("Error triggering reply notification:", error);
  }
};

// Trigger notification for mention
exports.triggerMentionNotification = async (userId, mentionerName, postId, commentId) => {
  try {
    const title = commentId ? 'You were mentioned ' : 'You were mentioned ';
    const message = `${mentionerName} mentioned you`;

    await Notification.createNotification({
      user_id: userId,
      type: "comment",
      title,
      message,
      data: {
        type: "mention",
        postId,
        commentId,
      },
      related_entity_type: commentId ? "comment" : "post",
      related_entity_id: commentId || postId,
      priority: "high",
    });

    // Send FCM push notification
    await notificationService.sendMentionNotification({
      userId,
      mentionerName,
      postId,
      commentId,
    });
  } catch (error) {
    console.error("Error triggering mention notification:", error);
  }
};
