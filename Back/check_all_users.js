const mongoose = require('mongoose');
const User = require('./models/user');

mongoose.connect('mongodb://localhost:27017/djtrip')
.then(async () => {
  console.log('Connected to MongoDB');
  
  // Compter tous les utilisateurs par statut
  const statusCounts = await User.aggregate([
    { $group: { _id: '$accountStatus', count: { $sum: 1 } } }
  ]);
  console.log('Users by status:', statusCounts);
  
  // Chercher tous les utilisateurs (limit 10)
  const allUsers = await User.find({})
    .select('username fullname accountStatus')
    .limit(10);
  console.log('All users (first 10):');
  allUsers.forEach(u => {
    console.log(`- ${u.username} (${u.fullname}) - ${u.accountStatus}`);
  });
  
  // Chercher spécifiquement aminemajdoub_discover
  const specificUser = await User.findOne({ username: 'aminemajdoub_discover' })
    .select('username fullname accountStatus');
  console.log('Specific user aminemajdoub_discover:', specificUser || 'NOT FOUND');
  
  process.exit(0);
})
.catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
