/**
 * Script pour générer un username pour un utilisateur spécifique avec ID exact
 * Utilise l'ID exact fourni par l'utilisateur
 */

const mongoose = require('mongoose');
const { createUsernameForUser, generateUsernameSuggestions } = require('./utils/usernameGenerator');
const User = require('./models/user');

// MongoDB connection
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/djtrip';

async function generateUsernameForUser(userId, options = {}) {
  try {
    await mongoose.connect(MONGODB_URI);
    console.log('🔗 Connected to MongoDB');

    const { 
      force = false,
      dryRun = false 
    } = options;

    console.log(`\n🚀 Generating username for user ID: ${userId}`);
    console.log(`⚙️ Options: force=${force}, dryRun=${dryRun}`);

    // Essayer de trouver l'utilisateur avec l'ID exact
    let user = null;
    
    // Essayer avec l'ID exact
    user = await User.findById(userId);
    if (user) {
      console.log(`✅ User found with findById: ${user.fullname} (${user.email})`);
    }

    // Si pas trouvé, essayer avec d'autres méthodes
    if (!user) {
      console.log('🔍 User not found with findById, trying alternative methods...');
      
      // Essayer avec ObjectId
      try {
        const ObjectId = require('mongodb').ObjectId;
        user = await User.findById(new ObjectId(userId));
        if (user) {
          console.log(`✅ User found with ObjectId: ${user.fullname} (${user.email})`);
        }
      } catch (e) {
        console.log('❌ ObjectId conversion failed');
      }
    }

    // Si toujours pas trouvé, essayer avec recherche par email
    if (!user) {
      console.log('🔍 Trying to find by email...');
      user = await User.findOne({ email: 'aminmj527@gmail.com' });
      if (user) {
        console.log(`✅ User found by email: ${user.fullname} (${user._id})`);
      }
    }

    if (!user) {
      console.error('❌ User not found with any method');
      
      // Afficher tous les utilisateurs disponibles
      const allUsers = await User.find({}).select('_id fullname email username').limit(5).lean();
      console.log('\n📊 Available users in database:');
      allUsers.forEach((u, index) => {
        console.log(`  ${index + 1}. ID: ${u._id}, Name: ${u.fullname}, Email: ${u.email}, Username: ${u.username || 'None'}`);
      });
      return;
    }

    console.log(`\n👤 User Details:`);
    console.log(`  ID: ${user._id}`);
    console.log(`  Name: ${user.fullname}`);
    console.log(`  Email: ${user.email}`);
    console.log(`  Current username: ${user.username || 'None'}`);
    console.log(`  User Type: ${user.userType}`);

    // Vérifier si déjà un username
    if (!force && user.username && user.username.trim() !== '') {
      console.log('\n✅ User already has username!');
      console.log(`🆔 Current username: @${user.username}`);
      
      // Proposer des alternatives
      const existingUsernames = await User.find({ 
        _id: { $ne: user._id },
        username: { $exists: true, $ne: null, $ne: '' } 
      }).select('username').lean().then(users => users.map(u => u.username).filter(Boolean));

      const suggestions = generateUsernameSuggestions(user.fullname, existingUsernames, 5);
      console.log('\n💡 Alternative username suggestions:');
      suggestions.forEach((suggestion, index) => {
        console.log(`  ${index + 1}. @${suggestion}`);
      });
      return;
    }

    // Fonction pour vérifier si un username existe
    const checkExists = async (username) => {
      const existing = await User.findOne({ 
        username: username.toLowerCase(),
        _id: { $ne: user._id }
      });
      return !!existing;
    };

    // Mode dry run
    if (dryRun) {
      const generatedUsername = await createUsernameForUser(user.fullname, checkExists);
      console.log(`\n🔍 Generated username (DRY RUN): @${generatedUsername}`);
      console.log('💡 Use --dry-run=false to actually save the username');
      return;
    }

    // Générer et sauvegarder le username
    console.log('\n🔄 Generating unique username...');
    const generatedUsername = await createUsernameForUser(user.fullname, checkExists);
    
    // Mettre à jour l'utilisateur
    const updatedUser = await User.findByIdAndUpdate(
      user._id,
      { 
        username: generatedUsername,
        updatedAt: new Date()
      },
      { new: true, select: 'username fullname email avatar' }
    );

    if (!updatedUser) {
      console.error('❌ Failed to update user');
      return;
    }

    console.log(`\n🎉 SUCCESS! Username generated and saved:`);
    console.log(`🆔 Username: @${generatedUsername}`);
    console.log(`👤 User: ${updatedUser.fullname}`);
    console.log(`📧 Email: ${updatedUser.email}`);
    console.log(`🕐 Updated at: ${updatedUser.updatedAt}`);

    // Vérifier l'unicité
    const isUnique = !(await checkExists(generatedUsername));
    console.log(`🔍 Uniqueness check: ${isUnique ? '✅ Unique' : '❌ Conflict'}`);

    // Afficher le profil mis à jour
    console.log('\n📱 Updated User Profile:');
    console.log(`  Username: @${updatedUser.username}`);
    console.log(`  Fullname: ${updatedUser.fullname}`);
    console.log(`  Email: ${updatedUser.email}`);
    console.log(`  Avatar: ${updatedUser.avatar || 'None'}`);

  } catch (error) {
    console.error('❌ Error generating username:', error);
    console.error('Stack:', error.stack);
  } finally {
    await mongoose.disconnect();
    console.log('\n🔌 Disconnected from MongoDB');
  }
}

// Point d'entrée principal
if (require.main === module) {
  const userId = process.argv[2];
  const options = {};
  
  // Parser les options
  for (let i = 3; i < process.argv.length; i++) {
    const arg = process.argv[i];
    if (arg.startsWith('--force=')) {
      options.force = arg.split('=')[1] === 'true';
    } else if (arg.startsWith('--dry-run')) {
      options.dryRun = true;
    }
  }
  
  if (!userId) {
    console.log('📋 Usage: node generate_username_specific.js <user_id> [options]');
    console.log('\n💡 Examples:');
    console.log('  node generate_username_specific.js 69ab6710f3c2a4172e14a6f0');
    console.log('  node generate_username_specific.js 69ab6710f3c2a4172e14a6f0 --force=true');
    console.log('  node generate_username_specific.js 69ab6710f3c2a4172e14a6f0 --dry-run');
    console.log('\n⚙️ Options:');
    console.log('  --force=true    - Force regenerate even if user has username');
    console.log('  --dry-run       - Show what would be generated without saving');
    process.exit(1);
  }

  console.log(`🚀 Starting username generation for user: ${userId}\n`);
  generateUsernameForUser(userId, options);
}

module.exports = { generateUsernameForUser };
