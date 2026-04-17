// ✅ ADDED
const cacheService = require("../services/cache");

function maybeParseJsonString(value) {
  if (typeof value !== "string") return value;

  const trimmed = value.trim();
  if (!trimmed) return value;

  // Parse nested JSON strings defensively (max 2 passes).
  if (
    !(
      trimmed.startsWith("{") ||
      trimmed.startsWith("[") ||
      trimmed.startsWith('"')
    )
  ) {
    return value;
  }

  let parsed = value;
  for (let i = 0; i < 2; i += 1) {
    if (typeof parsed !== "string") break;
    try {
      parsed = JSON.parse(parsed);
    } catch (_) {
      break;
    }
  }

  return parsed;
}

function buildCacheKey(req, namespace = "global") {
  const userPart = req.user?.userId ? `:u:${req.user.userId}` : "";
  return `cache:${namespace}:${req.originalUrl}${userPart}`;
}

function setConditionalHeaders(req, res, lastModifiedMs) {
  if (!lastModifiedMs) return false;

  const lastModified = new Date(lastModifiedMs).toUTCString();
  res.setHeader("Last-Modified", lastModified);

  const ifModifiedSince = req.headers["if-modified-since"];
  if (!ifModifiedSince) return false;

  const sinceTs = Date.parse(ifModifiedSince);
  if (Number.isNaN(sinceTs)) return false;

  return sinceTs >= lastModifiedMs;
}

exports.cacheGet = (namespace, ttlSeconds = 60) => {
  return async (req, res, next) => {
    if (req.method !== "GET") return next();

    const key = buildCacheKey(req, namespace);
    const cached = await cacheService.get(key);

    if (cached && cached.value) {
      res.setHeader("x-cache", "HIT");
      if (setConditionalHeaders(req, res, cached.lastModified)) {
        return res.status(304).end();
      }
      return res.status(200).json(maybeParseJsonString(cached.value));
    }

    res.setHeader("x-cache", "MISS");

    const originalJson = res.json.bind(res);
    res.json = (payload) => {
      if (res.statusCode >= 200 && res.statusCode < 300) {
        cacheService
          .set(key, maybeParseJsonString(payload), ttlSeconds)
          .catch((err) => {
            console.error("[CACHE] Failed to cache response:", err.message);
          });
      }
      return originalJson(payload);
    };

    return next();
  };
};

exports.invalidateCache = (patterns = []) => {
  const values = Array.isArray(patterns) ? patterns : [patterns];

  return (req, res, next) => {
    console.log('[CACHE invalidateCache] Starting with patterns:', patterns);
    res.on("finish", async () => {
      if (res.statusCode >= 400) return;
      try {
        await Promise.all(
          values.map((pattern) => cacheService.delByPattern(pattern).catch(err => {
            console.warn('[CACHE] Failed to invalidate pattern:', pattern, err.message);
          })),
        );
      } catch (error) {
        console.warn('[CACHE] Cache invalidation error:', error.message);
      }
    });
    console.log('[CACHE invalidateCache] Passing to next');
    next();
  };
};
