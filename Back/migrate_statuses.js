/**
 * Migration Script: French Status → English Status
 * Converts all existing Inscription documents with French statuses to English
 * Run once: node migrate_statuses.js
 */
require('dotenv').config();
const mongoose = require('mongoose');

async function migrateStatuses() {
  await mongoose.connect(process.env.MONGODB_URI || process.env.MONGO_URI);
  console.log('✅ Connected to MongoDB');

  const db = mongoose.connection.db;
  const collection = db.collection('inscriptions');

  const statusMap = {
    'en_attente': 'pending',
    'approuvee':  'approved',
    'refusee':    'rejected',
    'annulee':    'cancelled',
    'verifie':    'verified',
    // legacy English aliases kept for safety
    'approved':   'approved',
    'pending':    'pending',
    'rejected':   'rejected',
    'cancelled':  'cancelled',
    'verified':   'verified',
  };

  let totalUpdated = 0;

  for (const [oldStatus, newStatus] of Object.entries(statusMap)) {
    if (oldStatus === newStatus) continue; // skip already-English ones
    const result = await collection.updateMany(
      { statut: oldStatus },
      { $set: { statut: newStatus } }
    );
    if (result.modifiedCount > 0) {
      console.log(`  ✅ "${oldStatus}" → "${newStatus}": ${result.modifiedCount} documents`);
      totalUpdated += result.modifiedCount;
    }
  }

  console.log(`\n🏁 Migration complete. Total updated: ${totalUpdated}`);
  await mongoose.disconnect();
}

migrateStatuses().catch((err) => {
  console.error('❌ Migration failed:', err);
  process.exit(1);
});
