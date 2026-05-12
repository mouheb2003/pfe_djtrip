/**
 * Script pour générer un username pour un utilisateur spécifique
 * Utilise le système de génération de username unique et symbolique
 */

const mongoose = require('mongoose');
const { createUsernameForUser, isValidUsername } = require('./utils/usernameGenerator');
const User = require('./models/user');

// MongoDB connection
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/djtrip';

async function generateUsernameForSpecificUser(userId) {
  try {
    await mongoose.connect(MONGODB_URI);
    console.log('🔗 Connected to MongoDB');

    // Trouver l'utilisateur par ID
    const user = await User.findById(userId);
    if (!user) {
      console.error('❌ User not found with ID:', userId);
      return;
    }

    console.log(`\n👤 User found: ${user.fullname} (${user.email})`);
    console.log(`Current username: ${user.username || 'None'}`);

    if (user.username && user.username.trim() !== '') {
      console.log('✅ User already has a username!');
      
      // Proposer de nouvelles suggestions
      const checkExists = async (username) => {
        const existing = await User.findOne({ 
          username: username.toLowerCase(),
          _id: { $ne: userId }
        });
        return !!existing;
      };

      const existingUsernames = await User.find({ 
        _id: { $ne: userId },
        username: { $exists: true, $ne: null, $ne: '' }
      }).select('username').lean().then(users => users.map(u => u.username).filter(Boolean));

      const suggestions = require('./utils/usernameGenerator').generateUsernameSuggestions(
        user.fullname, 
        existingUsernames, 
        5
      );

      console.log('\n💡 Username suggestions:');
      suggestions.forEach((suggestion, index) => {
        console.log(`  ${index + 1}. @${suggestion}`);
      });

      return;
    }

    // Fonction pour vérifier si un username existe
    const checkExists = async (username) => {
      const existing = await User.findOne({ 
        username: username.toLowerCase(),
        _id: { $ne: userId }
      });
      return !!existing;
    };

    // Générer un username unique
    const generatedUsername = await createUsernameForUser(user.fullname, checkExists);
    
    // Mettre à jour l'utilisateur
    const updatedUser = await User.findByIdAndUpdate(
      userId,
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

    console.log(`\n✅ Username generated and assigned: @${generatedUsername}`);
    console.log(`👤 User: ${updatedUser.fullname}`);
    console.log(`📧 Email: ${updatedUser.email}`);
    console.log(`🆔 Updated at: ${updatedUser.updatedAt}`);

    // Vérifier que le username est bien unique
    const isUnique = !(await checkExists(generatedUsername));
    console.log(`🔍 Uniqueness check: ${isUnique ? '✅ Unique' : '❌ Conflict'}`);

  } catch (error) {
    console.error('❌ Error generating username:', error);
  } finally {
    await mongoose.disconnect();
    console.log('\n🔌 Disconnected from MongoDB');
  }
}

// Point d'entrée principal
if (require.main === module) {
  const userId = process.argv[2];
  
  if (!userId) {
    console.log('📋 Usage: node generate_username_for_user.js <user_id>');
    console.log('\n💡 Example: node generate_username_for_user.js 69ab6710f3c2a4172e14a6f0');
    process.exit(1);
  }

  console.log(`🚀 Generating username for user: ${userId}\n`);
  generateUsernameForSpecificUser(userId);
}

module.exports = { generateUsernameForSpecificUser };
