const mongoose = require('mongoose');
const User = require('./models/user');

mongoose.connect('mongodb://localhost:27017/djtrip')
.then(async () => {
  console.log('Connected to MongoDB');
  
  // Chercher l'utilisateur aminemajdoub_discover
  const user = await User.findOne({ username: 'aminemajdoub_discover' });
  console.log('User found:', user ? {
    username: user.username,
    fullname: user.fullname,
    accountStatus: user.accountStatus,
    _id: user._id
  } : 'NOT FOUND');
  
  // Compter tous les utilisateurs actifs
  const activeUsers = await User.countDocuments({ accountStatus: 'active' });
  console.log('Total active users:', activeUsers);
  
  // Test de recherche avec regex
  const regexUsers = await User.find({
    username: { $regex: 'a', $options: 'i' },
    accountStatus: 'active'
  }).select('username fullname').limit(5);
  console.log('Users matching regex /a/i:', regexUsers.map(u => u.username));
  
  // Test de recherche avec 'amine'
  const amineUsers = await User.find({
    username: { $regex: 'amine', $options: 'i' },
    accountStatus: 'active'
  }).select('username fullname').limit(5);
  console.log('Users matching regex /amine/i:', amineUsers.map(u => u.username));
  
  process.exit(0);
})
.catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
