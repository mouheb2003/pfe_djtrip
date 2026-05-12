const connectDB = require('../config/db');
const mongoose = require('mongoose');

async function run() {
  connectDB();
  const User = require('../models/user');

  // wait for connection
  await new Promise((res) => {
    const check = () => {
      if (mongoose.connection.readyState === 1) return res();
      setTimeout(check, 200);
    };
    check();
  });

  const q = process.argv[2] || 'mouheb';
  const users = await User.find({ $or: [ { email: new RegExp(q, 'i') }, { fullname: new RegExp(q, 'i') } ] }).limit(20).lean();
  console.log('Found', users.length, 'users');
  users.forEach(u => console.log(u._id.toString(), u.email, u.fullname, u.userType));
  process.exit(0);
}

run().catch(err => { console.error(err); process.exit(1); });
