const connectDB = require('../config/db');

async function run() {
  connectDB();
  const mongoose = require('mongoose');
  const Notification = require('../models/notification');

  await new Promise((res) => {
    const check = () => {
      if (mongoose.connection.readyState === 1) return res();
      setTimeout(check, 200);
    };
    check();
  });

  const adminId = process.argv[2] || null;
  if (!adminId) {
    console.error('Usage: node create_test_notification.js <adminObjectId>');
    process.exit(1);
  }

  const notif = await Notification.createNotification({
    user_id: adminId,
    type: 'appeal',
    title: 'Test Appeal Notification',
    message: 'This is a test notification for admin',
    data: { test: true },
    priority: 'high',
    related_entity_type: 'appeal',
  });

  console.log('Created notification:', notif._id.toString());
  process.exit(0);
}

run().catch(err => { console.error(err); process.exit(1); });
