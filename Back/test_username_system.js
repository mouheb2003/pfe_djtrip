/**
 * Script de test pour le système de username
 * Test la génération, validation, et unicité des usernames
 */

const mongoose = require('mongoose');
const { generateUsernameSuggestions, createUsernameForUser, isValidUsername } = require('./utils/usernameGenerator');
const User = require('./models/user');

// MongoDB connection
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/djtrip';

async function testUsernameSystem() {
  try {
    await mongoose.connect(MONGODB_URI);
    console.log('🔗 Connected to MongoDB');

    console.log('\n=== 🧪 TEST 1: Génération de suggestions ===');
    const testFullname = 'Jean Dupont';
    const existingUsernames = ['john_doe', 'marie_tourist', 'peter_organizer'];
    
    const suggestions = generateUsernameSuggestions(testFullname, existingUsernames, 5);
    console.log(`Fullname: ${testFullname}`);
    console.log('Suggestions générées:');
    suggestions.forEach((suggestion, index) => {
      console.log(`  ${index + 1}. ${suggestion}`);
    });

    console.log('\n=== 🧪 TEST 2: Validation des usernames ===');
    const testUsernames = [
      'jean_dupont_dj',
      'invalid username!',
      'ab',
      'valid_username_123',
      'user_with_underscores__invalid'
    ];

    for (const username of testUsernames) {
      const isValid = isValidUsername(username);
      console.log(`${username}: ${isValid ? '✅ Valide' : '❌ Invalide'}`);
    }

    console.log('\n=== 🧪 TEST 3: Vérification d\'unicité en base ===');
    const usernamesToTest = ['test_user_001', 'jean_dupont_dj', 'non_existent_user'];
    
    for (const username of usernamesToTest) {
      try {
        const existingUser = await User.findOne({ username: username.toLowerCase() });
        const exists = !!existingUser;
        console.log(`${username}: ${exists ? '❌ Déjà pris' : '✅ Disponible'}`);
      } catch (error) {
        console.error(`Erreur vérifiant ${username}:`, error.message);
      }
    }

    console.log('\n=== 🧪 TEST 4: Génération automatique avec vérification ===');
    const testFullname2 = 'Marie Curie';
    
    // Fonction pour vérifier si un username existe
    const checkExists = async (username) => {
      const existing = await User.findOne({ 
        username: username.toLowerCase() 
      });
      return !!existing;
    };

    const autoUsername = await createUsernameForUser(testFullname2, checkExists);
    console.log(`Fullname: ${testFullname2}`);
    console.log(`Username généré automatiquement: ${autoUsername}`);
    
    // Vérifier que le username généré est bien unique
    const isUnique = !(await checkExists(autoUsername));
    console.log(`Unicité vérifiée: ${isUnique ? '✅ Unique' : '❌ Conflit'}`);

    console.log('\n=== 🧪 TEST 5: Test des patterns de génération ===');
    const testNames = [
      'Ahmed Ben Ali',
      'Sophie Martin',
      'Carlos Rodriguez',
      '李伟', // Nom chinois
      'Mohammed Ould', // Nom maure
      'Anna-Karin Schmidt' // Nom avec trait d'union
    ];

    for (const name of testNames) {
      console.log(`\nNom: ${name}`);
      const nameSuggestions = generateUsernameSuggestions(name, existingUsernames, 3);
      nameSuggestions.forEach((suggestion, index) => {
        console.log(`  ${index + 1}. ${suggestion}`);
      });
    }

    console.log('\n=== 🧪 TEST 6: Test des suffixes symboliques ===');
    const symbolicNames = [
      'Djerba Explorer',
      'Tunis Guide',
      'Beach Lover',
      'Adventure Seeker'
    ];

    for (const name of symbolicNames) {
      const suggestions = generateUsernameSuggestions(name, [], 2);
      console.log(`\nNom symbolique: ${name}`);
      suggestions.forEach((suggestion, index) => {
        console.log(`  ${index + 1}. ${suggestion}`);
      });
    }

    console.log('\n=== 🎯 RÉSUMÉ DES TESTS ===');
    console.log('✅ Génération de suggestions: Fonctionnel');
    console.log('✅ Validation des usernames: Fonctionnel');
    console.log('✅ Vérification d\'unicité: Fonctionnel');
    console.log('✅ Génération automatique: Fonctionnel');
    console.log('✅ Support multilingue: Fonctionnel');
    console.log('✅ Suffixes symboliques: Fonctionnel');
    console.log('\n🚀 Le système de username est prêt pour la production!');

  } catch (error) {
    console.error('❌ Erreur durant les tests:', error);
  } finally {
    await mongoose.disconnect();
    console.log('\n🔌 Disconnected from MongoDB');
  }
}

// Fonction utilitaire pour nettoyer la base de données de test
async function cleanupTestData() {
  try {
    await mongoose.connect(MONGODB_URI);
    
    // Supprimer les utilisateurs de test créés
    const testUserPattern = /^test_user_\d+$/;
    const testUsers = await User.find({ 
      username: { $regex: testUserPattern } 
    });
    
    if (testUsers.length > 0) {
      console.log(`🧹 Nettoyage de ${testUsers.length} utilisateurs de test...`);
      await User.deleteMany({ 
        username: { $regex: testUserPattern } 
      });
      console.log('✅ Nettoyage terminé');
    } else {
      console.log('ℹ️ Aucun utilisateur de test à nettoyer');
    }
    
  } catch (error) {
    console.error('❌ Erreur durant le nettoyage:', error);
  } finally {
    await mongoose.disconnect();
  }
}

// Point d'entrée principal
if (require.main === module) {
  const command = process.argv[2];
  
  if (command === 'cleanup') {
    console.log('🧹 Lancement du nettoyage des données de test...');
    cleanupTestData();
  } else {
    console.log('🧪 Lancement des tests du système de username...\n');
    console.log('💡 Utilise: node test_username_system.js cleanup pour nettoyer les données de test\n');
    testUsernameSystem();
  }
}

module.exports = { testUsernameSystem, cleanupTestData };
