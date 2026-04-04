require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });

const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const Admin = require('../models/admin');

async function seedAdmin() {
  const mongoUri = process.env.MONGODB_URI;

  if (!mongoUri) {
    throw new Error('MONGODB_URI is missing in Back/.env');
  }

  await mongoose.connect(mongoUri);

  const email = 'admin';
  const plainPassword = 'admin';
  const hashedPassword = await bcrypt.hash(plainPassword, 10);

  const existing = await Admin.findOne({ email });

  if (existing) {
    existing.mot_de_passe = hashedPassword;
    existing.accountStatus = 'active';
    existing.emailVerified = true;
    existing.fullname = existing.fullname || 'Administrator';
    await existing.save();
    console.log('Admin account updated: admin/admin');
  } else {
    await Admin.create({
      fullname: 'Administrator',
      email,
      mot_de_passe: hashedPassword,
      accountStatus: 'active',
      emailVerified: true,
      managedBy: 'System',
    });
    console.log('Admin account created: admin/admin');
  }
}

seedAdmin()
  .then(async () => {
    await mongoose.disconnect();
    process.exit(0);
  })
  .catch(async (error) => {
    console.error('Failed to seed admin account:', error.message);
    try {
      await mongoose.disconnect();
    } catch {
      // ignore disconnect errors
    }
    process.exit(1);
  });
