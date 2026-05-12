import fs from 'fs/promises';
import path from 'path';
import crypto from 'crypto';
import { config } from '../config/index.js';

class CacheService {
  constructor() {
    this.cachePath = config.cacheStoragePath;
    this.cacheFile = path.join(this.cachePath, 'cache.json');
    this.cache = new Map();
    this.ttl = 60 * 60 * 1000; // 1 hour default TTL
  }

  async ensureCacheDirectory() {
    try {
      await fs.mkdir(this.cachePath, { recursive: true });
    } catch (error) {
      console.error('Error creating cache directory:', error.message);
      throw error;
    }
  }

  generateKey(key) {
    return crypto.createHash('md5').update(key).digest('hex');
  }

  async loadCache() {
    try {
      const data = await fs.readFile(this.cacheFile, 'utf-8');
      const cacheData = JSON.parse(data);
      
      // Convert to Map and filter expired entries
      const now = Date.now();
      for (const [key, value] of Object.entries(cacheData)) {
        if (value.expiresAt > now) {
          this.cache.set(key, value);
        }
      }
      
      console.log(`Loaded ${this.cache.size} cache entries`);
    } catch (error) {
      if (error.code !== 'ENOENT') {
        console.error('Error loading cache:', error.message);
      }
      this.cache = new Map();
    }
  }

  async saveCache() {
    try {
      await this.ensureCacheDirectory();
      
      const cacheData = {};
      const now = Date.now();
      
      for (const [key, value] of this.cache.entries()) {
        if (value.expiresAt > now) {
          cacheData[key] = value;
        }
      }
      
      await fs.writeFile(this.cacheFile, JSON.stringify(cacheData, null, 2));
    } catch (error) {
      console.error('Error saving cache:', error.message);
    }
  }

  set(key, value, ttl = this.ttl) {
    const cacheKey = this.generateKey(key);
    const expiresAt = Date.now() + ttl;
    
    this.cache.set(cacheKey, {
      value,
      expiresAt,
      createdAt: Date.now(),
    });
  }

  get(key) {
    const cacheKey = this.generateKey(key);
    const entry = this.cache.get(cacheKey);
    
    if (!entry) {
      return null;
    }
    
    if (Date.now() > entry.expiresAt) {
      this.cache.delete(cacheKey);
      return null;
    }
    
    return entry.value;
  }

  has(key) {
    return this.get(key) !== null;
  }

  delete(key) {
    const cacheKey = this.generateKey(key);
    return this.cache.delete(cacheKey);
  }

  clear() {
    this.cache.clear();
  }

  async cleanup() {
    const now = Date.now();
    const keysToDelete = [];
    
    for (const [key, value] of this.cache.entries()) {
      if (now > value.expiresAt) {
        keysToDelete.push(key);
      }
    }
    
    for (const key of keysToDelete) {
      this.cache.delete(key);
    }
    
    if (keysToDelete.length > 0) {
      await this.saveCache();
      console.log(`Cleaned up ${keysToDelete.length} expired cache entries`);
    }
    
    return keysToDelete.length;
  }

  getStats() {
    const now = Date.now();
    let totalEntries = this.cache.size;
    let expiredEntries = 0;
    let validEntries = 0;
    
    for (const value of this.cache.values()) {
      if (now > value.expiresAt) {
        expiredEntries++;
      } else {
        validEntries++;
      }
    }
    
    return {
      totalEntries,
      validEntries,
      expiredEntries,
      hitRate: this.calculateHitRate(),
    };
  }

  calculateHitRate() {
    if (this.hits === undefined || this.misses === undefined) {
      return 0;
    }
    
    const total = this.hits + this.misses;
    return total === 0 ? 0 : this.hits / total;
  }

  recordHit() {
    this.hits = (this.hits || 0) + 1;
  }

  recordMiss() {
    this.misses = (this.misses || 0) + 1;
  }

  async getOrSet(key, valueFn, ttl = this.ttl) {
    const cached = this.get(key);
    
    if (cached !== null) {
      this.recordHit();
      return cached;
    }
    
    this.recordMiss();
    const value = await valueFn();
    this.set(key, value, ttl);
    await this.saveCache();
    
    return value;
  }

  async invalidatePattern(pattern) {
    const regex = new RegExp(pattern);
    const keysToDelete = [];
    
    for (const key of this.cache.keys()) {
      if (regex.test(key)) {
        keysToDelete.push(key);
      }
    }
    
    for (const key of keysToDelete) {
      this.cache.delete(key);
    }
    
    if (keysToDelete.length > 0) {
      await this.saveCache();
    }
    
    return keysToDelete.length;
  }
}

export default new CacheService();
