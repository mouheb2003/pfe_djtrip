/**
 * Test script to verify booking overlap validation
 * Run with: node test_booking_overlap.js
 */

const mongoose = require('mongoose');
const Inscription = require('./models/inscription');
const Activite = require('./models/activite');
const Touriste = require('./models/touriste');

// MongoDB connection
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/djtrip';

async function testOverlapValidation() {
  try {
    await mongoose.connect(MONGODB_URI);
    console.log('Connected to MongoDB');

    // Test data
    const touristId = 'TOURIST_ID_HERE'; // Replace with actual tourist ID
    const activity1Start = new Date('2026-05-10T08:00:00Z');
    const activity1End = new Date('2026-05-10T13:00:00Z'); // 5 hours duration
    
    const activity2Start = new Date('2026-05-10T10:00:00Z'); // Overlaps with activity 1
    const activity2End = new Date('2026-05-10T15:00:00Z');

    console.log('\n=== Test 1: No overlap (different dates) ===');
    const noOverlapStart = new Date('2026-05-11T08:00:00Z');
    const noOverlapEnd = new Date('2026-05-11T13:00:00Z');
    
    const result1 = await Inscription.checkBookingOverlap(
      touristId,
      noOverlapStart,
      noOverlapEnd
    );
    console.log('No overlap result:', result1);

    console.log('\n=== Test 2: Overlap detected (same day, overlapping times) ===');
    const result2 = await Inscription.checkBookingOverlap(
      touristId,
      activity2Start,
      activity2End
    );
    console.log('Overlap result:', result2);

    console.log('\n=== Test 3: Edge case - exact same time ===');
    const result3 = await Inscription.checkBookingOverlap(
      touristId,
      activity1Start,
      activity1End
    );
    console.log('Exact same time result:', result3);

    console.log('\n=== Test 4: Edge case - back-to-back activities ===');
    const backToBackStart = new Date('2026-05-10T13:00:00Z'); // Starts exactly when activity 1 ends
    const backToBackEnd = new Date('2026-05-10T18:00:00Z');
    
    const result4 = await Inscription.checkBookingOverlap(
      touristId,
      backToBackStart,
      backToBackEnd
    );
    console.log('Back-to-back result:', result4);

    console.log('\n=== Test 5: Partial overlap ===');
    const partialOverlapStart = new Date('2026-05-10T07:00:00Z'); // Starts before activity 1
    const partialOverlapEnd = new Date('2026-05-10T09:00:00Z'); // Ends during activity 1
    
    const result5 = await Inscription.checkBookingOverlap(
      touristId,
      partialOverlapStart,
      partialOverlapEnd
    );
    console.log('Partial overlap result:', result5);

  } catch (error) {
    console.error('Test error:', error);
  } finally {
    await mongoose.disconnect();
    console.log('\nDisconnected from MongoDB');
  }
}

// Helper function to create test data
async function createTestData() {
  try {
    // Create a test tourist if not exists
    const testTourist = {
      _id: new mongoose.Types.ObjectId(),
      fullname: 'Test Tourist',
      email: 'test@tourist.com',
      // ... other required fields
    };

    // Create test activities if not exists
    const testActivity1 = {
      _id: new mongoose.Types.ObjectId(),
      titre: 'Test Activity 1',
      date_debut: new Date('2026-05-10T08:00:00Z'),
      date_fin: new Date('2026-05-10T13:00:00Z'),
      organisateur_id: new mongoose.Types.ObjectId(),
      // ... other required fields
    };

    console.log('Test data created successfully');
    return { testTourist, testActivity1 };
  } catch (error) {
    console.error('Error creating test data:', error);
  }
}

// Run the test
if (require.main === module) {
  console.log('Starting booking overlap validation test...\n');
  console.log('⚠️  Make sure to replace TOURIST_ID_HERE with an actual tourist ID');
  console.log('⚠️  Make sure the tourist has some existing bookings to test against\n');
  
  testOverlapValidation();
}

module.exports = { testOverlapValidation, createTestData };
