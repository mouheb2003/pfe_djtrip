const { createActivityLog } = require("../services/activityLogService");

const EXCLUDED_PREFIXES = [
  "/api/v1/logs",
  "/api/logs",
  "/api/v1/system-logs",
  "/api/system-logs",
  "/api/health",
  "/api/v1/debug",
  "/api/debug",
];

function normalizePath(originalUrl = "") {
  return String(originalUrl || "").split("?")[0] || "";
}

function isExcludedPath(pathname) {
  return EXCLUDED_PREFIXES.some((prefix) => pathname.startsWith(prefix));
}

function deriveTargetType(pathname) {
  const parts = String(pathname || "").split("/").filter(Boolean);
  if (!parts.length) return "system";

  let index = 0;
  if (parts[index] === "api") index += 1;
  if (parts[index] === "v1") index += 1;

  return parts[index] || "system";
}

module.exports = function requestActivityLogger(req, res, next) {
  res.on("finish", async () => {
    try {
      const actorId = req.user?.userId;
      if (!actorId) return;

      if (req.method === "OPTIONS") return;
      if (res.statusCode < 200 || res.statusCode >= 400) return;

      const endpoint = normalizePath(req.originalUrl);
      if (!endpoint || isExcludedPath(endpoint)) return;

      const targetType = deriveTargetType(endpoint);

      await createActivityLog({
        actorId,
        action: "api_request",
        targetType,
        targetId: actorId,
        templateKey: "api_request",
        metadata: {
          method: req.method,
          endpoint,
          statusCode: res.statusCode,
        },
      });
    } catch (_err) {
      // Never interrupt request flow if logging fails.
    }
  });

  next();
};
