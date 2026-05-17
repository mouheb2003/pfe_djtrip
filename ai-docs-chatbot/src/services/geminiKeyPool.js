import { GoogleGenerativeAI } from '@google/generative-ai';

/**
 * Gemini API Key Pool - Auto-rotation with quota exhaustion detection (ESM version)
 */
class GeminiKeyPool {
  constructor() {
    this._keys = [];
    this._currentIndex = 0;
    this._exhaustedKeys = new Map();
    this._cooldownMs = 60 * 1000;
    this._initialized = false;
  }

  initialize() {
    if (this._initialized) return;
    
    const multiKeys = process.env.GEMINI_API_KEYS;
    if (multiKeys) {
      this._keys = multiKeys
        .split(',')
        .map(k => k.trim())
        .filter(k => k.length > 0);
    }

    // Fallback to single key if pool is empty
    if (this._keys.length === 0) {
      const singleKey = process.env.GEMINI_API_KEY;
      if (singleKey && singleKey.trim().length > 0) {
        this._keys = [singleKey.trim()];
      }
    }

    this._initialized = true;
    console.log(`[GeminiKeyPool] Initialized with ${this._keys.length} API key(s)`);
  }

  _getNextAvailableKey() {
    if (!this._initialized) this.initialize();
    
    const now = Date.now();

    // Revive cooldown keys
    for (const [key, retryAfter] of this._exhaustedKeys.entries()) {
      if (now >= retryAfter) {
        this._exhaustedKeys.delete(key);
        console.log(`[GeminiKeyPool] Key ...${key.slice(-6)} cooldown expired`);
      }
    }

    // Try each key
    for (let i = 0; i < this._keys.length; i++) {
      const idx = (this._currentIndex + i) % this._keys.length;
      const key = this._keys[idx];

      if (!this._exhaustedKeys.has(key)) {
        this._currentIndex = (idx + 1) % this._keys.length;
        return key;
      }
    }

    return null;
  }

  _markExhausted(key) {
    const retryAfter = Date.now() + this._cooldownMs;
    this._exhaustedKeys.set(key, retryAfter);
    const available = this._keys.length - this._exhaustedKeys.size;
    console.log(`[GeminiKeyPool] Key ...${key.slice(-6)} exhausted. ${available}/${this._keys.length} available`);
  }

  _isQuotaError(error) {
    if (error.status === 429) return true;
    const msg = (error.message || '').toLowerCase();
    return (
      msg.includes('429') ||
      msg.includes('quota exceeded') ||
      msg.includes('rate_limit') ||
      msg.includes('too many requests') ||
      msg.includes('resource exhausted')
    );
  }

  async generateContent(unused_modelName, prompt, options = {}) {
    if (!this._initialized) this.initialize();
    const maxAttempts = Math.max(1, this._keys.length);
    let lastError = null;
    
    const modelName = 'gemini-2.5-flash';
    const triedKeys = new Set();
    for (let attempt = 0; attempt < maxAttempts; attempt++) {
      let apiKey = null;
      for (let i = 0; i < this._keys.length; i++) {
        const idx = (this._currentIndex + i) % this._keys.length;
        const key = this._keys[idx];
        if (!this._exhaustedKeys.has(key) && !triedKeys.has(key)) {
          apiKey = key;
          this._currentIndex = (idx + 1) % this._keys.length;
          break;
        }
      }

      if (!apiKey) {
        throw new Error(`[GeminiKeyPool] No available keys for ${modelName}`);
      }
      triedKeys.add(apiKey);

      try {
        const genAI = new GoogleGenerativeAI(apiKey);
        const model = genAI.getGenerativeModel(
          { model: modelName, ...options },
          { apiVersion: 'v1beta' }
        );

        const result = await model.generateContent(prompt);
        const response = await result.response;
        
        return {
          text: response.text().trim(),
          model: modelName,
          keyUsed: `...${apiKey.slice(-6)}`
        };
      } catch (error) {
        lastError = error;
        if (this._isQuotaError(error) && !error.message.includes('limit: 0')) {
          this._markExhausted(apiKey);
          continue;
        }
        if (error.status === 404 || error.message.includes('limit: 0')) {
          console.warn(`[GeminiKeyPool] Key ...${apiKey.slice(-6)} incompatible with ${modelName}`);
          continue;
        }
        throw error;
      }
    }
    throw lastError;
  }

  /**
   * For streaming responses with rotation support
   */
  async generateContentStream(modelName, prompt, options = {}) {
    if (!this._initialized) this.initialize();
    const maxAttempts = Math.max(1, this._keys.length);
    let lastError = null;

    for (let attempt = 0; attempt < maxAttempts; attempt++) {
      const apiKey = this._getNextAvailableKey();
      if (!apiKey) {
        throw new Error(`[GeminiKeyPool] All keys exhausted for streaming. Cooldown in progress.`);
      }

      try {
        const genAI = new GoogleGenerativeAI(apiKey);
        const model = genAI.getGenerativeModel({ model: modelName, ...options });
        return await model.generateContentStream(prompt);
      } catch (error) {
        lastError = error;
        if (this._isQuotaError(error)) {
          this._markExhausted(apiKey);
          console.warn(`[GeminiKeyPool] Streaming quota hit on key ...${apiKey.slice(-6)}, rotating...`);
          continue;
        }
        throw error;
      }
    }
    throw lastError;
  }

  /**
   * For embeddings with rotation support
   */
  async embedContent(modelName, text) {
    if (!this._initialized) this.initialize();
    const maxAttempts = Math.max(1, this._keys.length);
    let lastError = null;

    for (let attempt = 0; attempt < maxAttempts; attempt++) {
      const apiKey = this._getNextAvailableKey();
      if (!apiKey) {
        throw new Error(`[GeminiKeyPool] All keys exhausted for embeddings. Cooldown in progress.`);
      }

      try {
        const genAI = new GoogleGenerativeAI(apiKey);
        const model = genAI.getGenerativeModel({ model: modelName }, { apiVersion: 'v1' });
        const result = await model.embedContent(text);
        return result;
      } catch (error) {
        lastError = error;
        if (this._isQuotaError(error) || error.status === 404) {
          if (error.message.includes('limit: 0')) {
            console.warn(`[GeminiKeyPool] Key ...${apiKey.slice(-6)} has limit 0 for embedding ${modelName}. Rotating...`);
          } else if (error.status === 404) {
            console.warn(`[GeminiKeyPool] Key ...${apiKey.slice(-6)} returned 404 for embedding ${modelName}. Rotating...`);
          } else {
            console.warn(`[GeminiKeyPool] Embedding quota hit on key ...${apiKey.slice(-6)}, rotating...`);
          }
          this._markExhausted(apiKey);
          continue;
        }
        throw error;
      }
    }
    throw lastError;
  }

  /**
   * Get a GoogleGenerativeAI instance with the next available key
   */
  getClient() {
    if (!this._initialized) this.initialize();
    const apiKey = this._getNextAvailableKey();
    if (!apiKey) throw new Error('[GeminiKeyPool] No keys available');
    return new GoogleGenerativeAI(apiKey);
  }
}

const geminiKeyPool = new GeminiKeyPool();
export default geminiKeyPool;
