/**
 * Système de génération de username unique et symbolique
 * Basé sur le fullname de l'utilisateur avec ajout symbolique
 */

const crypto = require('crypto');

/**
 * Nettoie et normalise un nom pour en faire une base de username
 */
function normalizeName(fullname) {
  if (!fullname) return 'user';
  
  return fullname
    .toLowerCase()
    .trim()
    .replace(/[àáâäãåāăă]/g, 'a')
    .replace(/[èéêëēĕė]/g, 'e')
    .replace(/[ìíîïĩīĭ]/g, 'i')
    .replace(/[òóôöõøōŏ]/g, 'o')
    .replace(/[ùúûüũūŭ]/g, 'u')
    .replace(/[ýÿ]/g, 'y')
    .replace(/[ñń]/g, 'n')
    .replace(/[çčć]/g, 'c')
    .replace(/[šş]/g, 's')
    .replace(/[ž]/g, 'z')
    .replace(/[^a-z0-9\s]/g, '') // Garder seulement lettres, chiffres et espaces
    .replace(/\s+/g, ' ') // Unifier les espaces
    .trim();
}

/**
 * Symboles symboliques à ajouter pour l'unicité
 */
const SYMBOLIC_SUFFIXES = [
  '_dj', '_trip', '_djerba', '_tunis', '_travel', '_explore',
  '_adventure', '_guide', '_local', '_tunisia', '_visit',
  '_discover', '_journey', '_wander', '_exp', '_djt',
  '_sea', '_sun', '_beach', '_med', '_africa'
];

/**
 * Suffixes numériques pour l'unicité
 */
function getNumericSuffix() {
  const timestamp = Date.now().toString(36);
  const random = Math.random().toString(36).substr(2, 5);
  return timestamp + random;
}

/**
 * Génère un username unique basé sur le fullname
 * @param {string} fullname - Nom complet de l'utilisateur
 * @param {Array} existingUsernames - Liste des usernames existants à éviter
 * @returns {string} Username unique généré
 */
function generateUniqueUsername(fullname, existingUsernames = []) {
  const baseName = normalizeName(fullname);
  const nameParts = baseName.split(' ').filter(part => part.length > 0);
  
  // Stratégies de génération par ordre de préférence
  const strategies = [
    // 1. Nom complet sans espaces + suffix symbolique
    () => {
      const cleanName = nameParts.join('');
      const suffix = SYMBOLIC_SUFFIXES[Math.floor(Math.random() * SYMBOLIC_SUFFIXES.length)];
      return cleanName + suffix;
    },
    
    // 2. Première lettre + nom + suffix symbolique
    () => {
      if (nameParts.length >= 2) {
        const firstInitial = nameParts[0][0];
        const lastName = nameParts[nameParts.length - 1];
        const suffix = SYMBOLIC_SUFFIXES[Math.floor(Math.random() * SYMBOLIC_SUFFIXES.length)];
        return firstInitial + lastName + suffix;
      }
      return null;
    },
    
    // 3. Nom + suffix numérique court
    () => {
      const cleanName = nameParts.join('');
      const shortSuffix = getNumericSuffix().substr(0, 4);
      return cleanName + '_' + shortSuffix;
    },
    
    // 4. Nom tronqué + suffix symbolique
    () => {
      const cleanName = nameParts.join('');
      const truncated = cleanName.substr(0, 12); // Limiter à 12 caractères
      const suffix = SYMBOLIC_SUFFIXES[Math.floor(Math.random() * SYMBOLIC_SUFFIXES.length)];
      return truncated + suffix;
    },
    
    // 5. Initiales + suffix symbolique
    () => {
      const initials = nameParts.map(part => part[0]).join('');
      const suffix = SYMBOLIC_SUFFIXES[Math.floor(Math.random() * SYMBOLIC_SUFFIXES.length)];
      return initials + suffix;
    },
    
    // 6. Nom + hash court
    () => {
      const cleanName = nameParts.join('');
      const hash = crypto.createHash('md5').update(cleanName + Date.now()).digest('hex').substr(0, 6);
      return cleanName + '_' + hash;
    },
    
    // 7. Génération aléatoire de secours
    () => {
      const adjectives = ['happy', 'lucky', 'smart', 'cool', 'friendly', 'brave', 'quick', 'bright'];
      const nouns = ['traveler', 'explorer', 'adventurer', 'guide', 'visitor', 'wanderer', 'journeyer'];
      
      const adj = adjectives[Math.floor(Math.random() * adjectives.length)];
      const noun = nouns[Math.floor(Math.random() * nouns.length)];
      const suffix = SYMBOLIC_SUFFIXES[Math.floor(Math.random() * SYMBOLIC_SUFFIXES.length)];
      
      return adj + '_' + noun + suffix;
    }
  ];
  
  // Essayer chaque stratégie jusqu'à trouver un username unique
  for (const strategy of strategies) {
    try {
      const username = strategy();
      if (!username) continue;
      
      // Vérifier que le username est valide et unique
      if (isValidUsername(username) && !existingUsernames.includes(username.toLowerCase())) {
        return username.toLowerCase();
      }
    } catch (error) {
      console.warn('Username generation strategy failed:', error.message);
      continue;
    }
  }
  
  // En dernier recours, générer quelque chose d'unique
  const fallback = 'user_' + getNumericSuffix();
  return fallback.toLowerCase();
}

