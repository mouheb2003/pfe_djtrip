const mongoose = require('mongoose');
const Activite = require('./models/activite');

mongoose.connect('mongodb://localhost:27017/djtrip')
  .then(async () => {
    console.log('Connected to MongoDB');
    
    // Get activities with itinerary
    const activities = await Activite.find({
      location_type: 'itinerary'
    }).limit(1);
    
    if (activities.length === 0) {
      console.log('No activities with itinerary found');
      mongoose.connection.close();
      return;
    }
    
    const activity = activities[0];
    console.log('=== TESTING FRONTEND DISPLAY CONDITION ===');
    console.log('Activity ID:', activity._id);
    console.log('Title:', activity.titre);
    
    // Simulate the exact frontend condition from activity_detail_screen.dart
    const itineraire = activity.itineraire;
    const itineraireCoords = activity.itineraire_coords;
    
    console.log('\n--- Data Values ---');
    console.log('itineraire:', itineraire);
    console.log('itineraire type:', typeof itineraire);
    console.log('itineraireCoords:', itineraireCoords);
    console.log('itineraireCoords type:', typeof itineraireCoords);
    
    // Test the exact condition from the frontend
    // if ((activity.itineraire != null && activity.itineraire!.trim().isNotEmpty) || 
    //     (activity.itineraireCoords != null && activity.itineraireCoords!.isNotEmpty))
    
    const condition1 = itineraire != null && itineraire.trim().length > 0;
    const condition2 = itineraireCoords != null && itineraireCoords.length > 0;
    const shouldShowItinerary = condition1 || condition2;
    
    console.log('\n--- Condition Breakdown ---');
    console.log('Condition 1 (itineraire exists and not empty):', condition1);
    console.log('  itineraire != null:', itineraire != null);
    console.log('  itineraire.trim().length > 0:', itineraire ? itineraire.trim().length > 0 : 'N/A');
    
    console.log('Condition 2 (itineraireCoords exists and not empty):', condition2);
    console.log('  itineraireCoords != null:', itineraireCoords != null);
    console.log('  itineraireCoords.length > 0:', itineraireCoords ? itineraireCoords.length > 0 : 'N/A');
    
    console.log('\n--- FINAL RESULT ---');
    console.log('Should show itinerary section:', shouldShowItinerary);
    
    if (shouldShowItinerary) {
      console.log('✅ FRONTEND SHOULD DISPLAY ITINERARY');
    } else {
      console.log('❌ FRONTEND WILL NOT DISPLAY ITINERARY');
    }
    
    // Test what the frontend model would look like
    console.log('\n--- Frontend ActivityModel Simulation ---');
    const frontendActivity = {
      id: activity._id.toString(),
      titre: activity.titre,
      description: activity.description,
      typeActivite: activity.type_activite,
      categorie: activity.categorie,
      lieu: activity.lieu,
      locationType: activity.location_type,
      itineraire: activity.itineraire,
      itineraireCoords: activity.itineraire_coords,
    };
    
    console.log('Frontend model properties:');
    console.log('  locationType:', frontendActivity.locationType);
    console.log('  itineraire:', frontendActivity.itineraire ? `"${frontendActivity.itineraire}"` : 'null');
    console.log('  itineraireCoords length:', frontendActivity.itineraireCoords?.length || 0);
    
    mongoose.connection.close();
  })
  .catch(err => {
    console.error('MongoDB connection error:', err);
    process.exit(1);
  });
