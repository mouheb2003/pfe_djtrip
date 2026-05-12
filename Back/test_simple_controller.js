/**
 * Test simple pour vérifier le contrôleur de mentions
 */

// Test simple du contrôleur
try {
  console.log('🧪 Test du contrôleur de mentions...');
  
  // Importer le contrôleur
  const mentionController = require('./controllers/mentionController');
  
  // Vérifier si les fonctions existent
  if (typeof mentionController.searchMentions === 'function') {
    console.log('✅ searchMentions: Fonction définie');
  } else {
    console.log('❌ searchMentions: Non définie');
  }
  
  if (typeof mentionController.validateMentions === 'function') {
    console.log('✅ validateMentions: Fonction définie');
  } else {
    console.log('❌ validateMentions: Non définie');
  }
  
  if (typeof mentionController.saveMentions === 'function') {
    console.log('✅ saveMentions: Fonction définie');
  } else {
    console.log('❌ saveMentions: Non définie');
  }
  
  if (typeof mentionController.getPostMentions === 'function') {
    console.log('✅ getPostMentions: Fonction définie');
  } else {
    console.log('❌ getPostMentions: Non définie');
  }
  
  console.log('\n🎯 Test terminé !');
  
} catch (error) {
  console.error('❌ Erreur lors du test:', error.message);
}
