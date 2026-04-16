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
  verifyOrganisator,
  verifyTouristeOrOrganisator,
  verifyAdmin,
} = require("../middleware/auth");
const upload = require("../middleware/upload");

// Public feed (authenticated to show like status)
router.get("/feed", verifyToken, cacheGet("posts:feed", 60), postController.getFeedPosts);
router.post(
  "/:postId/like",
  verifyToken,
  invalidateCache(["posts:feed", "posts:me"]),
  postController.togglePostLike,
);

// Tourist and Organizer post management
router.get(
  "/me",
  verifyToken,
  verifyTouristeOrOrganisator,
  cacheGet("posts:me", 60),
  postController.getMyPosts,
);
router.post(
  "/upload-image",
  verifyToken,
  verifyTouristeOrOrganisator,
  upload.single("image"),
  invalidateCache(["posts:feed", "posts:me"]),
  postController.uploadPostImage,
);
router.post(
  "/",
  verifyToken,
  verifyTouristeOrOrganisator,
  validate(createPostSchema),
  invalidateCache(["posts:feed", "posts:me", "posts:comments"]),
  postController.createPost,
);
router.put(
  "/:postId",
  verifyToken,
  verifyTouristeOrOrganisator,
  validate(updatePostSchema),
  invalidateCache(["posts:feed", "posts:me", "posts:comments"]),
  postController.updateMyPost,
);
router.delete(
  "/:postId",
  verifyToken,
  verifyTouristeOrOrganisator,
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
