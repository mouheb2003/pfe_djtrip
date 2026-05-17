const { GoogleGenerativeAI } = require('@google/generative-ai');
require('dotenv').config(); // Should work if run from Cwd: Back

async function checkEmbeddings() {
  const multiKeys = process.env.GEMINI_API_KEYS;
  if (!multiKeys) {
    console.error('No GEMINI_API_KEYS found in env:', Object.keys(process.env).filter(k => k.includes('GEMINI')));
    return;
  }
  const keys = multiKeys.split(',');
  const genAI = new GoogleGenerativeAI(keys[0].trim());
  
  console.log('Checking models...');
  const modelsToTry = ['gemini-embedding-001', 'text-embedding-004', 'gemini-embedding-2'];
  
  for (const mName of modelsToTry) {
    try {
      const model = genAI.getGenerativeModel({ model: mName });
      await model.embedContent('test');
      console.log(`✅ ${mName} is working`);
    } catch (e) {
      console.log(`❌ ${mName} failed: ${e.message}`);
    }
  }
}

checkEmbeddings();
