const notificationServiceV2 = require('./services/notificationServiceV2');

async function testAppealNotification() {
  console.log('🧪 Testing appeal notification FCM...');
  
  try {
    // Test avec un utilisateur qui a un FCM token
    const testUserId = '69fefdbfe988866cd91d23bb'; // ID utilisateur de test
    const testAppealId = '69fefdbf41365d57d8104689';
    
    console.log(`📤 Sending notification to user: ${testUserId}`);
    console.log(`📋 Appeal ID: ${testAppealId}`);
    
    // Tester notification acceptée
    const result = await notificationServiceV2.sendAppealResolvedNotification({
      userId: testUserId,
      appealId: testAppealId,
      status: 'accepted'
    });
    
    console.log('✅ Notification sent successfully:', result);
    
    // Tester notification rejetée
    const result2 = await notificationServiceV2.sendAppealResolvedNotification({
      userId: testUserId,
      appealId: testAppealId,
      status: 'rejected'
    });
    
    console.log('✅ Rejected notification sent successfully:', result2);
    
  } catch (error) {
    console.error('❌ Error sending notification:', error);
    console.error('Stack:', error.stack);
  }
  
  process.exit(0);
}

testAppealNotification();
