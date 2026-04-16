const User = require('../models/user');
const logger = require('../utils/logger');

/**
 * FCM Token Management Service
 * Production-ready with:
 * - Multi-device support per user
 * - Cross-account device isolation
 * - Token activation/deactivation
 * - Performance optimized queries
 */

class FcmTokenService {
  /**
   * Add or update FCM token for a user
   * @param {string} userId - User ID
   * @param {string} token - FCM token
   * @param {string} deviceId - Unique device identifier
   * @returns {Promise<Object>} Result object
   */
  async addFcmToken(userId, token, deviceId) {
    try {
      if (!userId || !token || !deviceId) {
        throw new Error('userId, token, and deviceId are required');
      }

      logger.info(`Adding FCM token for user ${userId}, device ${deviceId}`);

      // Step 1: Deactivate this deviceId for ALL other users (cross-account isolation)
      const deactivateResult = await User.updateMany(
        { 
          _id: { $ne: userId },
          'fcmTokens.deviceId': deviceId 
        },
        { 
          $set: { 'fcmTokens.$.isActive': false } 
        }
      );

      if (deactivateResult.modifiedCount > 0) {
        logger.info(`Deactivated device ${deviceId} for ${deactivateResult.modifiedCount} other users`);
      }

      // Step 2: Find the user and update/add the token
      const user = await User.findById(userId);
      if (!user) {
        throw new Error('User not found');
      }

      // Initialize fcmTokens array if it doesn't exist
      if (!user.fcmTokens || !Array.isArray(user.fcmTokens)) {
        user.fcmTokens = [];
      }

      // Step 3: Check if deviceId already exists for this user
      const existingTokenIndex = user.fcmTokens.findIndex(
        (t) => t.deviceId === deviceId
      );

      const now = new Date();

      if (existingTokenIndex !== -1) {
        // Update existing token entry
        user.fcmTokens[existingTokenIndex] = {
          token,
          deviceId,
          isActive: true,
          lastUsed: now,
          createdAt: user.fcmTokens[existingTokenIndex].createdAt || now
        };
        logger.info(`Updated existing FCM token for user ${userId}, device ${deviceId}`);
      } else {
        // Add new token entry
        user.fcmTokens.push({
          token,
          deviceId,
          isActive: true,
          lastUsed: now,
          createdAt: now
        });
        logger.info(`Added new FCM token for user ${userId}, device ${deviceId}`);
      }

      // Step 4: Remove duplicate tokens (same token, different deviceId) to prevent duplicates
      user.fcmTokens = user.fcmTokens.filter((t, index, self) => 
        index === self.findIndex((t2) => t2.token === t.token)
      );

      await user.save();

      return {
        success: true,
        message: 'FCM token added/updated successfully',
        deviceId,
        isActive: true
      };
    } catch (error) {
      logger.error('Error in addFcmToken:', error);
      throw error;
    }
  }

  /**
   * Deactivate FCM token for a specific device (logout)
   * @param {string} userId - User ID
   * @param {string} deviceId - Device identifier
   * @returns {Promise<Object>} Result object
   */
  async logout(userId, deviceId) {
    try {
      if (!userId || !deviceId) {
        throw new Error('userId and deviceId are required');
      }

      logger.info(`Deactivating FCM token for user ${userId}, device ${deviceId}`);

      const user = await User.findById(userId);
      if (!user) {
        throw new Error('User not found');
      }

      if (!user.fcmTokens || !Array.isArray(user.fcmTokens)) {
        return {
          success: true,
          message: 'No FCM tokens found for user'
        };
      }

      // Find the token entry for this deviceId
      const tokenIndex = user.fcmTokens.findIndex(
        (t) => t.deviceId === deviceId
      );

      if (tokenIndex === -1) {
        return {
          success: true,
          message: 'FCM token not found for this device'
        };
      }

      // Deactivate the token (do NOT remove it)
      user.fcmTokens[tokenIndex].isActive = false;
      user.fcmTokens[tokenIndex].lastUsed = new Date();

      await user.save();

      logger.info(`Deactivated FCM token for user ${userId}, device ${deviceId}`);

      return {
        success: true,
        message: 'FCM token deactivated successfully',
        deviceId,
        isActive: false
      };
    } catch (error) {
      logger.error('Error in logout:', error);
      throw error;
    }
  }

  /**
   * Get active FCM tokens for a user
   * @param {string} userId - User ID
   * @returns {Promise<Array>} Array of active tokens
   */
  async getActiveTokens(userId) {
    try {
      if (!userId) {
        throw new Error('userId is required');
      }

      const user = await User.findById(userId).select('fcmTokens accountStatus');
      if (!user) {
        throw new Error('User not found');
      }

      // Only return active tokens for active accounts
      if (user.accountStatus !== 'active') {
        logger.info(`User ${userId} account status is ${user.accountStatus}, skipping FCM tokens`);
        return [];
      }

      if (!user.fcmTokens || !Array.isArray(user.fcmTokens)) {
        return [];
      }

      const activeTokens = user.fcmTokens
        .filter(t => t.isActive)
        .map(t => ({
          token: t.token,
          deviceId: t.deviceId,
          lastUsed: t.lastUsed
        }));

      logger.info(`Found ${activeTokens.length} active tokens for user ${userId}`);
      return activeTokens;
    } catch (error) {
      logger.error('Error in getActiveTokens:', error);
      throw error;
    }
  }

