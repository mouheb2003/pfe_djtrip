// ✅ ADDED
module.exports = function responseNormalizer(req, res, next) {
  const originalJson = res.json.bind(res);

  res.json = function normalizedJson(body) {
    const statusCode = res.statusCode || 200;

    if (!body || typeof body !== "object" || Array.isArray(body)) {
      const wrapped =
        statusCode >= 400
          ? { success: false, message: "Request failed", error: body }
          : { success: true, data: body };
      return originalJson(wrapped);
    }

    if (Object.prototype.hasOwnProperty.call(body, "success")) {
      return originalJson(body);
    }

    if (statusCode >= 400) {
      return originalJson({
        success: false,
        message: body.message || "Request failed",
        ...(body.error || body.errors
          ? { error: body.error || body.errors }
          : {}),
      });
    }

    return originalJson({
      success: true,
      ...body,
    });
  };

  next();
};
