const http = require('http');

// Test de l'API de recherche de mentions avec l'URL correcte
const testUrl = 'http://192.168.1.201:3000/api/v1/mentions/search?query=@amine&limit=10';

console.log('Testing mention search API...');
console.log('URL:', testUrl);

const options = {
  method: 'GET',
  headers: {
    'Content-Type': 'application/json',
    // Note: En production, il faudrait un token d'authentification valide
  }
};

const req = http.request(testUrl, options, (res) => {
  console.log(`Status: ${res.statusCode}`);
  console.log(`Headers: ${JSON.stringify(res.headers)}`);
  
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
