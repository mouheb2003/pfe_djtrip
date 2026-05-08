const express = require('express');
const router = express.Router();
const googlePlacesController = require('../controllers/googlePlaces');

// Public endpoints
router.get('/nearby', googlePlacesController.nearbySearch);
router.get('/details', googlePlacesController.placeDetails);
router.get('/autocomplete', googlePlacesController.autocomplete);

module.exports = router;
