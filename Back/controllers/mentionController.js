/**
 * Contrôleur pour la gestion des mentions dans les posts
 * Détection, validation, et gestion des mentions par @userId
 */

const User = require("../models/user");
const Post = require("../models/post");
const mongoose = require("mongoose");

/**
 * Extraire les IDs mentionnés d'un texte
 * @param {string} content - Le contenu du post
 * @returns {array} - Liste des IDs uniques mentionnés
 */
function extractMentions(content) {
  if (!content || typeof content !== 'string') {
    return [];
  }

  // Regex pour trouver les mentions @userId (24 caractères hexadécimaux)
  const mentionRegex = /@([a-fA-F0-9]{24})/gi;
  const mentions = [];
  let match;

  while ((match = mentionRegex.exec(content)) !== null) {
    const userId = match[1];
    if (!mentions.includes(userId)) {
      mentions.push(userId);
    }
  }

  return mentions;
}

/**
 * Valider un UserId
 * @param {string} id - L'ID à valider
 * @returns {boolean} - True si valide
 */
function isValidUserId(id) {
  return mongoose.Types.ObjectId.isValid(id);
}

/**
 * Rechercher des utilisateurs par IDs
 * @param {array} ids - Liste des IDs à rechercher
 * @returns {array} - Liste des utilisateurs trouvés
 */
async function findUsersByIds(ids) {
  if (!ids || ids.length === 0) {
    return [];
  }

  try {
    const users = await User.find({
      _id: { $in: ids },
      accountStatus: 'active'
    })
    .select('fullname avatar _id userType')
    .lean()
    .exec();

    return users;
  } catch (error) {
    console.error('[MENTION] Error finding users by IDs:', error);
    throw error;
  }
}

/**
 * Sauvegarder les mentions dans un post
 * @param {string} postId - ID du post
 * @param {array} mentions - Liste des mentions à sauvegarder
 */
async function saveMentionsToPost(postId, mentions) {
  if (!postId || !mentions) {
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
 * Rechercher des utilisateurs pour l'autocomplétion des mentions par nom
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

    // Nettoyer le query
    const cleanQuery = query.trim().replace(/^@/, '');
    
    // Rechercher les utilisateurs par fullname uniquement (plus de username)
    const users = await User.find({
      fullname: { $regex: cleanQuery, $options: 'i' },
      accountStatus: 'active'
    })
    .select('fullname avatar userType _id')
    .limit(parseInt(limit))
    .lean()
    .exec();

    res.status(200).json({
      success: true,
      data: users.map(user => ({
        fullname: user.fullname,
        avatar: user.avatar,
        userType: user.userType,
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
 * Valider et extraire les mentions d'un contenu (par ID)
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

    // Extraire les mentions d'IDs
    const mentionIds = extractMentions(content);

    // Valider chaque ID
    const validIds = [];
    const invalidIds = [];

    for (const id of mentionIds) {
      if (isValidUserId(id)) {
        validIds.push(id);
      } else {
        invalidIds.push(id);
      }
    }

    // Vérifier si les utilisateurs existent
    let existingUsers = [];
    if (validIds.length > 0) {
      existingUsers = await findUsersByIds(validIds);
    }

    res.status(200).json({
      success: true,
      data: {
        content: content,
        mentions: {
          all: mentionIds,
          valid: validIds,
          invalid: invalidIds,
          existing: existingUsers.map(u => u._id.toString())
        },
        users: existingUsers.map(user => ({
          fullname: user.fullname,
          avatar: user.avatar,
          userType: user.userType,
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

// Exporter les fonctions utilitaires
module.exports.extractMentions = extractMentions;
module.exports.isValidUserId = isValidUserId;
module.exports.findUsersByIds = findUsersByIds;
module.exports.saveMentionsToPost = saveMentionsToPost;
