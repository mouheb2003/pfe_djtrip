const mongoose = require('mongoose');
require('dotenv').config();

/**
 * Script to fix the duplicate key error on payments.token index
 * Drops the existing token_1 index and creates a new sparse index
 */

async function fixPaymentIndex() {
  try {
    console.log('Connecting to MongoDB...');
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('Connected to MongoDB');

    const db = mongoose.connection.db;
    const paymentsCollection = db.collection('payments');

    console.log('Checking existing indexes on payments collection...');
    const indexes = await paymentsCollection.indexes();
    console.log('Current indexes:', indexes);

    // Check if token_1 index exists
    const tokenIndex = indexes.find(idx => idx.name === 'token_1');
    
    if (tokenIndex) {
      console.log('Found token_1 index, dropping it...');
      await paymentsCollection.dropIndex('token_1');
      console.log('token_1 index dropped successfully');
    } else {
      console.log('No token_1 index found');
    }

    console.log('Creating sparse index on token field...');
    // Create a sparse index that allows multiple null values
    await paymentsCollection.createIndex(
      { token: 1 },
      { 
        unique: true, 
        sparse: true,
        name: 'token_1'
      }
    );
    console.log('Sparse token index created successfully');

    console.log('Verifying new indexes...');
    const newIndexes = await paymentsCollection.indexes();
    console.log('New indexes:', newIndexes);

    console.log('Fix completed successfully!');
  } catch (error) {
    console.error('Error fixing payment index:', error);
    process.exit(1);
  } finally {
    await mongoose.disconnect();
    console.log('Disconnected from MongoDB');
    process.exit(0);
  }
}

fixPaymentIndex();
