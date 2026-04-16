const logTemplates = {
  create_post: '{actor} a publie "{title}" le {date}',
  book_activity: "{actor} a reserve {count} places le {date}",
  approve_request: "{actor} a approuve une demande le {date}",
  reject_request: "{actor} a refuse une demande le {date}",
  cancel_booking: "{actor} a annule une reservation le {date}",
  update_user_status:
    "{actor} a change le statut du compte ({targetName}) vers {status} le {date}",
  ban_user: "{actor} a banni l'utilisateur {targetName} le {date}",
  unban_user: "{actor} a debanni l'utilisateur {targetName} le {date}",
  update_post_admin: "{actor} a modifie une publication le {date}",
  delete_post_admin: "{actor} a supprime une publication le {date}",
  verify_booking:
    "{actor} a verifie une reservation pour {targetName} ({activityTitle}) le {date}",
  user_signup: "{actor} a cree un compte le {date}",
  user_login: "{actor} s'est connecte le {date}",
  user_logout: "{actor} s'est deconnecte le {date}",
  api_request: "{apiAction}",
};

// Traduit les actions API techniques en messages compréhensibles
function translateApiAction(method, endpoint, actor, date) {
  const actionMap = {
    // Messages
    "GET /api/v1/messages": "{actor} a consulte les messages le {date}",
    "GET /api/v1/messages/conversations": "{actor} a consulte les conversations de messages le {date}",
    "POST /api/v1/messages": "{actor} a envoye un message le {date}",
    "PUT /api/v1/messages": "{actor} a modifie un message le {date}",
    "DELETE /api/v1/messages": "{actor} a supprime un message le {date}",
    
    // Notifications
    "GET /api/v1/notifications": "{actor} a consulte les notifications le {date}",
    "PUT /api/v1/notifications": "{actor} a modifie une notification le {date}",
    
    // Utilisateurs
    "GET /api/v1/users": "{actor} a consulte la liste des utilisateurs le {date}",
    "GET /api/v1/users/me": "{actor} a consulte son profil le {date}",
    "GET /api/v1/profile": "{actor} a consulte son profil le {date}",
    "PUT /api/v1/profile": "{actor} a modifie son profil le {date}",
    
    // Activités
    "GET /api/v1/activites": "{actor} a consulte les activites le {date}",
    "POST /api/v1/activites": "{actor} a cree une activite le {date}",
    "PUT /api/v1/activites": "{actor} a modifie une activite le {date}",
    "DELETE /api/v1/activites": "{actor} a supprime une activite le {date}",
    
    // Publications
    "GET /api/v1/publications": "{actor} a consulte les publications le {date}",
    "POST /api/v1/publications": "{actor} a cree une publication le {date}",
    "PUT /api/v1/publications": "{actor} a modifie une publication le {date}",
    "DELETE /api/v1/publications": "{actor} a supprime une publication le {date}",
    
    // Lieux
    "GET /api/v1/lieux": "{actor} a consulte les lieux le {date}",
    "POST /api/v1/lieux": "{actor} a cree un lieu le {date}",
    "PUT /api/v1/lieux": "{actor} a modifie un lieu le {date}",
    "DELETE /api/v1/lieux": "{actor} a supprime un lieu le {date}",
    
    // Réservations
    "GET /api/v1/bookings": "{actor} a consulte les reservations le {date}",
    "POST /api/v1/bookings": "{actor} a effectue une reservation le {date}",
    "PUT /api/v1/bookings": "{actor} a modifie une reservation le {date}",
    "DELETE /api/v1/bookings": "{actor} a annule une reservation le {date}",
    
    // Commentaires
    "GET /api/v1/comments": "{actor} a consulte les commentaires le {date}",
    "POST /api/v1/comments": "{actor} a ajoute un commentaire le {date}",
    "PUT /api/v1/comments": "{actor} a modifie un commentaire le {date}",
    "DELETE /api/v1/comments": "{actor} a supprime un commentaire le {date}",
  };
  
  // Essayer correspondance exacte
  const fullKey = `${method} ${endpoint}`;
  if (actionMap[fullKey]) {
    return actionMap[fullKey].replace(/{actor}/g, actor).replace(/{date}/g, date);
  }
  
  // Essayer correspondance partielle (sans paramètres)
  const baseEndpoint = endpoint.split('?')[0].replace(/\/\d+/g, '');
  const partialKey = `${method} ${baseEndpoint}`;
  if (actionMap[partialKey]) {
    return actionMap[partialKey].replace(/{actor}/g, actor).replace(/{date}/g, date);
  }
  
  // Fallback: utiliser un format générique
  const methodTranslations = {
    GET: "a consulte",
    POST: "a cree",
    PUT: "a modifie",
    DELETE: "a supprime",
    PATCH: "a mis a jour"
  };
  
  const resource = endpoint.replace(/^\/api\/v\d+\//, '').split('/')[0] || 'ressource';
  const methodAction = methodTranslations[method] || "a effectue une action sur";
  
  return `${actor} ${methodAction} ${resource} le ${date}`;
}

function formatReadableDate(value = new Date()) {
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) {
    return "date inconnue";
  }

  const day = new Intl.DateTimeFormat("fr-FR", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
  }).format(date);

  const time = new Intl.DateTimeFormat("fr-FR", {
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).format(date);

  return `${day} a ${time}`;
}

function generateLog(templateKey, data = {}) {
  const template = logTemplates[templateKey];
  if (!template) {
    throw new Error(`Unknown log template key: ${templateKey}`);
  }

  const payload = {
    date: formatReadableDate(data.date),
    ...data,
  };

  // Traitement spécial pour les requêtes API
  if (templateKey === 'api_request') {
    const { method, endpoint, actor, date } = payload;
    const readableDate = date || formatReadableDate(data.date);
    return translateApiAction(method, endpoint, actor, readableDate);
  }

  return template.replace(/\{(\w+)\}/g, (_match, variable) => {
    const value = payload[variable];
    if (value === undefined || value === null || value === "") {
      return "-";
    }
    return String(value);
  });
}

module.exports = {
  logTemplates,
  formatReadableDate,
  generateLog,
  translateApiAction,
};
