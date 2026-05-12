/**
 * Script pour générer/régénérer des usernames pour TOUS les utilisateurs
 * Génère des usernames symboliques uniques pour chaque utilisateur
 */

const mongoose = require('mongoose');
const { createUsernameForUser, generateUsernameSuggestions } = require('./utils/usernameGenerator');
const User = require('./models/user');

// MongoDB connection
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/djtrip';

async function generateUsernamesForAllUsers(options = {}) {
  try {
    await mongoose.connect(MONGODB_URI);
    console.log('🔗 Connected to MongoDB');

    const { 
      force = false,           // Force la régénération même si déjà un username
      skipExisting = false,  // Ignorer les utilisateurs avec déjà un username
      limit = null,          // Limiter le nombre d'utilisateurs à traiter
      dryRun = false         // Mode test (ne pas sauvegarder)
    } = options;

    console.log(`\n⚙️ OPTIONS:`);
    console.log(`  Force regenerate: ${force}`);
    console.log(`  Skip existing: ${skipExisting}`);
    console.log(`  Limit: ${limit || 'All'}`);
    console.log(`  Dry run: ${dryRun}`);
    console.log('');

    // Construire la requête de base
    let query = {};
    if (skipExisting) {
      query.username = { $exists: false };
    }

    let cursor = User.find(query);
    if (limit) {
      cursor = cursor.limit(limit);
    }

    const allUsers = await cursor.exec();
    console.log(`📊 Found ${allUsers.length} users to process`);

    if (allUsers.length === 0) {
      console.log('ℹ️ No users found matching criteria');
      return;
    }

    // Récupérer tous les usernames existants pour éviter les doublons
    const existingUsernames = await User.find({ 
      username: { $exists: true, $ne: null, $ne: '' } 
    }).select('username').lean().then(users => users.map(u => u.username).filter(Boolean));

    console.log(`🔍 Found ${existingUsernames.length} existing usernames`);

    let successCount = 0;
    let skipCount = 0;
    let errorCount = 0;
    let updateCount = 0;

    // Fonction pour vérifier si un username existe
    const checkExists = async (username, excludeUserId = null) => {
      const existing = await User.findOne({ 
        username: username.toLowerCase(),
        _id: { $ne: excludeUserId }
      });
      return !!existing;
    };

    // Traiter chaque utilisateur
    for (let i = 0; i < allUsers.length; i++) {
      const user = allUsers[i];
      const progress = Math.round(((i + 1) / allUsers.length) * 100);
      
      try {
        console.log(`\n🔄 [${progress}%] Processing: ${user.fullname || 'User'} (${user.email})`);
        
        // Vérifier si l'utilisateur a déjà un username
        if (!force && user.username && user.username.trim() !== '') {
          console.log(`⏭️ Skipping: Already has username @${user.username}`);
          skipCount++;
          continue;
        }

        // Générer suggestions (mode dry run)
        if (dryRun) {
          const suggestions = generateUsernameSuggestions(user.fullname || 'User', existingUsernames, 3);
          console.log(`💡 Suggestions for ${user.fullname}:`);
          suggestions.forEach((suggestion, index) => {
            console.log(`  ${index + 1}. @${suggestion}`);
          });
          successCount++;
          continue;
        }

        // Générer un username unique
        const generatedUsername = await createUsernameForUser(
          user.fullname || 'User', 
          checkExists
        );

        if (dryRun) {
          console.log(`🔍 Generated: @${generatedUsername} (DRY RUN - NOT SAVED)`);
        } else {
          // Mettre à jour l'utilisateur
          await User.findByIdAndUpdate(
            user._id,
            { 
              username: generatedUsername,
              updatedAt: new Date()
            },
            { new: true, select: 'username fullname email' }
          );

          console.log(`✅ Generated: @${generatedUsername}`);
          updateCount++;
        }

        successCount++;

        // Ajouter à la liste des usernames existants pour éviter les doublons dans la suite
        if (!dryRun && !existingUsernames.includes(generatedUsername)) {
          existingUsernames.push(generatedUsername);
        }

      } catch (error) {
        console.error(`❌ Error processing ${user.email}:`, error.message);
        errorCount++;
      }
    }

    console.log('\n🎯 GENERATION SUMMARY');
    console.log(`✅ Successfully processed: ${successCount} users`);
    console.log(`⏭️ Skipped (existing): ${skipCount} users`);
    console.log(`🔄 Updated: ${updateCount} users`);
    console.log(`❌ Failed: ${errorCount} users`);
    console.log(`📊 Total processed: ${allUsers.length} users`);

    if (dryRun) {
      console.log('\n🔍 DRY RUN COMPLETED - No changes saved');
    } else if (errorCount === 0) {
      console.log('\n🚀 Generation completed successfully!');
    } else {
      console.log('\n⚠️ Generation completed with some errors');
    }

  } catch (error) {
    console.error('❌ Generation error:', error);
  } finally {
    await mongoose.disconnect();
    console.log('\n🔌 Disconnected from MongoDB');
  }
}

