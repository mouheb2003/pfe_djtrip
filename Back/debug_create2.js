const mongoose = require('mongoose');
const Activite = require('./models/activite');

mongoose.connect('mongodb://localhost:27017/djtrip')
  .then(async () => {
    console.log('Connected to MongoDB');
    
    // Test with valid enum value
    const validData = {
      titre: 'Test Itinerary Activity',
      description: 'Test activity with itinerary',
      type_activite: 'Guided Tour', // Valid enum value
      categorie: 'Test',
      organisateur_id: '507f1f77bcf86cd799439011',
      lieu: 'Multi-location tour: Test Location A to Test Location B',
      duree: 4,
      prix: 50,
      capacite_max: 10,
      location_type: 'itinerary',
      itineraire: 'Step 1: Start at Test Location A - Test Location A\nStep 2: Visit Test Location B - Test Location B',
      itineraire_coords: JSON.stringify([
        { lat: 35.8256, lng: 10.6084, address: 'Test Location A' },
        { lat: 35.8356, lng: 10.6184, address: 'Test Location B' }
      ]),
      date_debut: new Date(),
      date_fin: new Date(Date.now() + 4 * 60 * 60 * 1000)
    };
    
    console.log('Testing with valid enum value...');
    
    const activite = new Activite({
      titre: validData.titre,
      description: validData.description,
      type_activite: validData.type_activite,
      categorie: validData.categorie,
      organisateur_id: validData.organisateur_id,
      lieu: validData.lieu,
      duree: validData.duree,
      prix: validData.prix,
      capacite_max: validData.capacite_max,
      location_type: validData.location_type,
      itineraire: validData.itineraire,
      itineraire_coords: JSON.parse(validData.itineraire_coords),
      date_debut: validData.date_debut,
      date_fin: validData.date_fin
    });
    
    try {
      const saved = await activite.save();
      console.log('✅ Saved successfully:', {
        id: saved._id,
        location_type: saved.location_type,
        itineraire: saved.itineraire,
        itineraire_coords: saved.itineraire_coords
      });
      
      // Check all activities with itinerary data now
      const activities = await Activite.find({
        $or: [
          { location_type: 'itinerary' },
          { itineraire: { $exists: true, $ne: '' } },
          { itineraire_coords: { $exists: true, $ne: [] } }
        ]
      });
      
      console.log(`📊 Found ${activities.length} activities with itinerary data:`);
      activities.forEach((activity, index) => {
        console.log(`\n--- Activity ${index + 1} ---`);
        console.log('ID:', activity._id);
        console.log('Title:', activity.titre);
        console.log('Location Type:', activity.location_type);
        console.log('Itinerary:', activity.itineraire);
        console.log('Itinerary Coords:', activity.itineraire_coords);
      });
      
    } catch (error) {
      console.error('❌ Save failed:', error);
    }
    
    mongoose.connection.close();
  })
  .catch(err => {
    console.error('MongoDB connection error:', err);
    process.exit(1);
  });
