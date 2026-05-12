const mongoose = require('mongoose');
const Activite = require('./models/activite');

mongoose.connect('mongodb://localhost:27017/djtrip')
  .then(async () => {
    console.log('Connected to MongoDB');
    
    // Simulate the exact data structure from frontend
    const frontendData = {
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
      itineraire_coords: JSON.stringify([
        { lat: 35.8256, lng: 10.6084, address: 'Test Location A' },
        { lat: 35.8356, lng: 10.6184, address: 'Test Location B' }
      ]),
      date_debut: new Date(),
      date_fin: new Date(Date.now() + 4 * 60 * 60 * 1000)
    };
    
    console.log('Frontend data simulation:', frontendData);
    
    // Test creating activity with exact same parsing as backend
    const activite = new Activite({
      titre: frontendData.titre,
      description: frontendData.description,
      type_activite: frontendData.type_activite,
      categorie: frontendData.categorie,
      organisateur_id: frontendData.organisateur_id,
      lieu: frontendData.lieu,
      duree: frontendData.duree,
      prix: frontendData.prix,
      capacite_max: frontendData.capacite_max,
      location_type: frontendData.location_type,
      itineraire: frontendData.itineraire,
      itineraire_coords: JSON.parse(frontendData.itineraire_coords), // This is what backend does
      date_debut: frontendData.date_debut,
      date_fin: frontendData.date_fin
    });
    
    console.log('Activity before save:', {
      location_type: activite.location_type,
      itineraire: activite.itineraire,
      itineraire_coords: activite.itineraire_coords
    });
    
    try {
      const saved = await activite.save();
      console.log('✅ Saved successfully:', {
        id: saved._id,
        location_type: saved.location_type,
        itineraire: saved.itineraire,
        itineraire_coords: saved.itineraire_coords
      });
      
      // Verify it was actually saved
      const found = await Activite.findById(saved._id);
      console.log('🔍 Retrieved from DB:', {
        location_type: found.location_type,
        itineraire: found.itineraire,
        itineraire_coords: found.itineraire_coords
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
