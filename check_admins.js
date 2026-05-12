require('dotenv').config({path:'./Back/.env'});
const mongoose = require('mongoose');
const User = require('./Back/models/user');

(async () => {
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('Connected to MongoDB');
    
    const admins = await User.find({ userType: { $regex: /^admin$/i } }).select('_id email userType');
    console.log('Admins found:', admins.length);
    admins.forEach(a => {
      console.log('  ', a._id, a.email, a.userType);
    });
    
    const allUsers = await User.countDocuments();
    console.log('\nTotal users:', allUsers);
    
    const byType = await User.aggregate([
      { $group: { _id: '$userType', count: { $sum: 1 } } }
    ]);
    console.log('Users by type:');
    byType.forEach(b => console.log('  ', b._id, ':', b.count));
    
    await mongoose.disconnect();
  } catch (err) {
    console.error('Error:', err.message);
    process.exit(1);
  }
})();
