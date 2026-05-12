const mongoose = require('mongoose');
const User = require('./models/user');

mongoose.connect('mongodb://localhost:27017/djtrip')
.then(async () => {
  console.log('Connected to MongoDB');
  
  // Créer un utilisateur de test
  const testUser = new User({
    username: 'aminemajdoub_discover',
    fullname: 'Amine Majdoub',
    email: 'amine@test.com',
    mot_de_passe: 'password123',
    accountStatus: 'active',
    role: 'touriste',
    isEmailVerified: true
  });
  
  try {
    await testUser.save();
    console.log('Test user created successfully!');
    console.log('Username:', testUser.username);
    console.log('Fullname:', testUser.fullname);
    console.log('Status:', testUser.accountStatus);
  } catch (error) {
    console.error('Error creating user:', error.message);
    
    // Si l'utilisateur existe déjà, l'activer
    if (error.code === 11000) {
      console.log('User already exists, activating...');
      await User.findOneAndUpdate(
        { username: 'aminemajdoub_discover' },
        { accountStatus: 'active' }
      );
      console.log('User activated!');
    }
  }
  
  // Créer quelques autres utilisateurs de test
  const testUsers = [
    { username: 'alice_tourist', fullname: 'Alice Tourist', role: 'touriste' },
    { username: 'bob_organizer', fullname: 'Bob Organizer', role: 'organisator' },
    { username: 'charlie_guide', fullname: 'Charlie Guide', role: 'touriste' }
  ];
  
  for (const userData of testUsers) {
    try {
      const user = new User({
        ...userData,
        email: `${userData.username}@test.com`,
        mot_de_passe: 'password123',
        accountStatus: 'active',
        isEmailVerified: true
      });
      await user.save();
      console.log(`Created user: ${user.username}`);
    } catch (error) {
      if (error.code === 11000) {
        console.log(`User ${userData.username} already exists, activating...`);
        await User.findOneAndUpdate(
          { username: userData.username },
          { accountStatus: 'active' }
        );
      }
    }
  }
  
  // Vérifier le résultat
  const activeUsers = await User.find({ accountStatus: 'active' })
    .select('username fullname role');
  console.log('\nActive users now:');
  activeUsers.forEach(u => {
    console.log(`- ${u.username} (${u.fullname}) - ${u.role}`);
  });
  
  process.exit(0);
})
.catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
