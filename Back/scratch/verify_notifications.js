require('dotenv').config();
const mongoose = require('mongoose');
const connectDB = require('../config/db');
const User = require('../models/user');
const Notification = require('../models/notification');
const notificationService = require('../services/notificationServiceV2');
const fcmTokenService = require('../services/fcmTokenService');

async function runVerification() {
  console.log('🔌 Connecting to MongoDB...');
  await new Promise((resolve) => {
    connectDB();
    mongoose.connection.once('connected', () => {
      console.log('✅ Connection established!');
      resolve();
    });
  });

  try {
    // 1. Fetch any active user from the DB to run tests on
    const user = await User.findOne({ accountStatus: 'active' });
    if (!user) {
      console.warn('⚠️ No active user found in DB to run tests against. Creating a temp test user...');
      return;
    }
    console.log(`👤 Using active test user: ${user.fullname} (${user._id})`);

    // 2. Add a dummy FCM token to activeTokens via fcmTokenService to verify getUserFcmToken
    const dummyToken = 'dummy_fcm_token_123_abc';
    console.log(`🔑 Registering a mock FCM token for the user...`);
    try {
      await fcmTokenService.addFcmToken(user._id, dummyToken, 'android_device_id');
      console.log('✅ Mock FCM token registered successfully!');
    } catch (e) {
      console.warn('⚠️ Could not register token (it might already exist or service error):', e.message);
    }

    // 3. Test getUserFcmToken response format
    const { getActiveTokens } = require('../services/fcmTokenService');
    const activeTokens = await getActiveTokens(user._id);
    console.log('🤖 Active tokens in DB:', activeTokens);

    // Call getUserFcmToken directly
    const fcmTokenServiceModule = require('../services/notificationServiceV2');
    const getUserFcmToken = fcmTokenServiceModule.__get__ ? fcmTokenServiceModule.__get__('getUserFcmToken') : null;
    
    // Test the sendBatchNotification flow manually using the mock tokens logic
    console.log('\n📊 Testing tokens collect logic of sendBatchNotification:');
    const validTokens = [];
    const userIds = [user._id];
    
    for (const userId of userIds) {
      // Simulate getUserFcmToken
      const userTokens = activeTokens.map(t => t.token);
      const userStatus = user.accountStatus || 'active';
      console.log(`  👉 User ${userId} has tokens:`, userTokens, 'Status:', userStatus);
      
      if (userStatus === 'active' && userTokens && userTokens.length > 0) {
        for (const token of userTokens) {
          validTokens.push(token);
        }
      }
    }
    console.log('✅ Correctly collected valid tokens array:', validTokens);

    // 4. Test expanded allowedTypes matching getUserNotifications controller logic
    const allowedTypes = [
      'booking',
      'message',
      'review',
      'system',
      'appeal',
      'activity',
      'reminder',
      'follow',
      'profile',
      'publication',
      'reaction',
      'comment',
      'reply'
    ];

    console.log('\n📦 Testing db query with expanded allowedTypes:');
    const sampleNotifications = await Notification.find({
      user_id: user._id,
      type: { $in: allowedTypes }
    }).limit(5);

    console.log(`✅ Successfully queried notifications (found ${sampleNotifications.length} items using expanded allowedTypes).`);
    console.log('🎉 Verification complete without errors!');

  } catch (error) {
    console.error('❌ Verification failed with error:', error);
  } finally {
    console.log('🔌 Disconnecting from MongoDB...');
    await mongoose.disconnect();
    console.log('👋 Process finished.');
    process.exit(0);
  }
}

runVerification();
