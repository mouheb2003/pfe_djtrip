require('dotenv').config();
const { generateTokens } = require('./middleware/auth');

try {
  // Generate a fake but cryptographically valid Admin token
  const tokens = generateTokens('111122223333444455556666', 'admin@djtrip.local', 'Admin', 0);
  const token = tokens.accessToken;

  fetch('http://localhost:3000/api/v1/debug/email/test', {
      method: 'POST',
      headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
      },
      body: JSON.stringify({
          "to": "aminmj527@gmail.com",
          "subject": "Test DJTrip",
          "message": "Hello from API route test!"
      })
  })
  .then(async res => {
      console.log("Status Code:", res.status);
      console.log("Response Body:", await res.text());
      process.exit(0);
  })
  .catch(err => {
      console.error(err);
      process.exit(1);
  });
} catch (error) {
  console.error("Error generating token:", error);
}
