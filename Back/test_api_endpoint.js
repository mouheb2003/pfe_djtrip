const express = require('express');
const multer = require('multer');
const app = express();
const upload = multer();

// Simulate the exact frontend request
const simulateFrontendRequest = {
  body: {
    titre: 'Test Itinerary Activity',
    description: 'Test activity with itinerary',
    type_activite: 'Guided Tour',
    categorie: 'Test',
    lieu: 'Multi-location tour: Test Location A to Test Location B',
    duree: '4',
    prix: '50',
    capacite_max: '10',
    location_type: 'itinerary',
    itineraire: 'Step 1: Start at Test Location A - Test Location A\nStep 2: Visit Test Location B - Test Location B',
    itineraire_coords: JSON.stringify([
      { lat: 35.8256, lng: 10.6084, address: 'Test Location A' },
      { lat: 35.8356, lng: 10.6184, address: 'Test Location B' }
    ]),
    date_debut: new Date().toISOString(),
    date_fin: new Date(Date.now() + 4 * 60 * 60 * 1000).toISOString(),
    statut: 'active'
  },
  user: {
    userId: '507f1f77bcf86cd799439011' // dummy organizer ID
  },
  files: [] // no files for this test
};

console.log('=== SIMULATING FRONTEND REQUEST ===');
console.log('Request body:', simulateFrontendRequest.body);

// Test the exact parsing logic from the controller
const {
  titre,
  description,
  type_activite,
  categorie,
  lieu,
  duree,
  prix,
  capacite_max,
  location_type,
  itineraire,
  itineraire_coords,
  date_debut,
  date_fin,
  statut
} = simulateFrontendRequest.body;

// Parse JSON fields like the controller does
let parsedItineraireCoords = itineraire_coords;
if (parsedItineraireCoords !== undefined && typeof parsedItineraireCoords === "string") {
  try {
    parsedItineraireCoords = JSON.parse(parsedItineraireCoords);
  } catch (e) {
    console.warn("⚠️ Failed to parse itineraire_coords:", e);
    parsedItineraireCoords = [];
  }
}

console.log('\n=== PARSED DATA ===');
console.log('titre:', titre);
console.log('type_activite:', type_activite);
console.log('location_type:', location_type);
console.log('itineraire:', itineraire);
console.log('itineraire_coords:', parsedItineraireCoords);

// Test creating the activity object like the controller does
const mongoose = require('mongoose');
const Activite = require('./models/activite');

mongoose.connect('mongodb://localhost:27017/djtrip')
  .then(async () => {
    console.log('\n=== TESTING ACTIVITY CREATION ===');
    
    const activite = new Activite({
      titre,
      description,
      type_activite,
      categorie,
      organisateur_id: simulateFrontendRequest.user.userId,
      lieu,
      duree: parseFloat(duree),
      prix: parseFloat(prix),
      capacite_max: parseInt(capacite_max),
      location_type: location_type || "fixed",
      itineraire,
      itineraire_coords: parsedItineraireCoords,
      date_debut: new Date(date_debut),
      date_fin: new Date(date_fin),
      statut: statut || "active",
    });
    
    console.log('Activity object created:', {
      location_type: activite.location_type,
      itineraire: activite.itineraire,
      itineraire_coords: activite.itineraire_coords
    });
    
    try {
      const saved = await activite.save();
      console.log('✅ SUCCESS: Activity saved to database');
      console.log('Saved ID:', saved._id);
      console.log('Location type:', saved.location_type);
      console.log('Itinerary saved:', !!saved.itineraire);
      console.log('Itinerary coords saved:', saved.itineraire_coords.length);
      
      // Verify retrieval
      const retrieved = await Activite.findById(saved._id);
      console.log('✅ VERIFIED: Retrieved from database');
      console.log('Retrieved location type:', retrieved.location_type);
      console.log('Retrieved itinerary:', retrieved.itineraire);
      console.log('Retrieved coords count:', retrieved.itineraire_coords.length);
      
    } catch (error) {
      console.error('❌ FAILED: Activity save error:', error.message);
      if (error.errors) {
        Object.keys(error.errors).forEach(key => {
          console.error(`  ${key}: ${error.errors[key].message}`);
        });
      }
    }
    
    mongoose.connection.close();
  })
  .catch(err => {
    console.error('❌ MongoDB connection error:', err);
    process.exit(1);
  });
