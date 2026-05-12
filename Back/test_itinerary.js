const mongoose = require('mongoose');
const Activite = require('./models/activite');

mongoose.connect('mongodb://localhost:27017/djtrip')
  .then(async () => {
    console.log('Connected to MongoDB');
    
    // Check if any activities have itinerary data
    const activities = await Activite.find({
      $or: [
        { location_type: 'itinerary' },
        { itineraire: { $exists: true, $ne: '' } },
        { itineraire_coords: { $exists: true, $ne: [] } }
      ]
    }).limit(3);
    
    console.log('Found activities with itinerary data:', activities.length);
    
    activities.forEach((activity, index) => {
      console.log(`\n--- Activity ${index + 1} ---`);
      console.log('ID:', activity._id);
      console.log('Title:', activity.titre);
      console.log('Location Type:', activity.location_type);
      console.log('Itinerary:', activity.itineraire);
      console.log('Itinerary Coords:', activity.itineraire_coords);
    });
    
    // Test creating a sample activity with itinerary
    console.log('\n=== Testing Itinerary Creation ===');
    const testActivity = new Activite({
      titre: 'Test Itinerary Activity',
      description: 'Test activity with itinerary',
      type_activite: 'Tour',
      categorie: 'Test',
      organisateur_id: '507f1f77bcf86cd799439011', // dummy ID
      lieu: 'Multi-location tour: Test Location A to Test Location B',
      duree: 4,
      prix: 50,
      capacite_max: 10,
      location_type: 'itinerary',
      itineraire: 'Step 1: Start at Test Location A - Test Location A\nStep 2: Visit Test Location B - Test Location B',
      itineraire_coords: [
        { lat: 35.8256, lng: 10.6084, address: 'Test Location A' },
        { lat: 35.8356, lng: 10.6184, address: 'Test Location B' }
      ],
      date_debut: new Date(),
      date_fin: new Date(Date.now() + 4 * 60 * 60 * 1000)
    });
    
    console.log('Test activity data:', {
      location_type: testActivity.location_type,
      itineraire: testActivity.itineraire,
      itineraire_coords: testActivity.itineraire_coords
    });
    
    mongoose.connection.close();
  })
  .catch(err => {
    console.error('MongoDB connection error:', err);
    process.exit(1);
  });
