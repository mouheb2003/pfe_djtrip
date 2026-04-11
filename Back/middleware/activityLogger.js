const { createActivityLog } = require("../services/activityLogService");

// Optional middleware: logs an action when request succeeds.
// Usage:
// router.post('/x', verifyToken, controller.doX, activityLogger((req) => ({ ... })))
module.exports = function activityLogger(resolvePayload) {
  return (req, res, next) => {
    res.on("finish", async () => {
      try {
        if (res.statusCode < 200 || res.statusCode >= 300) return;
        if (typeof resolvePayload !== "function") return;

        const payload = await resolvePayload(req, res);
        if (!payload) return;

        await createActivityLog(payload);
      } catch (_err) {
        // Logging should never break the main request flow.
      }
    });

    next();
  };
};
