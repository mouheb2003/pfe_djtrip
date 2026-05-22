require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const mongoose = require('mongoose');
const User = require('../models/user');

async function check() {
  const mongoUri = process.env.MONGODB_URI;
  console.log('Uri:', mongoUri);
  await mongoose.connect(mongoUri);
  const users = await User.find({ userType: 'Admin' });
  console.log('Admins found:', JSON.stringify(users, null, 2));
  await mongoose.disconnect();
}

check().catch(console.error);
