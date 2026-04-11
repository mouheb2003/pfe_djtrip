const express = require("express");
const router = express.Router();
const commentController = require("../controllers/comment");
const validate = require("../middleware/validate");
const wrapRouter = require("../middleware/wrapRouter");
const { cacheGet, invalidateCache } = require("../middleware/cache");
const { verifyToken, verifyTouriste, verifyAdmin } = require("../middleware/auth");

// Validators
const commentSchema = {
  content: { type: "string", minLength: 1, maxLength: 1200, required: true },
  parentCommentId: { type: "string", optional: true },
};

const updateCommentSchema = {
  content: { type: "string", minLength: 1, maxLength: 1200, required: true },
};

const reactionSchema = {
  reactionType: {
    type: "string",
    enum: ["like", "love", "laugh", "wow", "sad", "angry"],
    required: true,
  },
};

// ==================== PUBLIC ENDPOINTS ====================

// Get comments for a post with pagination
router.get(
  "/posts/:postId/comments",
  cacheGet("comments:post", 30),
  commentController.getPostComments
);

// Get a single comment
router.get(
  "/comments/:commentId",
  cacheGet("comments:single", 30),
  commentController.getComment
);

// Get comment reactions
router.get(
  "/comments/:commentId/reactions",
  cacheGet("comments:reactions", 60),
  commentController.getCommentReactions
);

// ==================== AUTHENTICATED ENDPOINTS ====================

// Create a new comment (IMMEDIATE PUBLICATION)
router.post(
  "/posts/:postId/comments",
  verifyToken,
  validate(commentSchema),
  invalidateCache(["comments:post", "comments:single", "posts:feed", "posts:me"]),
  commentController.createComment
);

// React to a comment
router.post(
  "/comments/:commentId/react",
  verifyToken,
  validate(reactionSchema),
  invalidateCache(["comments:reactions", "comments:post"]),
  commentController.reactToComment
);

// Update comment (ONLY OWNER)
router.patch(
  "/comments/:commentId",
  verifyToken,
  verifyTouriste,
  validate(updateCommentSchema),
  invalidateCache(["comments:post", "comments:single"]),
  commentController.updateComment
);

// Delete comment (OWNER OR POST OWNER OR ADMIN)
router.delete(
  "/comments/:commentId",
  verifyToken,
  invalidateCache(["comments:post", "comments:single", "posts:feed", "posts:me"]),
  commentController.deleteComment
);

// ==================== ADMIN ENDPOINTS ====================

// Get all comments with filters (ADMIN)
router.get(
  "/admin/comments",
  verifyToken,
  verifyAdmin,
  commentController.getAdminComments
);

// Delete any comment (ADMIN)
router.delete(
  "/admin/comments/:commentId",
  verifyToken,
  verifyAdmin,
  invalidateCache(["comments:post", "comments:single", "posts:feed", "posts:me"]),
  commentController.adminDeleteComment
);

console.log('[COMMENT ROUTES] Loading comment routes...');
module.exports = wrapRouter(router);
console.log('[COMMENT ROUTES] Comment routes loaded successfully');
