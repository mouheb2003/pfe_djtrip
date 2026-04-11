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
};

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
};
