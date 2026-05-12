/**
 * Script pour vérifier l'état de la base de données et trouver des utilisateurs
 */

const mongoose = require('mongoose');
const User = require('./models/user');

// MongoDB connection
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/djtrip';

async function checkDatabase() {
  try {
    await mongoose.connect(MONGODB_URI);
    console.log('🔗 Connected to MongoDB');

    // Compter tous les utilisateurs
    const totalUsers = await User.countDocuments();
    console.log(`\n📊 Total users in database: ${totalUsers}`);

    // Afficher les 5 premiers utilisateurs
    const firstUsers = await User.find({}).select('_id fullname email username userType').limit(5).lean();
    console.log('\n👥 First 5 users:');
    firstUsers.forEach((user, index) => {
      console.log(`  ${index + 1}. ID: ${user._id}`);
      console.log(`     Name: ${user.fullname}`);
      console.log(`     Email: ${user.email}`);
      console.log(`     Username: ${user.username || 'None'}`);
      console.log(`     Type: ${user.userType}`);
      console.log('');
    });

    // Chercher l'utilisateur spécifique par ID
    console.log('🔍 Searching for user by ID: 69ab6710f3c2a4172e14a6f0');
    const userById = await User.findById('69ab6710f3c2a4172e14a6f0');
    if (userById) {
      console.log('✅ User found by ID!');
      console.log(`  Name: ${userById.fullname}`);
      console.log(`  Email: ${userById.email}`);
      console.log(`  Username: ${userById.username || 'None'}`);
    } else {
      console.log('❌ User NOT found by ID');
    }

    // Chercher par email
    console.log('\n🔍 Searching for user by email: aminmj527@gmail.com');
    const userByEmail = await User.findOne({ email: 'aminmj527@gmail.com' });
    if (userByEmail) {
      console.log('✅ User found by email!');
      console.log(`  ID: ${userByEmail._id}`);
      console.log(`  Name: ${userByEmail.fullname}`);
      console.log(`  Username: ${userByEmail.username || 'None'}`);
    } else {
      console.log('❌ User NOT found by email');
    }

    // Chercher par nom "touriste"
    console.log('\n🔍 Searching for users with name: "touriste"');
    const usersByName = await User.find({ fullname: 'touriste' }).select('_id fullname email username');
    console.log(`Found ${usersByName.length} users with name "touriste":`);
    usersByName.forEach((user, index) => {
      console.log(`  ${index + 1}. ID: ${user._id}, Email: ${user.email}, Username: ${user.username || 'None'}`);
    });

    // Afficher les statistiques des usernames
    const usersWithUsername = await User.countDocuments({ 
      username: { $exists: true, $ne: null, $ne: '' } 
    });
    const usersWithoutUsername = await User.countDocuments({ 
      username: { $exists: false } 
    });

    console.log('\n📈 Username Statistics:');
    console.log(`  Users with username: ${usersWithUsername}`);
    console.log(`  Users without username: ${usersWithoutUsername}`);
    console.log(`  Coverage: ${totalUsers > 0 ? ((usersWithUsername / totalUsers) * 100).toFixed(1) : 0}%`);

    // Afficher tous les IDs pour debug
    console.log('\n🔍 All user IDs in database:');
    const allUsers = await User.find({}).select('_id fullname email').limit(10).lean();
    allUsers.forEach((user, index) => {
      console.log(`  ${index + 1}. ${user._id} - ${user.fullname} (${user.email})`);
    });

  } catch (error) {
    console.error('❌ Error checking database:', error);
  } finally {
    await mongoose.disconnect();
    console.log('\n🔌 Disconnected from MongoDB');
  }
}

// Point d'entrée principal
if (require.main === module) {
  console.log('🔍 Checking database state...\n');
  checkDatabase();
}

module.exports = { checkDatabase };
