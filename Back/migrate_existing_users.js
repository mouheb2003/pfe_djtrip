/**
 * Script de migration pour générer des usernames pour les utilisateurs existants
 * Génère automatiquement un username symbolique unique pour chaque utilisateur sans username
 */

const mongoose = require('mongoose');
const { createUsernameForUser } = require('./utils/usernameGenerator');
const User = require('./models/user');

// MongoDB connection
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/djtrip';

async function migrateExistingUsers() {
  try {
    await mongoose.connect(MONGODB_URI);
    console.log('🔗 Connected to MongoDB');

    // Trouver tous les utilisateurs sans username
    const usersWithoutUsername = await User.find({ 
      username: { $exists: false } 
    });

    console.log(`\n📊 Found ${usersWithoutUsername.length} users without username`);

    if (usersWithoutUsername.length === 0) {
      console.log('✅ All users already have usernames!');
      return;
    }

    let successCount = 0;
    let errorCount = 0;

    // Fonction pour vérifier si un username existe
    const checkExists = async (username) => {
      const existing = await User.findOne({ 
        username: username.toLowerCase() 
      });
      return !!existing;
    };

    // Traiter chaque utilisateur
    for (const user of usersWithoutUsername) {
      try {
        const fullname = user.fullname || 'User';
        console.log(`\n🔄 Processing: ${fullname} (${user.email})`);

        // Générer un username unique
        const generatedUsername = await createUsernameForUser(fullname, checkExists);
        
        // Mettre à jour l'utilisateur
        await User.findByIdAndUpdate(
          user._id,
          { 
            username: generatedUsername,
            updatedAt: new Date()
          },
          { new: true }
        );

        console.log(`✅ Username generated: @${generatedUsername}`);
        successCount++;

      } catch (error) {
        console.error(`❌ Error processing ${user.email}:`, error.message);
        errorCount++;
      }
    }

    console.log('\n🎯 MIGRATION SUMMARY');
    console.log(`✅ Successfully migrated: ${successCount} users`);
    console.log(`❌ Failed migrations: ${errorCount} users`);
    console.log(`📊 Total processed: ${usersWithoutUsername.length} users`);

    if (errorCount === 0) {
      console.log('\n🚀 Migration completed successfully!');
    } else {
      console.log('\n⚠️ Migration completed with some errors');
    }

  } catch (error) {
    console.error('❌ Migration error:', error);
  } finally {
    await mongoose.disconnect();
    console.log('\n🔌 Disconnected from MongoDB');
  }
}

// Fonction pour vérifier l'état de la migration
async function checkMigrationStatus() {
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

    console.log('\n📊 MIGRATION STATUS');
    console.log(`👥 Total users: ${totalUsers}`);
    console.log(`✅ Users with username: ${usersWithUsername}`);
    console.log(`❌ Users without username: ${usersWithoutUsername}`);
    console.log(`📈 Migration progress: ${((usersWithUsername / totalUsers) * 100).toFixed(1)}%`);

    if (usersWithoutUsername === 0) {
      console.log('\n🎉 All users have usernames!');
    } else {
      console.log('\n⚠️ Some users still need usernames');
      console.log('💡 Run: node migrate_existing_users.js migrate');
    }

  } catch (error) {
    console.error('❌ Status check error:', error);
  } finally {
    await mongoose.disconnect();
    console.log('\n🔌 Disconnected from MongoDB');
  }
}

// Fonction pour annuler les usernames générés (rollback)
async function rollbackUsernames() {
  try {
    await mongoose.connect(MONGODB_URI);
    console.log('🔗 Connected to MongoDB');

    console.log('\n⚠️ ROLLBACK: Removing generated usernames...');
    
    // Supprimer le champ username pour tous les utilisateurs
    const result = await User.updateMany(
      {}, // Filtre vide = tous les utilisateurs
      { 
        $unset: { username: 1 },
        updatedAt: new Date()
      }
    );

    console.log(`✅ Removed usernames from ${result.modifiedCount} users`);
    console.log('\n🔄 Rollback completed!');

  } catch (error) {
    console.error('❌ Rollback error:', error);
  } finally {
    await mongoose.disconnect();
    console.log('\n🔌 Disconnected from MongoDB');
  }
}

// Point d'entrée principal
if (require.main === module) {
  const command = process.argv[2];
  
  switch (command) {
    case 'migrate':
      console.log('🚀 Starting username migration for existing users...\n');
      migrateExistingUsers();
      break;
      
    case 'status':
      console.log('📊 Checking migration status...\n');
      checkMigrationStatus();
      break;
      
    case 'rollback':
      console.log('⚠️ Starting rollback...\n');
      console.log('⚠️ WARNING: This will remove all generated usernames!');
      rollbackUsernames();
      break;
      
    default:
      console.log('📋 Available commands:');
      console.log('  node migrate_existing_users.js migrate  - Generate usernames for users without them');
      console.log('  node migrate_existing_users.js status   - Check migration status');
      console.log('  node migrate_existing_users.js rollback - Remove all generated usernames (DANGEROUS)');
      console.log('\n💡 Recommended: Run "status" first, then "migrate"');
      break;
  }
}

module.exports = { 
  migrateExistingUsers, 
  checkMigrationStatus, 
  rollbackUsernames 
};
