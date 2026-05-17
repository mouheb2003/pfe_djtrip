const { GoogleGenerativeAI } = require('@google/generative-ai');
require('dotenv').config();

async function check() {
  const keys = process.env.GEMINI_API_KEYS ? process.env.GEMINI_API_KEYS.split(',') : [process.env.GEMINI_API_KEY];
  const key = keys[0].trim();
  console.log('Checking with key:', key.slice(0, 6) + '...');
  
  try {
    // We can't easily call listModels with the current SDK version in a simple way 
    // without a full client, but we can try a very basic model.
    const models = ['gemini-2.5-flash', 'gemini-2.0-flash', 'gemini-flash-latest', 'gemini-pro-latest'];
    const versions = ['v1beta'];
    
    for (const v of versions) {
      console.log(`\n--- Testing API Version: ${v} ---`);
      for (const m of models) {
        try {
          const genAI = new GoogleGenerativeAI(key);
          const model = genAI.getGenerativeModel({ model: m }, { apiVersion: v });
          const result = await model.generateContent('hi');
          console.log(`✅ Model ${m} (${v}) WORKS! Response: ${result.response.text()}`);
        } catch (e) {
          console.log(`❌ Model ${m} (${v}) failed: ${e.message}`);
        }
      }
    }
  } catch (err) {
    console.error('Error:', err.message);
  }
}

check();
