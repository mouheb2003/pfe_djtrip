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

function actorLabel(userType) {
  const role = String(userType || "").toLowerCase();
  if (role === "admin") return "L'administrateur";
  if (role === "organisator") return "L'organisateur";
  if (role === "touriste") return "Le touriste";
  if (role === "anonymous") return "Un visiteur";
  return "L'utilisateur";
}

function readableTarget(pathname = "") {
  const clean = String(pathname || "").split("?")[0].toLowerCase();

  if (clean.includes("/messages/conversations")) return "les conversations";
  if (clean.includes("/messages")) return "les messages";
  if (clean.includes("/notifications")) return "les notifications";
  if (clean.includes("/posts")) return "les publications";
  if (clean.includes("/activites")) return "les activites";
  if (clean.includes("/lieux")) return "les lieux";
  if (clean.includes("/users")) return "les utilisateurs";

  const normalized = clean.replace(/^\/api\/v\d+\//, "");
  const firstSegment = normalized.split("/").filter(Boolean)[0] || "la ressource";
  return firstSegment;
}

function readableVerb(action, method) {
  const actionValue = String(action || "").toLowerCase();
  if (actionValue.endsWith(".create") || method === "POST") return "a cree";
  if (actionValue.endsWith(".update") || method === "PUT" || method === "PATCH")
    return "a modifie";
  if (actionValue.endsWith(".delete") || method === "DELETE") return "a supprime";
  if (actionValue === "message.send") return "a envoye";
  if (actionValue === "auth.login") return "s'est connecte";
  if (actionValue === "auth.logout") return "s'est deconnecte";
  return "a consulte";
}

function formatReadableRequestMessage({ action, userType, method, path, statusCode, durationMs }) {
  const actor = actorLabel(userType);
  const verb = readableVerb(action, method);
  const target = readableTarget(path);
  return `${actor} ${verb} ${target} (statut ${statusCode}, ${durationMs} ms)`;
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

    const msg = formatReadableRequestMessage({
      action,
      userType,
      method: req.method,
      path: req.originalUrl,
      statusCode: res.statusCode,
      durationMs,
    });

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
  });

  if (process.env.NODE_ENV !== "production") {
    req.safeHeaders = maskAuthHeader(req.headers);
  }

  next();
};