  /**
   * Send notification to a user (only to active tokens)
   * @param {string} userId - User ID
   * @param {Object} payload - Notification payload
   * @param {string} payload.title - Notification title
   * @param {string} payload.body - Notification body
   * @param {Object} payload.data - Additional data
   * @returns {Promise<Object>} Result object
   */
  async sendNotification(userId, payload) {
    try {
      if (!userId || !payload) {
        throw new Error('userId and payload are required');
      }

      const { title, body, data = {} } = payload;

      // Get active tokens for the user
      const activeTokens = await this.getActiveTokens(userId);

      if (activeTokens.length === 0) {
        return {
          success: false,
          reason: 'No active FCM tokens found for user'
        };
      }

      // Import Firebase admin dynamically
      const { getFirebaseAdmin, isInitialized } = require('../config/firebase');

      if (!isInitialized()) {
        logger.warn('Firebase not initialized, skipping notification');
        return {
          success: false,
          reason: 'Firebase not initialized'
        };
      }

      const admin = getFirebaseAdmin();
      const results = [];

      // Send notification to each active token
      for (const tokenData of activeTokens) {
        try {
          const message = {
            notification: {
              title,
              body
            },
            data: {
              ...data,
              timestamp: new Date().toISOString()
            },
            token: tokenData.token
          };

          const response = await admin.messaging().send(message);
          logger.info(`Notification sent successfully to device ${tokenData.deviceId}`);
          results.push({
            success: true,
            deviceId: tokenData.deviceId,
            messageId: response
          });
        } catch (error) {
          // Handle invalid tokens
          if (error.code === 'messaging/registration-token-not-registered') {
            logger.warn(`Invalid token for device ${tokenData.deviceId}, deactivating`);
            await this.deactivateInvalidToken(userId, tokenData.token);
            results.push({
              success: false,
              deviceId: tokenData.deviceId,
              reason: 'Invalid token deactivated'
            });
          } else {
            logger.error(`Error sending notification to device ${tokenData.deviceId}:`, error);
            results.push({
              success: false,
              deviceId: tokenData.deviceId,
              reason: error.message
            });
          }
        }
      }

      const successCount = results.filter(r => r.success).length;

      return {
        success: successCount > 0,
        results,
        message: `Sent to ${successCount}/${activeTokens.length} devices`
      };
    } catch (error) {
      logger.error('Error in sendNotification:', error);
      throw error;
    }
  }

  /**
   * Deactivate an invalid token
   * @param {string} userId - User ID
   * @param {string} token - Invalid token
   * @returns {Promise<boolean>} Success status
   */
  async deactivateInvalidToken(userId, token) {
    try {
      await User.updateOne(
        { _id: userId, 'fcmTokens.token': token },
        { $set: { 'fcmTokens.$.isActive': false } }
      );
      logger.info(`Deactivated invalid token for user ${userId}`);
      return true;
    } catch (error) {
      logger.error('Error deactivating invalid token:', error);
      return false;
    }
  }

  /**
   * Clean up old inactive tokens (maintenance)
   * @param {number} daysOld - Remove tokens inactive for this many days
   * @returns {Promise<Object>} Cleanup result
   */
  async cleanupOldTokens(daysOld = 30) {
    try {
      const cutoffDate = new Date();
      cutoffDate.setDate(cutoffDate.getDate() - daysOld);

      const result = await User.updateMany(
        {
          'fcmTokens.isActive': false,
          'fcmTokens.lastUsed': { $lt: cutoffDate }
        },
        {
          $pull: {
            fcmTokens: {
              isActive: false,
              lastUsed: { $lt: cutoffDate }
            }
          }
        }
      );

      logger.info(`Cleaned up ${result.modifiedCount} users with old inactive tokens`);
      return {
        success: true,
        usersModified: result.modifiedCount
      };
    } catch (error) {
      logger.error('Error in cleanupOldTokens:', error);
      throw error;
    }
  }

  /**
   * Get all tokens for a user (including inactive)
   * @param {string} userId - User ID
   * @returns {Promise<Array>} Array of all tokens
   */
  async getAllTokens(userId) {
    try {
      if (!userId) {
        throw new Error('userId is required');
      }

      const user = await User.findById(userId).select('fcmTokens');
      if (!user) {
        throw new Error('User not found');
      }

      return user.fcmTokens || [];
    } catch (error) {
      logger.error('Error in getAllTokens:', error);
      throw error;
    }
  }
}

module.exports = new FcmTokenService();
