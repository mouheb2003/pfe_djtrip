require('dotenv').config();
const mongoose = require('mongoose');
const User = require('./models/user');

(async () => {
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('Connected to MongoDB');
    
    const admins = await User.find({ userType: { $regex: /^admin$/i } }).select('_id email userType');
    console.log('Admins found with case-insensitive regex:', admins.length);
    admins.forEach(a => {
      console.log('  ', a._id, a.email, a.userType);
    });
    
    const adminsExact = await User.find({ userType: 'Admin' }).select('_id email userType');
    console.log('\nAdmins found with exact "Admin":', adminsExact.length);
    adminsExact.forEach(a => {
      console.log('  ', a._id, a.email, a.userType);
    });
    
    const byType = await User.aggregate([
      { $group: { _id: '$userType', count: { $sum: 1 } } }
    ]);
    console.log('\nUsers by type:');
    byType.forEach(b => console.log('  ', b._id, ':', b.count));
    
    await mongoose.disconnect();
  } catch (err) {
    console.error('Error:', err.message);
    process.exit(1);
  }
})();
