require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const mongoose = require('mongoose');
const User = require('../models/user');

async function check() {
  const mongoUri = process.env.MONGODB_URI;
  await mongoose.connect(mongoUri);
  const cleanQuery = 'admin';
  const users = await User.find({
    $or: [
      { fullname: { $regex: cleanQuery, $options: 'i' } },
      { email: { $regex: cleanQuery, $options: 'i' } },
      { userType: { $regex: cleanQuery, $options: 'i' } }
    ],
    accountStatus: 'active'
  })
  .select('fullname avatar userType _id')
  .lean()
  .exec();
  console.log('Search Result for "admin":', JSON.stringify(users, null, 2));
  await mongoose.disconnect();
}

check().catch(console.error);
