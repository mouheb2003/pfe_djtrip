const express = require("express");
const router = express.Router();
const postController = require("../controllers/post");
const { verifyToken, verifyTouriste, verifyAdmin } = require("../middleware/auth");
const upload = require("../middleware/upload");

// Public feed
router.get("/feed", postController.getFeedPosts);
router.get("/:postId/comments", verifyToken, postController.getPostComments);
router.post("/:postId/comments", verifyToken, postController.addPostComment);

// Tourist post management
router.get("/me", verifyToken, verifyTouriste, postController.getMyPosts);
router.post(
  "/upload-image",
  verifyToken,
  verifyTouriste,
  upload.single("image"),
  postController.uploadPostImage,
);
router.post("/", verifyToken, verifyTouriste, postController.createPost);
router.put(
  "/:postId",
  verifyToken,
  verifyTouriste,
  postController.updateMyPost,
);
router.delete(
  "/:postId",
  verifyToken,
  verifyTouriste,
  postController.deleteMyPost,
);

// Admin publication management
router.get("/admin", verifyToken, verifyAdmin, postController.getAdminPosts);
router.post("/admin", verifyToken, verifyAdmin, postController.createAdminPost);
router.put("/admin/:postId", verifyToken, verifyAdmin, postController.updatePostByAdmin);
router.delete("/admin/:postId", verifyToken, verifyAdmin, postController.deletePostByAdmin);

module.exports = router;
