const admin = require('firebase-admin');

/**
 * Firebase Admin SDK Configuration
 * Production-ready initialization using Base64-encoded environment variable
 */

let firebaseInitialized = false;

/**
 * Decode Base64 string and parse as JSON
 * @param {string} base64String - Base64 encoded JSON string
 * @returns {Object} Parsed JSON object
 * @throws {Error} If Base64 is invalid or JSON parsing fails
 */
function decodeBase64ServiceAccount(base64String) {
  try {
    // Decode Base64 to UTF-8 string
    const decodedString = Buffer.from(base64String, 'base64').toString('utf-8');
    
    // Parse JSON
    const serviceAccount = JSON.parse(decodedString);
    
    // Validate required fields
    const requiredFields = ['type', 'project_id', 'private_key_id', 'private_key', 'client_email'];
    const missingFields = requiredFields.filter(field => !serviceAccount[field]);
    
    if (missingFields.length > 0) {
      throw new Error(`Missing required fields in service account: ${missingFields.join(', ')}`);
    }
    
    return serviceAccount;
  } catch (error) {
    if (error instanceof SyntaxError) {
      throw new Error('Invalid JSON in Firebase service account');
    }
    throw new Error(`Failed to decode Firebase service account: ${error.message}`);
  }
}

/**
 * Initialize Firebase Admin SDK using environment variable
 * @throws {Error} If FIREBASE_KEY_BASE64 is missing or invalid
 */
function initializeFirebase() {
  if (firebaseInitialized) {
    console.log('✅ Firebase Admin SDK already initialized');
    return;
  }

  try {
    // Get Base64-encoded service account from environment variable
    const firebaseKeyBase64 = process.env.FIREBASE_KEY_BASE64;

    if (!firebaseKeyBase64) {
      throw new Error('FIREBASE_KEY_BASE64 environment variable is not set');
    }

    // Decode and parse the service account
    const serviceAccount = decodeBase64ServiceAccount(firebaseKeyBase64);

    // Initialize Firebase Admin SDK
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });

    firebaseInitialized = true;
    console.log('✅ Firebase Admin SDK initialized successfully from environment variable');
  } catch (error) {
    console.error('❌ Failed to initialize Firebase Admin SDK:', error.message);
    console.error('📝 Make sure FIREBASE_KEY_BASE64 environment variable is set with a valid Base64-encoded service account JSON');
    
    // For development: allow app to continue without Firebase
    // In production, you might want to throw the error to prevent startup
    if (process.env.NODE_ENV === 'production') {
      throw error;
    }
  }
}

/**
 * Get Firebase Admin instance
 * @returns {Object} Firebase Admin instance
 * @throws {Error} If Firebase is not initialized
 */
function getFirebaseAdmin() {
  if (!firebaseInitialized) {
    throw new Error('Firebase Admin SDK is not initialized. Call initializeFirebase() first.');
  }
  return admin;
}

/**
 * Check if Firebase is initialized
 * @returns {boolean} True if initialized
 */
function isInitialized() {
  return firebaseInitialized;
}

module.exports = {
  initializeFirebase,
  getFirebaseAdmin,
  isInitialized,
  decodeBase64ServiceAccount, // Export for testing purposes
};
