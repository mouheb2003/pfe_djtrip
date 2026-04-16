/**
 * Mention Parser Utility
 * Extracts @mentions from comment content and validates them against user database
 */

const User = require("../models/user");

/**
 * Parse mentions from content
 * @param {string} content - Comment content
 * @returns {Object} - { mentions: string[], cleanContent: string }
 */
function parseMentions(content) {
  const mentionRegex = /@([a-zA-Z0-9_.-]+)/g;
  const mentions = [];
  let match;
  
  while ((match = mentionRegex.exec(content)) !== null) {
    mentions.push(match[1]);
  }
  
  // Remove duplicates
  const uniqueMentions = [...new Set(mentions)];
  
  return {
    mentions: uniqueMentions,
    cleanContent: content, // Keep original content with @ symbols
  };
}

/**
 * Validate mentions against user database
 * @param {string[]} usernames - Array of usernames
 * @returns {Promise<Object>} - { validUserIds: string[], invalidUsernames: string[] }
 */
async function validateMentions(usernames) {
  const validUserIds = [];
  const invalidUsernames = [];
  
  if (usernames.length === 0) {
    return { validUserIds, invalidUsernames };
  }
  
  try {
    // Find users by username (case-insensitive)
    const users = await User.find({
      username: { $in: usernames.map(u => new RegExp(`^${u}$`, 'i')) },
      is_active: true,
    }).select("_id username");
    
    const validUsernamesMap = new Map(
      users.map(user => [user.username.toLowerCase(), user._id.toString()])
    );
    
    for (const username of usernames) {
      const userId = validUsernamesMap.get(username.toLowerCase());
      if (userId) {
        validUserIds.push(userId);
      } else {
        invalidUsernames.push(username);
      }
    }
  } catch (error) {
    console.error("Error validating mentions:", error);
    // On error, return empty arrays to avoid blocking comment creation
  }
  
  return { validUserIds, invalidUsernames };
}

/**
 * Extract and validate mentions from content
 * @param {string} content - Comment content
 * @returns {Promise<Object>} - { validUserIds: string[], cleanContent: string }
 */
async function extractAndValidateMentions(content) {
  const { mentions } = parseMentions(content);
  const { validUserIds } = await validateMentions(mentions);
  
  return {
    validUserIds,
    cleanContent: content,
  };
}

/**
 * Calculate comment depth based on parent comment
 * @param {string} parentCommentId - Parent comment ID
 * @param {number} maxDepth - Maximum allowed depth (default: 3)
 * @returns {Promise<number>} - Depth level (0 for root comments)
 */
async function calculateDepth(parentCommentId, maxDepth = 3) {
  if (!parentCommentId) {
    return 0;
  }
  
  const Comment = require("../models/comment");
  
  try {
    const parentComment = await Comment.findById(parentCommentId).select("depth").lean();
    
    if (!parentComment) {
      throw new Error("Parent comment not found");
    }
    
    const newDepth = parentComment.depth + 1;
    
    if (newDepth > maxDepth) {
      throw new Error(`Maximum nesting depth (${maxDepth}) exceeded`);
    }
    
    return newDepth;
  } catch (error) {
    console.error("Error calculating depth:", error);
    throw error;
  }
}

module.exports = {
  parseMentions,
  validateMentions,
  extractAndValidateMentions,
  calculateDepth,
};
