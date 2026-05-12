/**
 * Contrôleur pour la gestion des mentions dans les posts
 * Détection, validation, et gestion des mentions @username
 */

const User = require("../models/user");
const Post = require("../models/post");

/**
 * Extraire les usernames mentionnés d'un texte
 * @param {string} content - Le contenu du post
 * @returns {array} - Liste des usernames uniques mentionnés
 */
function extractMentions(content) {
  if (!content || typeof content !== 'string') {
    return [];
  }

  // Regex pour trouver les mentions @username
  const mentionRegex = /@([a-zA-Z0-9_]{3,30})/gi;
  const mentions = [];
  let match;

  while ((match = mentionRegex.exec(content)) !== null) {
    const username = match[1].toLowerCase();
    if (!mentions.includes(username)) {
      mentions.push(username);
    }
  }

  return mentions;
}

/**
 * Valider un username
 * @param {string} username - Le username à valider
 * @returns {boolean} - True si valide
 */
function isValidUsername(username) {
  if (!username || typeof username !== 'string') {
    return false;
  }
  
  // Doit avoir entre 3 et 30 caractères
  if (username.length < 3 || username.length > 30) {
    return false;
  }
  
  // Uniquement lettres, chiffres, et underscores
  return /^[a-zA-Z0-9_]+$/.test(username);
}

/**
 * Rechercher des utilisateurs par usernames
 * @param {array} usernames - Liste des usernames à rechercher
 * @returns {array} - Liste des utilisateurs trouvés
 */
async function findUsersByUsernames(usernames) {
  if (!usernames || usernames.length === 0) {
    return [];
  }

  try {
    const users = await User.find({
      username: { $in: usernames },
      accountStatus: 'active'
    })
    .select('username fullname avatar _id')
    .lean()
    .exec();

    return users;
  } catch (error) {
    console.error('[MENTION] Error finding users by usernames:', error);
    throw error;
  }
}

/**
 * Sauvegarder les mentions dans un post
 * @param {string} postId - ID du post
 * @param {array} mentions - Liste des mentions à sauvegarder
 */
async function saveMentionsToPost(postId, mentions) {
  if (!postId || mentions.length === 0) {
    return;
  }

  try {
    const post = await Post.findById(postId);
    if (!post) {
      throw new Error('Post not found');
    }

    // Ajouter les mentions au post
    post.mentions = mentions;
    post.updatedAt = new Date();
    await post.save();

    console.log(`[MENTION] Saved ${mentions.length} mentions to post ${postId}`);
  } catch (error) {
    console.error('[MENTION] Error saving mentions to post:', error);
    throw error;
  }
}

/**
 * GET /api/mentions/search
 * Rechercher des utilisateurs pour l'autocomplétion des mentions
 */
exports.searchMentions = async (req, res) => {
  try {
    const { query, limit = 10 } = req.query;

    if (!query || query.trim().length < 1) {
      return res.status(400).json({
        success: false,
        message: 'Query parameter is required'
      });
    }

    // Nettoyer le query et enlever le @ s'il est présent
    const cleanQuery = query.trim().replace(/^@/, '');
    
    // Rechercher les utilisateurs par regex (recherche partielle)
    const users = await User.find({
      username: { $regex: cleanQuery, $options: 'i' },
      accountStatus: 'active'
    })
    .select('username fullname avatar _id')
    .limit(parseInt(limit))
    .lean()
    .exec();

    res.status(200).json({
      success: true,
      data: users.map(user => ({
        username: user.username,
        fullname: user.fullname,
        avatar: user.avatar,
        _id: user._id
      })),
      count: users.length
    });

  } catch (error) {
    console.error('[MENTION] Error in searchMentions:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

/**
 * POST /api/mentions/validate
 * Valider et extraire les mentions d'un contenu
 */
exports.validateMentions = async (req, res) => {
  try {
    const { content } = req.body;

    if (!content) {
      return res.status(400).json({
        success: false,
        message: 'Content parameter is required'
      });
    }

    // Extraire les mentions
    const mentions = extractMentions(content);

    // Valider chaque mention
    const validMentions = [];
    const invalidMentions = [];

    for (const username of mentions) {
      if (isValidUsername(username)) {
        validMentions.push(username);
      } else {
        invalidMentions.push(username);
      }
    }

    // Vérifier si les usernames existent
    let existingUsers = [];
    if (validMentions.length > 0) {
      existingUsers = await findUsersByUsernames(validMentions);
    }

    res.status(200).json({
      success: true,
      data: {
        content: content,
        mentions: {
          all: mentions,
          valid: validMentions,
          invalid: invalidMentions,
          existing: existingUsers.map(u => u.username)
        },
        users: existingUsers.map(user => ({
          username: user.username,
          fullname: user.fullname,
          avatar: user.avatar,
          _id: user._id
        }))
      }
    });

  } catch (error) {
    console.error('[MENTION] Error in validateMentions:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

/**
 * POST /api/mentions/save/:postId
 * Sauvegarder les mentions dans un post
 */
exports.saveMentions = async (req, res) => {
  try {
    const { postId } = req.params;
    const { mentions } = req.body;

    if (!postId) {
      return res.status(400).json({
        success: false,
        message: 'Post ID parameter is required'
      });
    }

    if (!Array.isArray(mentions)) {
      return res.status(400).json({
        success: false,
        message: 'Mentions must be an array'
      });
    }

    await saveMentionsToPost(postId, mentions);

    res.status(200).json({
      success: true,
      message: 'Mentions saved successfully',
      data: {
        postId,
        mentionsCount: mentions.length,
        mentions
      }
    });

  } catch (error) {
    console.error('[MENTION] Error in saveMentions:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

/**
 * GET /api/mentions/post/:postId
 * Récupérer les mentions d'un post
 */
exports.getPostMentions = async (req, res) => {
  try {
    const { postId } = req.params;

    if (!postId) {
      return res.status(400).json({
        success: false,
        message: 'Post ID parameter is required'
      });
    }

    const post = await Post.findById(postId)
      .select('mentions')
      .lean()
      .exec();

    if (!post) {
      return res.status(404).json({
        success: false,
        message: 'Post not found'
      });
    }

    res.status(200).json({
      success: true,
      data: {
        postId,
        mentions: post.mentions || []
      }
    });

  } catch (error) {
    console.error('[MENTION] Error in getPostMentions:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

// Exporter les fonctions utilitaires pour utilisation dans d'autres contrôleurs
module.exports.extractMentions = extractMentions;
module.exports.isValidUsername = isValidUsername;
module.exports.findUsersByUsernames = findUsersByUsernames;
module.exports.saveMentionsToPost = saveMentionsToPost;