// Fonction pour afficher les statistiques actuelles
async function showUsernameStats() {
  try {
    await mongoose.connect(MONGODB_URI);
    console.log('🔗 Connected to MongoDB');

    const totalUsers = await User.countDocuments();
    const usersWithUsername = await User.countDocuments({ 
      username: { $exists: true, $ne: null, $ne: '' } 
    });
    const usersWithoutUsername = await User.countDocuments({ 
      username: { $exists: false } 
    });

    console.log('\n📊 USERNAME STATISTICS');
    console.log(`👥 Total users: ${totalUsers}`);
    console.log(`✅ Users with username: ${usersWithUsername}`);
    console.log(`❌ Users without username: ${usersWithoutUsername}`);
    console.log(`📈 Coverage: ${totalUsers > 0 ? ((usersWithUsername / totalUsers) * 100).toFixed(1) : 0}%`);

    // Afficher quelques exemples de usernames
    if (usersWithUsername > 0) {
      const sampleUsers = await User.find({ 
        username: { $exists: true, $ne: null, $ne: '' } 
      }).select('username fullname').limit(5).lean();
      
      console.log('\n💡 Sample usernames:');
      sampleUsers.forEach((user, index) => {
        console.log(`  ${index + 1}. @${user.username} (${user.fullname})`);
      });
    }

  } catch (error) {
    console.error('❌ Stats error:', error);
  } finally {
    await mongoose.disconnect();
    console.log('\n🔌 Disconnected from MongoDB');
  }
}

// Point d'entrée principal
if (require.main === module) {
  const command = process.argv[2];
  const options = {};
  
  // Parser les options
  for (let i = 3; i < process.argv.length; i++) {
    const arg = process.argv[i];
    if (arg.startsWith('--force=')) {
      options.force = arg.split('=')[1] === 'true';
    } else if (arg.startsWith('--skip-existing=')) {
      options.skipExisting = arg.split('=')[1] === 'true';
    } else if (arg.startsWith('--limit=')) {
      options.limit = parseInt(arg.split('=')[1]) || null;
    } else if (arg.startsWith('--dry-run')) {
      options.dryRun = true;
    }
  }
  
  switch (command) {
    case 'generate':
      console.log('🚀 Starting username generation for all users...\n');
      generateUsernamesForAllUsers(options);
      break;
      
    case 'stats':
      console.log('📊 Checking username statistics...\n');
      showUsernameStats();
      break;
      
    default:
      console.log('📋 Available commands:');
      console.log('  node generate_usernames_for_all.js generate [options] - Generate usernames for all users');
      console.log('  node generate_usernames_for_all.js stats          - Show username statistics');
      console.log('\n💡 Options for generate command:');
      console.log('  --force=true           - Force regenerate even if user has username');
      console.log('  --skip-existing=true   - Skip users who already have usernames');
      console.log('  --limit=100           - Process only first N users');
      console.log('  --dry-run             - Show what would be generated without saving');
      console.log('\n🔍 Examples:');
      console.log('  node generate_usernames_for_all.js generate --dry-run');
      console.log('  node generate_usernames_for_all.js generate --limit=50');
      console.log('  node generate_usernames_for_all.js generate --force=true');
      break;
  }
}

module.exports = { 
  generateUsernamesForAllUsers, 
  showUsernameStats 
};
