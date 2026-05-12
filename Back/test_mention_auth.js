const http = require('http');

// Test de l'API de recherche de mentions avec authentification
const testUrl = 'http://192.168.1.201:3000/api/v1/mentions/search?query=@amine&limit=10';

console.log('Testing mention search API with auth...');
console.log('URL:', testUrl);

// Simuler un token JWT (en production, il faudrait un token valide)
const mockToken = 'Bearer mock_token_for_testing';

const options = {
  method: 'GET',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': mockToken,
  }
};

const req = http.request(testUrl, options, (res) => {
  console.log(`Status: ${res.statusCode}`);
  
  let data = '';
  res.on('data', (chunk) => {
    data += chunk;
  });
  
  res.on('end', () => {
    console.log('Response body:', data);
    
    try {
      const parsed = JSON.parse(data);
      console.log('Parsed response:', JSON.stringify(parsed, null, 2));
    } catch (e) {
      console.log('Response is not valid JSON');
    }
    
    process.exit(0);
  });
});

req.on('error', (error) => {
  console.error('Error:', error.message);
  process.exit(1);
});

req.end();
