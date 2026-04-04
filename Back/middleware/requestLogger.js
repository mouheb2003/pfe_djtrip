// ✅ ADDED
function maskAuthHeader(headers) {
  if (!headers || !headers.authorization) return headers;
  return {
    ...headers,
    authorization: "[REDACTED]",
  };
}

module.exports = function requestLogger(req, res, next) {
  const startedAt = Date.now();
  const requestId =
    req.headers["x-request-id"] ||
    `${Date.now()}-${Math.random().toString(16).slice(2, 8)}`;

  req.requestId = requestId;
  res.setHeader("x-request-id", requestId);

  res.on("finish", () => {
    const durationMs = Date.now() - startedAt;
    console.log(
      `[REQ] ${req.method} ${req.originalUrl} ${res.statusCode} ${durationMs}ms requestId=${requestId}`,
    );
  });

  if (process.env.NODE_ENV !== "production") {
    req.safeHeaders = maskAuthHeader(req.headers);
  }

  next();
};
