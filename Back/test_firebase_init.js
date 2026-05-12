const { initializeFirebase, isInitialized } = require('./config/firebase');

console.log('🔧 Testing Firebase initialization...');

try {
  initializeFirebase();
  
  if (isInitialized()) {
    console.log('✅ Firebase initialized successfully');
  } else {
    console.log('❌ Firebase not initialized');
  }
} catch (error) {
  console.error('❌ Error initializing Firebase:', error.message);
}

process.exit(0);
