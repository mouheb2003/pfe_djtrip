const { GoogleGenerativeAI } = require('@google/generative-ai');

/**
 * Gemini API Key Pool - Auto-rotation with quota exhaustion detection
 * 
 * Usage:
 *   Set GEMINI_API_KEYS in .env as comma-separated keys:
 *   GEMINI_API_KEYS=key1,key2,key3,...
 *   
 *   Falls back to GEMINI_API_KEY (single key) if GEMINI_API_KEYS is not set.
 */

class GeminiKeyPool {
  constructor() {
    this._keys = this._loadKeys();
    this._currentIndex = 0;
    // Track exhausted keys with cooldown timestamps (key -> Date when it can be retried)
    this._exhaustedKeys = new Map();
    // Cooldown period: 60 seconds before retrying an exhausted key
    this._cooldownMs = 60 * 1000;

    console.log(`[GeminiKeyPool] Initialized with ${this._keys.length} API key(s)`);
  }

  /**
   * Load API keys from environment variables
   */
  _loadKeys() {
    const multiKeys = process.env.GEMINI_API_KEYS;
    if (multiKeys) {
      const keys = multiKeys
        .split(',')
        .map(k => k.trim())
        .filter(k => k.length > 0);
      if (keys.length > 0) return keys;
    }

    // Fallback to single key
    const singleKey = process.env.GEMINI_API_KEY;
    if (singleKey && singleKey.trim().length > 0) {
      return [singleKey.trim()];
    }

    console.error('[GeminiKeyPool] No API keys found! Set GEMINI_API_KEYS or GEMINI_API_KEY in .env');
    return [];
  }

  /**
   * Get the next available (non-exhausted) key
   * Returns null if all keys are exhausted
   */
  _getNextAvailableKey() {
    const now = Date.now();

    // First, revive any keys whose cooldown has expired
    for (const [key, retryAfter] of this._exhaustedKeys.entries()) {
      if (now >= retryAfter) {
        this._exhaustedKeys.delete(key);
        console.log(`[GeminiKeyPool] Key ...${key.slice(-6)} cooldown expired (${now - retryAfter}ms late), marking as available`);
      }
    }

    if (this._exhaustedKeys.size > 0) {
      console.log(`[GeminiKeyPool] ${this._exhaustedKeys.size}/${this._keys.length} keys are currently in cooldown`);
    }

    // Try each key starting from current index
    for (let i = 0; i < this._keys.length; i++) {
      const idx = (this._currentIndex + i) % this._keys.length;
      const key = this._keys[idx];

      if (!this._exhaustedKeys.has(key)) {
        this._currentIndex = (idx + 1) % this._keys.length;
        return key;
      }
    }

    return null; // All keys exhausted
  }

  /**
   * Mark a key as exhausted (quota exceeded)
   */
  _markExhausted(key) {
    const retryAfter = Date.now() + this._cooldownMs;
    this._exhaustedKeys.set(key, retryAfter);
    const available = this._keys.length - this._exhaustedKeys.size;
    console.log(`[GeminiKeyPool] Key ...${key.slice(-6)} exhausted. ${available}/${this._keys.length} keys available`);
  }

  /**
   * Check if an error is a quota/rate-limit error
   */
  _isQuotaError(error) {
    // Check status code first (standard way)
    if (error.status === 429) return true;
    
    // Check message for specific keywords, but avoid matching "generative"
    const msg = (error.message || '').toLowerCase();
    return (
      msg.includes('429') ||
      msg.includes('quota exceeded') ||
      msg.includes('rate_limit') ||
      msg.includes('too many requests') ||
      msg.includes('resource exhausted')
    );
  }

  /**
   * Generate content with automatic key rotation
   * 
   * @param {string} modelName - Gemini model name (e.g. 'gemini-2.0-flash')
   * @param {string|Array} prompt - The prompt to send
   * @param {Object} options - Optional generation config
   * @returns {Promise<{text: string, model: string, keyIndex: number}>}
   */
  async generateContent(modelName, prompt, options = {}) {
    const maxAttempts = this._keys.length;
    let lastError = null;

    const triedKeys = new Set();

    for (let attempt = 0; attempt < maxAttempts; attempt++) {
      // Find next key that is NOT globally exhausted AND not already tried in this call
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
        throw new Error(
          `[GeminiKeyPool] All available API keys have been tried for ${modelName} or are in cooldown.`
        );
      }

      triedKeys.add(apiKey);

      try {
        const keyLabel = `...${apiKey.slice(-6)}`;
        console.log(`[GeminiKeyPool] Attempt ${attempt + 1}/${maxAttempts} using key ${keyLabel} with model ${modelName}`);

        const genAI = new GoogleGenerativeAI(apiKey);
        const isExperimental = modelName.includes('2.0') || modelName.includes('1.5');
        const apiVersion = isExperimental ? 'v1beta' : 'v1';
        
        const model = genAI.getGenerativeModel(
          { model: modelName, ...options },
          { apiVersion }
        );

        const result = await model.generateContent(prompt);
        const response = await result.response;
        return {
          text: response.text().trim(),
          model: modelName,
          keyUsed: keyLabel
        };
      } catch (error) {
        lastError = error;

        // If it's a REAL quota error (429 but NOT limit 0), mark key as exhausted globally
        if (this._isQuotaError(error) && !error.message.includes('limit: 0')) {
          this._markExhausted(apiKey);
          console.warn(`[GeminiKeyPool] Quota error on key ...${apiKey.slice(-6)}: ${error.message}`);
          await new Promise(resolve => setTimeout(resolve, 200));
          continue; // Try next key
        }

        // If it's 404 or limit 0, it's a key/model incompatibility. 
        // Don't mark exhausted globally, just try next key in this loop.
        if (error.status === 404 || error.message.includes('limit: 0')) {
          console.warn(`[GeminiKeyPool] Key ...${apiKey.slice(-6)} does not support ${modelName}. Trying next key...`);
          continue; 
        }

        // Other non-retryable errors
        throw error;
      }
    }

    throw lastError || new Error('[GeminiKeyPool] All keys failed');
  }

  /**
   * Get a GoogleGenerativeAI instance with the next available key
   * (for cases where you need the raw SDK object)
   */
  getClient() {
    const apiKey = this._getNextAvailableKey();
    if (!apiKey) {
      throw new Error('[GeminiKeyPool] All API keys are exhausted');
    }
    return new GoogleGenerativeAI(apiKey);
  }

  /**
   * Get pool status for health checks
   */
  getStatus() {
    const now = Date.now();
    return {
      totalKeys: this._keys.length,
      availableKeys: this._keys.filter(k => !this._exhaustedKeys.has(k)).length,
      exhaustedKeys: this._exhaustedKeys.size,
      exhaustedDetails: [...this._exhaustedKeys.entries()].map(([key, retryAfter]) => ({
        key: `...${key.slice(-6)}`,
        retryInSeconds: Math.max(0, Math.ceil((retryAfter - now) / 1000))
      }))
    };
  }
}

// Singleton instance
const geminiKeyPool = new GeminiKeyPool();

module.exports = geminiKeyPool;
