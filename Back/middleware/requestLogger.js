// ✅ ADDED
const systemLogStore = require("../services/systemLogStore");
const { formatReadableDate } = require("../utils/logTemplates");

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

function generateDescriptiveMessage(method, path, statusCode, userId, userType, durationMs) {
  const m = String(method || "GET").toUpperCase();
  const p = String(path).toLowerCase();
  const statusText = statusCode >= 200 && statusCode < 300 ? "succès" : "échec";
  const timestamp = formatReadableDate();

  // Authentication actions
  if (p.includes("/users/signin") || p.includes("/auth/login")) {
    const userDesc = userId !== "guest" ? `utilisateur ${userId}` : "utilisateur anonyme";
    return `${timestamp} - Connexion de ${userDesc} (${userType}) : ${statusText} (${statusCode}) - Durée: ${durationMs}ms`;
  }
  if (p.includes("/users/signup") || p.includes("/auth/signup")) {
    return `${timestamp} - Inscription d'un nouvel utilisateur : ${statusText} (${statusCode}) - Durée: ${durationMs}ms`;
  }
  if (p.includes("/users/logout") || p.includes("/auth/logout")) {
    return `${timestamp} - Déconnexion de l'utilisateur ${userId} (${userType}) : ${statusText} (${statusCode}) - Durée: ${durationMs}ms`;
  }
  if (p.includes("/users/forgot-password")) {
    return `${timestamp} - Demande de réinitialisation de mot de passe par l'utilisateur ${userId} : ${statusText} (${statusCode}) - Durée: ${durationMs}ms`;
  }
  if (p.includes("/users/reset-password")) {
    return `${timestamp} - Réinitialisation du mot de passe par l'utilisateur ${userId} : ${statusText} (${statusCode}) - Durée: ${durationMs}ms`;
  }

  // Publication actions
  if (p.includes("/posts")) {
    if (m === "POST") return `${timestamp} - Création d'une publication par l'utilisateur ${userId} (${userType}) : ${statusText} (${statusCode}) - Durée: ${durationMs}ms`;
    if (m === "PUT" || m === "PATCH") return `${timestamp} - Modification d'une publication par l'utilisateur ${userId} (${userType}) : ${statusText} (${statusCode}) - Durée: ${durationMs}ms`;
    if (m === "DELETE") return `${timestamp} - Suppression d'une publication par l'utilisateur ${userId} (${userType}) : ${statusText} (${statusCode}) - Durée: ${durationMs}ms`;
    return `${timestamp} - Consultation des publications par l'utilisateur ${userId} (${userType}) : ${statusText} (${statusCode}) - Durée: ${durationMs}ms`;
  }

  // Activity actions
  if (p.includes("/activites")) {
    if (m === "POST") return `${timestamp} - Création d'une activité par l'utilisateur ${userId} (${userType}) : ${statusText} (${statusCode}) - Durée: ${durationMs}ms`;
    if (m === "PUT" || m === "PATCH") return `${timestamp} - Modification d'une activité par l'utilisateur ${userId} (${userType}) : ${statusText} (${statusCode}) - Durée: ${durationMs}ms`;
    if (m === "DELETE") return `${timestamp} - Suppression d'une activité par l'utilisateur ${userId} (${userType}) : ${statusText} (${statusCode}) - Durée: ${durationMs}ms`;
    return `${timestamp} - Consultation des activités par l'utilisateur ${userId} (${userType}) : ${statusText} (${statusCode}) - Durée: ${durationMs}ms`;
  }

  // Message actions
  if (p.includes("/messages")) {
    if (m === "POST") return `${timestamp} - Envoi d'un message par l'utilisateur ${userId} (${userType}) : ${statusText} (${statusCode}) - Durée: ${durationMs}ms`;
    if (m === "DELETE") return `${timestamp} - Suppression d'un message par l'utilisateur ${userId} (${userType}) : ${statusText} (${statusCode}) - Durée: ${durationMs}ms`;
    return `${timestamp} - Consultation des messages par l'utilisateur ${userId} (${userType}) : ${statusText} (${statusCode}) - Durée: ${durationMs}ms`;
  }

  // User actions
  if (p.includes("/users")) {
    if (m === "PUT" || m === "PATCH") return `${timestamp} - Mise à jour du profil par l'utilisateur ${userId} (${userType}) : ${statusText} (${statusCode}) - Durée: ${durationMs}ms`;
    if (m === "DELETE") return `${timestamp} - Suppression du compte par l'utilisateur ${userId} (${userType}) : ${statusText} (${statusCode}) - Durée: ${durationMs}ms`;
    return `${timestamp} - Consultation des utilisateurs par ${userId} (${userType}) : ${statusText} (${statusCode}) - Durée: ${durationMs}ms`;
  }

  // Place actions
  if (p.includes("/lieux")) {
    if (m === "POST") return `${timestamp} - Ajout d'un lieu par l'utilisateur ${userId} (${userType}) : ${statusText} (${statusCode}) - Durée: ${durationMs}ms`;
    if (m === "PUT" || m === "PATCH") return `${timestamp} - Modification d'un lieu par l'utilisateur ${userId} (${userType}) : ${statusText} (${statusCode}) - Durée: ${durationMs}ms`;
    if (m === "DELETE") return `${timestamp} - Suppression d'un lieu par l'utilisateur ${userId} (${userType}) : ${statusText} (${statusCode}) - Durée: ${durationMs}ms`;
    return `${timestamp} - Consultation des lieux par l'utilisateur ${userId} (${userType}) : ${statusText} (${statusCode}) - Durée: ${durationMs}ms`;
  }

  // Generic request
  return `${timestamp} - Requête ${m} sur ${path} par l'utilisateur ${userId} (${userType}) : ${statusText} (${statusCode}) - Durée: ${durationMs}ms`;
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

    const msg = generateDescriptiveMessage(
      req.method,
      req.originalUrl,
      res.statusCode,
      userId,
      userType,
      durationMs
    );

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
