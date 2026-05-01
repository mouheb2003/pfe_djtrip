console.log('[COMMENT ROUTES] Loading comment routes...');

const express = require("express");
const router = express.Router();
const commentController = require("../controllers/comment");
console.log('[COMMENT ROUTES] Comment controller loaded');
const validate = require("../middleware/validate");
const wrapRouter = require("../middleware/wrapRouter");
const { cacheGet, invalidateCache } = require("../middleware/cache");
const { verifyToken, verifyTouriste, verifyTouristeOrOrganisator, verifyAdmin } = require("../middleware/auth");
const { createCommentSchema, updateCommentSchema, reactionSchema } = require("../validators/comment");

// ==================== ADMIN ENDPOINTS (MUST BE FIRST TO AVOID CONFLICTS) ====================

// Test endpoint
router.get("/test", (req, res) => {
  console.log('[TEST ENDPOINT] Called');
  res.json({ message: "Test endpoint works" });
});

// ==================== PUBLIC ENDPOINTS ====================

// Search users for mention autocomplete
router.get(
  "/users/search",
  verifyToken,
  commentController.searchUsersForMention
);

// ==================== ADMIN ENDPOINTS ====================

// Get all comments with filters (ADMIN)
router.get(
  "/admin",
  verifyToken,
  verifyAdmin,
  commentController.getAdminComments
);

// Delete any comment (ADMIN)
router.delete(
  "/admin/:commentId",
  verifyToken,
  verifyAdmin,
  invalidateCache(["comments:post", "comments:single", "posts:feed", "posts:me"]),
  commentController.adminDeleteComment
);

// Get comments for a post with pagination
router.get(
  "/:postId/comments",
  verifyToken,
  commentController.getPostComments
);

// Get a single comment
router.get(
  "/:commentId",
  verifyToken,
  commentController.getComment
);

// Get comment reactions
router.get(
  "/:commentId/reactions",
  verifyToken,
  commentController.getCommentReactions
);

// Get replies for a specific comment with pagination (Facebook/Instagram style)
router.get(
  "/:commentId/replies",
  verifyToken,
  commentController.getCommentReplies
);

// ==================== AUTHENTICATED ENDPOINTS ====================

// Create a new comment (IMMEDIATE PUBLICATION)
router.post(
  "/:postId/comments",
  verifyToken,
  validate(createCommentSchema),
  invalidateCache(["comments:post", "comments:single", "posts:feed", "posts:me"]),
  commentController.createComment
);

// React to a comment
router.post(
  "/:commentId/react",
  verifyToken,
  validate(reactionSchema),
  invalidateCache(["comments:reactions", "comments:post"]),
  commentController.reactToComment
);

// Update comment (ONLY OWNER)
router.patch(
  "/:commentId",
  verifyToken,
  verifyTouristeOrOrganisator,
  validate(updateCommentSchema),
  invalidateCache(["comments:post", "comments:single"]),
  commentController.updateComment
);

// Delete comment (OWNER OR POST OWNER OR ADMIN)
router.delete(
  "/:commentId",
  verifyToken,
  invalidateCache(["comments:post", "comments:single", "posts:feed", "posts:me"]),
  commentController.deleteComment
);

console.log('[COMMENT ROUTES] All routes defined, wrapping router...');
module.exports = wrapRouter(router);
console.log('[COMMENT ROUTES] Comment routes loaded successfully');
