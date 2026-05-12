const mongoose = require('mongoose');
const User = require('./models/user');
const mentionController = require('./controllers/mentionController');

// Simuler une requête
const mockReq = {
  query: {
    query: '@a',
    limit: '10'
  }
};

const mockRes = {
  status: function(code) {
    console.log(`Status: ${code}`);
    return this;
  },
  json: function(data) {
    console.log('Response:', JSON.stringify(data, null, 2));
    return this;
  }
};

mongoose.connect('mongodb://localhost:27017/djtrip')
.then(async () => {
  console.log('Connected to MongoDB');
  console.log('Testing mention search API with query "@a"...\n');
  
  // Tester la fonction de recherche de mentions
  await mentionController.searchMentions(mockReq, mockRes);
  
  process.exit(0);
})
.catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
