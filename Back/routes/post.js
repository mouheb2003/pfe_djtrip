const express = require("express");
const router = express.Router();
const postController = require("../controllers/post");
const validate = require("../middleware/validate");
const wrapRouter = require("../middleware/wrapRouter");
const { cacheGet, invalidateCache } = require("../middleware/cache");
const {
  createPostSchema,
  commentSchema,
  updatePostSchema,
} = require("../validators/post");
const {
  verifyToken,
  verifyTouriste,
  verifyAdmin,
} = require("../middleware/auth");
const upload = require("../middleware/upload");

// Public feed
router.get("/feed", cacheGet("posts:feed", 60), postController.getFeedPosts);
router.get(
  "/:postId/comments",
  verifyToken,
  cacheGet("posts:comments", 60),
  postController.getPostComments,
);
router.post(
  "/:postId/comments",
  verifyToken,
  validate(commentSchema),
  invalidateCache(["posts:comments", "posts:feed", "posts:me"]),
  postController.addPostComment,
);
router.post(
  "/:postId/like",
  verifyToken,
  invalidateCache(["posts:feed", "posts:me"]),
  postController.togglePostLike,
);

// Comment reactions
router.post(
  "/:postId/comments/:commentId/react",
  verifyToken,
  invalidateCache(["posts:comments", "posts:feed"]),
  postController.reactToComment,
);
router.get(
  "/:postId/comments/:commentId/reactions",
  postController.getCommentReactions,
);

// Tourist post management
router.get(
  "/me",
  verifyToken,
  verifyTouriste,
  cacheGet("posts:me", 60),
  postController.getMyPosts,
);
router.post(
  "/upload-image",
  verifyToken,
  verifyTouriste,
  upload.single("image"),
  invalidateCache(["posts:feed", "posts:me"]),
  postController.uploadPostImage,
);
router.post(
  "/",
  verifyToken,
  verifyTouriste,
  validate(createPostSchema),
  invalidateCache(["posts:feed", "posts:me", "posts:comments"]),
  postController.createPost,
);
router.put(
  "/:postId",
  verifyToken,
  verifyTouriste,
  validate(updatePostSchema),
  invalidateCache(["posts:feed", "posts:me", "posts:comments"]),
  postController.updateMyPost,
);
router.delete(
  "/:postId",
  verifyToken,
  verifyTouriste,
  invalidateCache(["posts:feed", "posts:me", "posts:comments"]),
  postController.deleteMyPost,
);

// Admin publication management
router.get(
  "/admin",
  verifyToken,
  verifyAdmin,
  cacheGet("posts:admin", 60),
  postController.getAdminPosts,
);
router.post(
  "/admin",
  verifyToken,
  verifyAdmin,
  validate(createPostSchema),
  invalidateCache(["posts:feed", "posts:admin", "posts:me"]),
  postController.createAdminPost,
);
router.put(
  "/admin/:postId",
  verifyToken,
  verifyAdmin,
  validate(updatePostSchema),
  invalidateCache(["posts:feed", "posts:admin", "posts:me", "posts:comments"]),
  postController.updatePostByAdmin,
);
router.delete(
  "/admin/:postId",
  verifyToken,
  verifyAdmin,
  invalidateCache(["posts:feed", "posts:admin", "posts:me", "posts:comments"]),
  postController.deletePostByAdmin,
);

module.exports = wrapRouter(router);
