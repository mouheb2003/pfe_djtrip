const axios = require('axios');

const GOOGLE_MAPS_API_KEY = process.env.GOOGLE_MAPS_API_KEY || '';

function ensureKey(res) {
  if (!GOOGLE_MAPS_API_KEY) {
    res.status(500).json({ message: 'Server not configured with GOOGLE_MAPS_API_KEY' });
    return false;
  }
  return true;
}

exports.nearbySearch = async (req, res) => {
  if (!ensureKey(res)) return;

  const { lat, lng, radius = 1500, type } = req.query;
  if (!lat || !lng) return res.status(400).json({ message: 'lat and lng are required' });

  try {
    const url = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json';
    const params = {
      location: `${lat},${lng}`,
      radius,
      key: GOOGLE_MAPS_API_KEY,
    };
    if (type) params.type = type;

    const response = await axios.get(url, { params });
    return res.json(response.data);
  } catch (err) {
    console.error('Google Places nearbySearch error:', err?.message || err);
    return res.status(500).json({ message: 'Error fetching nearby places', error: err?.message });
  }
};

exports.placeDetails = async (req, res) => {
  if (!ensureKey(res)) return;

  const {
    place_id,
    fields = 'name,geometry,formatted_address,address_components,photos,website,formatted_phone_number,rating,opening_hours,price_level,types',
  } = req.query;
  if (!place_id) return res.status(400).json({ message: 'place_id is required' });

  try {
    const url = 'https://maps.googleapis.com/maps/api/place/details/json';
    const params = { place_id, fields, key: GOOGLE_MAPS_API_KEY };
    const response = await axios.get(url, { params });
    return res.json(response.data);
  } catch (err) {
    console.error('Google Places details error:', err?.message || err);
    return res.status(500).json({ message: 'Error fetching place details', error: err?.message });
  }
};

exports.autocomplete = async (req, res) => {
  if (!ensureKey(res)) return;

  const { input, location, radius } = req.query;
  if (!input) return res.status(400).json({ message: 'input is required' });

  try {
    const url = 'https://maps.googleapis.com/maps/api/place/autocomplete/json';
    const params = { input, key: GOOGLE_MAPS_API_KEY };
    if (location) params.location = location;
    if (radius) params.radius = radius;

    const response = await axios.get(url, { params });
    return res.json(response.data);
  } catch (err) {
    console.error('Google Places autocomplete error:', err?.message || err);
    return res.status(500).json({ message: 'Error fetching autocomplete', error: err?.message });
  }
};
