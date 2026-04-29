const express = require("express");
const router = express.Router();
const followController = require("../controllers/follow");
const { verifyToken } = require("../middleware/auth");

// POST /follow - Follow a user
router.post("/", verifyToken, followController.followUser);

// DELETE /follow - Unfollow a user
router.delete("/", verifyToken, followController.unfollowUser);

// GET /follow/check/:followingId - Check if following a user
router.get("/check/:followingId", verifyToken, followController.checkFollowStatus);

// GET /follow/followers/:userId - Get followers count
router.get("/followers/:userId", followController.getFollowersCount);

// GET /follow/following/:userId - Get following count
router.get("/following/:userId", followController.getFollowingCount);

module.exports = router;
