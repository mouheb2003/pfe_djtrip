// ✅ ADDED
const systemLogStore = require("../services/systemLogStore");

function maskAuthHeader(headers) {
  if (!headers || !headers.authorization) return headers;
  return {
    ...headers,
    authorization: "[REDACTED]",
  };
}

function classifySource(pathname = "") {
  const path = String(pathname).toLowerCase();
  if (path.includes("/users/") || path.includes("/auth/")) return "auth";
  if (path.includes("/posts")) return "publication";
  if (path.includes("/activites")) return "activity";
  if (path.includes("/messages")) return "message";
  if (path.includes("/lieux")) return "place";
  return "request";
}

function classifyAction(method = "GET", pathname = "") {
  const m = String(method || "GET").toUpperCase();
  const path = String(pathname).toLowerCase();

  if (path.includes("/users/signin")) return "auth.login";
  if (path.includes("/users/signup")) return "auth.signup";
  if (path.includes("/users/logout")) return "auth.logout";
  if (path.includes("/users/forgot-password")) return "auth.forgot-password";
  if (path.includes("/users/reset-password")) return "auth.reset-password";

  if (path.includes("/posts")) {
    if (m === "POST") return "publication.create";
    if (m === "PUT" || m === "PATCH") return "publication.update";
    if (m === "DELETE") return "publication.delete";
    return "publication.read";
  }

  if (path.includes("/activites")) {
    if (m === "POST") return "activity.create";
    if (m === "PUT" || m === "PATCH") return "activity.update";
    if (m === "DELETE") return "activity.delete";
    return "activity.read";
  }

  if (path.includes("/messages")) {
    if (m === "POST") return "message.send";
    if (m === "DELETE") return "message.delete";
    return "message.read";
  }

  if (path.includes("/users")) {
    if (m === "PUT" || m === "PATCH") return "user.update";
    if (m === "DELETE") return "user.delete";
    return "user.read";
  }

  return "request.generic";
}

function levelFromStatus(statusCode) {
  if (statusCode >= 500) return "error";
  if (statusCode >= 400) return "warn";
  return "info";
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
    const userId = req.user?.userId || "guest";
    const userType = req.user?.userType || "anonymous";
    const source = classifySource(req.originalUrl);
    const action = classifyAction(req.method, req.originalUrl);
    const level = levelFromStatus(res.statusCode);

    const msg =
      `[${source.toUpperCase()}] action=${action} user=${userId} role=${userType} ` +
      `method=${req.method} path=${req.originalUrl} status=${res.statusCode} ` +
      `duration=${durationMs}ms requestId=${requestId}`;

    systemLogStore.addLog({
      level,
      source,
      message: msg,
      action,
      userId,
      userType,
      method: req.method,
      path: req.originalUrl,
      statusCode: res.statusCode,
      durationMs,
      requestId,
    });

    console.log(msg);
  });

  if (process.env.NODE_ENV !== "production") {
    req.safeHeaders = maskAuthHeader(req.headers);
  }

  next();
};
