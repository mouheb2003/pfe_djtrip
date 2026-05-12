const mongoose = require('mongoose');
const Activite = require('./models/activite');

mongoose.connect('mongodb://localhost:27017/djtrip')
  .then(async () => {
    console.log('Connected to MongoDB');
    
    // Get the activity we just created with itinerary
    const activities = await Activite.find({
      location_type: 'itinerary'
    }).limit(3);
    
    console.log(`Found ${activities.length} activities with itinerary type:`);
    
    activities.forEach((activity, index) => {
      console.log(`\n=== Activity ${index + 1} ===`);
      console.log('ID:', activity._id);
      console.log('Title:', activity.titre);
      console.log('Location Type:', activity.location_type);
      console.log('Lieu:', activity.lieu);
      console.log('Itinerary exists:', !!activity.itineraire);
      console.log('Itinerary length:', activity.itineraire?.length || 0);
      console.log('Itinerary coords count:', activity.itineraire_coords?.length || 0);
      
      if (activity.itineraire) {
        console.log('Itinerary text:', activity.itineraire);
      }
      
      if (activity.itineraire_coords && activity.itineraire_coords.length > 0) {
        console.log('Itinerary coordinates:');
        activity.itineraire_coords.forEach((coord, i) => {
          console.log(`  ${i + 1}. Lat: ${coord.lat}, Lng: ${coord.lng}, Address: ${coord.address}`);
        });
      }
      
      // Test the frontend model parsing
      console.log('\n--- Frontend Model Simulation ---');
      const frontendModel = {
        id: activity._id.toString(),
        titre: activity.titre,
        description: activity.description,
        typeActivite: activity.type_activite,
        categorie: activity.categorie,
        lieu: activity.lieu,
        locationType: activity.location_type,
        itineraire: activity.itineraire,
        itineraireCoords: activity.itineraire_coords,
        // ... other fields
      };
      
      console.log('Frontend would receive:');
      console.log('  locationType:', frontendModel.locationType);
      console.log('  itineraire:', frontendModel.itineraire ? `"${frontendModel.itineraire}"` : 'null');
      console.log('  itineraireCoords length:', frontendModel.itineraireCoords?.length || 0);
      
      // Test the activity detail screen condition
      const shouldShowItinerary = (frontendModel.itineraire != null && frontendModel.itineraire.trim().isNotEmpty) || 
                                  (frontendModel.itineraireCoords != null && frontendModel.itineraireCoords.isNotEmpty);
      
      console.log('  Should show itinerary section:', shouldShowItinerary);
    });
    
    mongoose.connection.close();
  })
  .catch(err => {
    console.error('MongoDB connection error:', err);
    process.exit(1);
  });
