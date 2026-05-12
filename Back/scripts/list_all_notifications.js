const connectDB = require('../config/db');
const mongoose = require('mongoose');

async function run() {
  connectDB();
  const Notification = require('../models/notification');

  await new Promise((res) => {
    const check = () => {
      if (mongoose.connection.readyState === 1) return res();
      setTimeout(check, 200);
    };
    check();
  });

  const docs = await Notification.find({}).sort({ createdAt: -1 }).limit(20).lean();
  console.log('Total recent notifications:', docs.length);
  docs.forEach(d => console.log(d._id.toString(), d.user_id?.toString(), d.type, d.title, d.createdAt));
  process.exit(0);
}

run().catch(err => { console.error(err); process.exit(1); });
