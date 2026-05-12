const connectDB = require('../config/db');
const mongoose = require('mongoose');

async function run() {
  connectDB();
  const Notification = require('../models/notification');

  // wait for connection
  await new Promise((res) => {
    const check = () => {
      if (mongoose.connection.readyState === 1) return res();
      setTimeout(check, 200);
    };
    check();
  });

  const docs = await Notification.find({ type: 'appeal' }).sort({ createdAt: -1 }).limit(20).lean();
  console.log('Recent appeal notifications:', docs.length);
  docs.forEach(d => console.log(d._id.toString(), d.user_id?.toString(), d.title, d.message, d.createdAt));
  process.exit(0);
}

run().catch(err => { console.error(err); process.exit(1); });
