const mongoose = require('mongoose');

/**
 * User Notification Preferences Model
 * Allows users to customize which notifications they receive
 */

const notificationPreferenceSchema = new mongoose.Schema(
  {
    user_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      unique: true,
    },
    // Push notification settings
    push_enabled: {
      type: Boolean,
      default: true,
    },
    // Email notification settings
    email_enabled: {
      type: Boolean,
      default: true,
    },
    // Specific notification type preferences
    preferences: {
      booking: {
        push: { type: Boolean, default: true },
        email: { type: Boolean, default: true },
      },
      message: {
        push: { type: Boolean, default: true },
        email: { type: Boolean, default: false },
      },
      review: {
        push: { type: Boolean, default: true },
        email: { type: Boolean, default: true },
      },
      follow: {
        push: { type: Boolean, default: true },
        email: { type: Boolean, default: false },
      },
      payment: {
        push: { type: Boolean, default: true },
        email: { type: Boolean, default: true },
      },
      activity: {
        push: { type: Boolean, default: true },
        email: { type: Boolean, default: false },
      },
      profile: {
        push: { type: Boolean, default: false },
        email: { type: Boolean, default: false },
      },
      appeal: {
        push: { type: Boolean, default: true },
        email: { type: Boolean, default: true },
      },
      system: {
        push: { type: Boolean, default: true },
        email: { type: Boolean, default: true },
      },
    },

    // Device-specific settings
    device_settings: {
      android: {
        sound: { type: Boolean, default: true },
        vibration: { type: Boolean, default: true },
        led: { type: Boolean, default: true },
      },
      ios: {
        sound: { type: Boolean, default: true },
        badge: { type: Boolean, default: true },
        alert: { type: Boolean, default: true },
      },
    },
  },
  {
    timestamps: true,
    collection: 'notification_preferences',
  }
);

// Indexes for performance
notificationPreferenceSchema.index({ user_id: 1 });

/**
 * Check if user has push enabled for a specific notification type
 */
notificationPreferenceSchema.methods.isPushEnabled = function (notificationType) {
  if (!this.push_enabled) return false;
  
  const typePreference = this.preferences[notificationType];
  return typePreference ? typePreference.push : true;
};

/**
 * Check if user has email enabled for a specific notification type
 */
notificationPreferenceSchema.methods.isEmailEnabled = function (notificationType) {
  if (!this.email_enabled) return false;
  
  const typePreference = this.preferences[notificationType];
  return typePreference ? typePreference.email : true;
};



/**
 * Get user's notification preferences
 */
notificationPreferenceSchema.statics.getUserPreferences = async function (userId) {
  let preferences = await this.findOne({ user_id: userId });
  
  // Create default preferences if not found
  if (!preferences) {
    preferences = await this.create({ user_id: userId });
  }
  
  return preferences;
};

/**
 * Update user's notification preferences
 */
notificationPreferenceSchema.statics.updateUserPreferences = async function (
  userId,
  updates
) {
  return this.findOneAndUpdate(
    { user_id: userId },
    { $set: updates },
    { upsert: true, new: true }
  );
};

const NotificationPreference = mongoose.model(
  'NotificationPreference',
  notificationPreferenceSchema
);

module.exports = NotificationPreference;
