// ✅ ADDED
const DEFAULT_TTL_SECONDS = Number(process.env.CACHE_TTL_SECONDS || 60);

class MemoryCache {
  constructor() {
    this.store = new Map();
  }

  get(key) {
    const item = this.store.get(key);
    if (!item) return null;

    if (item.expiresAt < Date.now()) {
      this.store.delete(key);
      return null;
    }

    return item;
  }

  set(key, payload, ttlSeconds = DEFAULT_TTL_SECONDS) {
    this.store.set(key, {
      value: payload,
      lastModified: Date.now(),
      expiresAt: Date.now() + ttlSeconds * 1000,
    });
  }

  delByPattern(pattern) {
    let deleted = 0;
    for (const key of this.store.keys()) {
      if (key.includes(pattern)) {
        this.store.delete(key);
        deleted += 1;
      }
    }
    return deleted;
  }

  get size() {
    return this.store.size;
  }
}

class CacheService {
  constructor() {
    this.memory = new MemoryCache();
    this.redisEnabled =
      String(process.env.ENABLE_REDIS || "false").toLowerCase() === "true";
    this.redisClient = null;
    this.redisAvailable = false;
    this.redisConnecting = false;
  }

  async initRedis() {
    if (!this.redisEnabled || this.redisAvailable || this.redisConnecting)
      return;

    this.redisConnecting = true;
    try {
      let redisModule;
      try {
        redisModule = require("redis");
      } catch (error) {
        console.warn(
          "[CACHE] Redis package not installed, falling back to memory cache",
        );
        this.redisEnabled = false;
        return;
      }

      const redisUrl = process.env.REDIS_URL;
      this.redisClient = redisModule.createClient(
        redisUrl ? { url: redisUrl } : undefined,
      );

      this.redisClient.on("error", (err) => {
        console.error("[CACHE] Redis error:", err.message);
        this.redisAvailable = false;
      });

      await this.redisClient.connect();
      this.redisAvailable = true;
      console.log("[CACHE] Redis connected");
    } catch (error) {
      this.redisAvailable = false;
      console.error("[CACHE] Redis unavailable, using memory cache");
    } finally {
      this.redisConnecting = false;
    }
  }

  async get(key) {
    await this.initRedis();

    if (this.redisAvailable && this.redisClient) {
      try {
        const raw = await this.redisClient.get(key);
        if (!raw) return null;
        return JSON.parse(raw);
      } catch (error) {
        console.error("[CACHE] Redis get failed:", error.message);
      }
    }

    return this.memory.get(key);
  }

  async set(key, payload, ttlSeconds = DEFAULT_TTL_SECONDS) {
    await this.initRedis();

    const cachePayload = {
      value: payload,
      lastModified: Date.now(),
    };

    if (this.redisAvailable && this.redisClient) {
      try {
        await this.redisClient.setEx(
          key,
          ttlSeconds,
          JSON.stringify(cachePayload),
        );
        return;
      } catch (error) {
        console.error("[CACHE] Redis set failed:", error.message);
      }
    }

    this.memory.set(key, payload, ttlSeconds);
  }

  async delByPattern(pattern) {
    await this.initRedis();

    let redisDeleted = 0;
    if (this.redisAvailable && this.redisClient) {
      try {
        const keys = await this.redisClient.keys(`*${pattern}*`);
        if (keys.length > 0) {
          redisDeleted = await this.redisClient.del(keys);
        }
      } catch (error) {
        console.error("[CACHE] Redis delete failed:", error.message);
      }
    }

    const memoryDeleted = this.memory.delByPattern(pattern);
    return redisDeleted + memoryDeleted;
  }

  getStatus() {
    return {
      mode: this.redisAvailable ? "redis" : "memory",
      redisEnabled: this.redisEnabled,
      redisAvailable: this.redisAvailable,
      memoryEntries: this.memory.size,
      ttlSeconds: DEFAULT_TTL_SECONDS,
    };
  }
}

module.exports = new CacheService();
