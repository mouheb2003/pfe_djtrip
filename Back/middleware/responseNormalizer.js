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
      // Preserve account restriction fields for 403 responses
      const restrictionFields = {};
      if (statusCode === 403) {
        if (normalizedBody.type) restrictionFields.type = normalizedBody.type;
        if (normalizedBody.forceLogout !== undefined) restrictionFields.forceLogout = normalizedBody.forceLogout;
        if (normalizedBody.reason !== undefined) restrictionFields.reason = normalizedBody.reason;
        if (normalizedBody.suspendedUntil !== undefined) restrictionFields.suspendedUntil = normalizedBody.suspendedUntil;
        if (normalizedBody.remainingSeconds !== undefined) restrictionFields.remainingSeconds = normalizedBody.remainingSeconds;
      }

      // Robust message extraction
      let displayMessage = normalizedBody.message || normalizedBody.reason || "Request failed";
      
      // If message is generic but there's a specific error object, try to extract from it
      const errObj = normalizedBody.error || normalizedBody.errors;
      if (errObj) {
        if (typeof errObj === 'string') {
          displayMessage = errObj;
        } else if (typeof errObj === 'object') {
          // Handle Mongoose validation errors (errors: { field: { message: "..." } })
          const firstErrKey = Object.keys(errObj)[0];
          if (firstErrKey && errObj[firstErrKey] && errObj[firstErrKey].message) {
            displayMessage = errObj[firstErrKey].message;
          } else if (errObj.message) {
            displayMessage = errObj.message;
          }
        }
      }

      return originalJson({
        success: false,
        message: displayMessage,
        ...(normalizedBody.error || normalizedBody.errors
          ? { error: normalizedBody.error || normalizedBody.errors }
          : {}),
        ...restrictionFields,
      });
    }

    return originalJson({
      success: true,
      ...normalizedBody,
    });
  };

  next();
};
