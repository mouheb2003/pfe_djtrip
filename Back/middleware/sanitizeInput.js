// ✅ ADDED
function sanitizeValue(value) {
  if (typeof value === "string") {
    return value.replace(/[<>]/g, "").trim();
  }

  if (Array.isArray(value)) {
    return value.map(sanitizeValue);
  }

  if (value && typeof value === "object") {
    const result = {};
    for (const [key, val] of Object.entries(value)) {
      if (key.startsWith("$") || key.includes(".")) continue;
      result[key] = sanitizeValue(val);
    }
    return result;
  }

  return value;
}

module.exports = function sanitizeInput(req, res, next) {
  if (req.body && typeof req.body === "object") {
    Object.assign(req.body, sanitizeValue(req.body));
  }
  if (req.query && typeof req.query === "object") {
    Object.assign(req.query, sanitizeValue(req.query));
  }
  if (req.params && typeof req.params === "object") {
    Object.assign(req.params, sanitizeValue(req.params));
  }

  next();
};
