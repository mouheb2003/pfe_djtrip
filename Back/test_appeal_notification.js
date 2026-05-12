const notificationService = require('./services/notificationServiceV2');

async function testAppealNotification() {
  console.log('Testing appeal notification with status "accepted"...');
  
  try {
    const result = await notificationService.sendAppealResolvedNotification({
      userId: '69fefdbfe988866cd91d23bb', // L'ID de notre utilisateur de test
      appealId: '69fefdbf41365d57d8104689',
      status: 'accepted'
    });
    
    console.log('Notification result:', result);
  } catch (error) {
    console.error('Error sending notification:', error);
  }
  
  process.exit(0);
}

testAppealNotification();
