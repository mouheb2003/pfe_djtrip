// ✅ ADDED
module.exports = function responseNormalizer(req, res, next) {
  const originalJson = res.json.bind(res);

  function maybeParseJsonString(value) {
    if (typeof value !== "string") return value;

    const trimmed = value.trim();
    if (!trimmed) return value;
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

  res.json = function normalizedJson(body) {
    const statusCode = res.statusCode || 200;
    const normalizedBody = maybeParseJsonString(body);

    if (
      !normalizedBody ||
      typeof normalizedBody !== "object" ||
      Array.isArray(normalizedBody)
    ) {
      const wrapped =
        statusCode >= 400
          ? { success: false, message: "Request failed", error: normalizedBody }
          : { success: true, data: normalizedBody };
      return originalJson(wrapped);
    }

    if (Object.prototype.hasOwnProperty.call(normalizedBody, "success")) {
      return originalJson(normalizedBody);
    }

    if (statusCode >= 400) {
      return originalJson({
        success: false,
        message: normalizedBody.message || "Request failed",
        ...(normalizedBody.error || normalizedBody.errors
          ? { error: normalizedBody.error || normalizedBody.errors }
          : {}),
      });
    }

    return originalJson({
      success: true,
      ...normalizedBody,
    });
  };

  next();
};