/**
 * Vérifie si un username est valide
 * @param {string} username - Username à valider
 * @returns {boolean} True si valide
 */
function isValidUsername(username) {
  if (!username || typeof username !== 'string') {
    return false;
  }
  
  // Longueur: 3-30 caractères
  if (username.length < 3 || username.length > 30) {
    return false;
  }
  
  // Caractères autorisés: lettres, chiffres, underscores
  const validPattern = /^[a-z0-9_]+$/;
  if (!validPattern.test(username)) {
    return false;
  }
  
  // Ne pas commencer par underscore
  if (username.startsWith('_')) {
    return false;
  }
  
  // Ne pas avoir plus de 2 underscores consécutifs
  if (username.includes('__')) {
    return false;
  }
  
  return true;
}

/**
 * Génère plusieurs suggestions de usernames
 * @param {string} fullname - Nom complet de l'utilisateur
 * @param {Array} existingUsernames - Liste des usernames existants
 * @param {number} count - Nombre de suggestions à générer
 * @returns {Array} Liste de suggestions de usernames
 */
function generateUsernameSuggestions(fullname, existingUsernames = [], count = 5) {
  const suggestions = [];
  const usedUsernames = new Set(existingUsernames.map(u => u.toLowerCase()));
  
  while (suggestions.length < count) {
    const username = generateUniqueUsername(fullname, Array.from(usedUsernames));
    
    if (!usedUsernames.has(username)) {
      suggestions.push(username);
      usedUsernames.add(username);
    }
  }
  
  return suggestions;
}

/**
 * Crée un username pour un nouvel utilisateur
 * @param {string} fullname - Nom complet de l'utilisateur
 * @param {Function} checkExists - Fonction pour vérifier si un username existe déjà
 * @returns {Promise<string>} Username unique
 */
async function createUsernameForUser(fullname, checkExists) {
  const suggestions = generateUsernameSuggestions(fullname, [], 10);
  
  // Tester chaque suggestion jusqu'à en trouver une qui n'existe pas
  for (const username of suggestions) {
    try {
      const exists = await checkExists(username);
      if (!exists) {
        return username;
      }
    } catch (error) {
      console.warn(`Error checking username existence for ${username}:`, error.message);
      continue;
    }
  }
  
  // Si aucune suggestion ne fonctionne, générer avec timestamp
  return generateUniqueUsername(fullname, []);
}

module.exports = {
  generateUniqueUsername,
  generateUsernameSuggestions,
  createUsernameForUser,
  isValidUsername,
  normalizeName,
  SYMBOLIC_SUFFIXES
};
