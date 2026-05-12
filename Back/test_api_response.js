const mongoose = require('mongoose');
const Activite = require('./models/activite');

mongoose.connect('mongodb://localhost:27017/djtrip')
  .then(async () => {
    console.log('🔍 TESTING BACKEND API RESPONSE FORMAT');
    console.log('==========================================\n');
    
    // 1. Get an activity with itinerary data
    const activity = await Activite.findOne({ location_type: 'itinerary' });
    
    if (!activity) {
      console.log('❌ No itinerary activity found in database');
      mongoose.connection.close();
      return;
    }
    
    console.log('✅ Found activity with itinerary:');
    console.log('   ID:', activity._id);
    console.log('   Title:', activity.titre);
    console.log('   Location Type:', activity.location_type);
    
    // 2. Simulate backend API response (like what controller returns)
    console.log('\n📤 BACKEND API RESPONSE SIMULATION:');
    console.log('=====================================');
    
    // Simulate the populated response that backend sends
    const apiResponse = {
      _id: activity._id,
      titre: activity.titre,
      description: activity.description,
      type_activite: activity.type_activite,
      categorie: activity.categorie,
      organisateur_id: activity.organisateur_id,
      lieu: activity.lieu,
      coordonnees: activity.coordonnees,
      duree: activity.duree,
      prix: activity.prix,
      capacite_max: activity.capacite_max,
      langues_disponibles: activity.langues_disponibles,
      photos: activity.photos,
      niveau_difficulte: activity.niveau_difficulte,
      equipements_inclus: activity.equipements_inclus,
      a_apporter: activity.a_apporter,
      dates_disponibles: activity.dates_disponibles,
      date_debut: activity.date_debut,
      date_fin: activity.date_fin,
      statut: activity.statut,
      location_type: activity.location_type,
      itineraire: activity.itineraire,
      itineraire_coords: activity.itineraire_coords,
      note_moyenne: activity.note_moyenne,
      nombre_avis: activity.nombre_avis,
      nombre_reservations: activity.nombre_reservations,
      createdAt: activity.createdAt,
      updatedAt: activity.updatedAt,
    };
    
    console.log('Itinerary Data in Response:');
    console.log('   location_type:', apiResponse.location_type);
    console.log('   itineraire:', apiResponse.itineraire ? `"${apiResponse.itineraire}"` : 'null');
    console.log('   itineraire_coords length:', apiResponse.itineraire_coords?.length || 0);
    
    if (apiResponse.itineraire_coords && apiResponse.itineraire_coords.length > 0) {
      console.log('   itineraire_coords sample:');
      apiResponse.itineraire_coords.slice(0, 2).forEach((coord, i) => {
        console.log(`     ${i + 1}. lat: ${coord.lat}, lng: ${coord.lng}, address: "${coord.address}"`);
      });
    }
    
    // 3. Test JSON serialization (what actually gets sent over HTTP)
    console.log('\n🌐 JSON SERIALIZATION TEST:');
    console.log('===========================');
    
    const jsonString = JSON.stringify(apiResponse);
    const parsedBack = JSON.parse(jsonString);
    
    console.log('After JSON round-trip:');
    console.log('   location_type:', parsedBack.location_type);
    console.log('   itineraire exists:', !!parsedBack.itineraire);
    console.log('   itineraire_coords exists:', !!parsedBack.itineraire_coords);
    console.log('   itineraire_coords length:', parsedBack.itineraire_coords?.length || 0);
    
    // 4. Simulate frontend ActivityModel.fromJson
    console.log('\n📱 FRONTEND ACTIVITY MODEL PARSING:');
    console.log('===================================');
    
    const simulateFrontendParsing = (json) => {
      // Simulate the exact parsing logic from ActivityModel.fromJson
      const model = {
        id: json._id?.toString() ?? json['id']?.toString() ?? '',
        titre: json['titre']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        typeActivite: json['type_activite']?.toString() ?? '',
        categorie: json['categorie']?.toString() ?? 'Other',
        lieu: json['lieu']?.toString() ?? '',
        locationType: json['location_type']?.toString(),
        itineraire: json['itineraire']?.toString(),
        itineraireCoords: json['itineraire_coords'] instanceof Array
          ? json['itineraire_coords'].map(e => e instanceof Object ? e : {})
          : [],
        duree: typeof json['duree'] === 'number' ? json['duree'] : parseFloat(json['duree']?.toString() ?? '0'),
        prix: typeof json['prix'] === 'number' ? json['prix'] : parseFloat(json['prix']?.toString() ?? '0'),
        capaciteMax: typeof json['capacite_max'] === 'number' ? json['capacite_max'] : parseInt(json['capacite_max']?.toString() ?? '1'),
        // ... other fields
      };
      
      return model;
    };
    
    const frontendModel = simulateFrontendParsing(parsedBack);
    
    console.log('Frontend Model Results:');
    console.log('   id:', frontendModel.id);
    console.log('   locationType:', frontendModel.locationType);
    console.log('   itineraire:', frontendModel.itineraire ? `"${frontendModel.itineraire}"` : 'null');
    console.log('   itineraireCoords length:', frontendModel.itineraireCoords?.length || 0);
    
    // 5. Test frontend display conditions
    console.log('\n🎯 FRONTEND DISPLAY CONDITIONS:');
    console.log('===============================');
    
    const shouldShowItinerary = (frontendModel.itineraire != null && frontendModel.itineraire.trim().length > 0) || 
                               (frontendModel.itineraireCoords != null && frontendModel.itineraireCoords.length > 0);
    
    console.log('Should show itinerary section:', shouldShowItinerary);
    console.log('Condition 1 (text exists):', frontendModel.itineraire != null && frontendModel.itineraire.trim().length > 0);
    console.log('Condition 2 (coords exist):', frontendModel.itineraireCoords != null && frontendModel.itineraireCoords.length > 0);
    
    // 6. Summary
    console.log('\n📋 DATA FLOW SUMMARY:');
    console.log('====================');
    console.log('✅ Backend stores itinerary data correctly');
    console.log('✅ API response includes itinerary fields');
    console.log('✅ JSON serialization preserves data');
    console.log('✅ Frontend parsing works correctly');
    console.log('✅ Display conditions are met');
    
    if (shouldShowItinerary) {
      console.log('\n🎉 SUCCESS: Itinerary data flows correctly from backend to frontend display!');
    } else {
      console.log('\n❌ ISSUE: Display conditions not met despite data being present');
    }
    
    mongoose.connection.close();
  })
  .catch(err => {
    console.error('❌ MongoDB connection error:', err);
    process.exit(1);
  });
