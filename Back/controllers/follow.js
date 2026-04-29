const Follow = require("../models/follow");
const User = require("../models/user");
const notificationEventBus = require("../services/notificationEventBus");

// Follow a user
exports.followUser = async (req, res) => {
  try {
    const followerId = req.user.userId;
    const { followingId } = req.body;

    if (!followingId) {
      return res.status(400).json({ message: "followingId is required" });
    }

    // Check if already following
    const existingFollow = await Follow.findOne({
      follower_id: followerId,
      following_id: followingId,
    });

    if (existingFollow) {
      return res.status(400).json({ message: "Already following this user" });
    }

    // Create new follow (automatic, no approval needed)
    await Follow.create({
      follower_id: followerId,
      following_id: followingId,
    });

    // Get follower info for notification
    const follower = await User.findById(followerId).select('fullname avatar');
    
    // Emit follow notification to the followed user
    notificationEventBus.emit('follow.created', {
      recipientId: followingId,
      type: 'follow',
      title: 'New Follower',
      body: `${follower?.fullname || 'Someone'} started following you`,
      data: {
        followerId: followerId,
        followerName: follower?.fullname,
        followerAvatar: follower?.avatar,
      },
    });

    res.status(201).json({ message: "Followed successfully" });
  } catch (error) {
    console.error("Error following user:", error);
    res.status(500).json({
      message: "Error following user",
      error: error.message,
    });
  }
};

// Unfollow a user
exports.unfollowUser = async (req, res) => {
  try {
    const followerId = req.user.userId;
    const { followingId } = req.body;

    if (!followingId) {
      return res.status(400).json({ message: "followingId is required" });
    }

    const follow = await Follow.findOneAndDelete({
      follower_id: followerId,
      following_id: followingId,
    });

    if (!follow) {
      return res.status(404).json({ message: "Not following this user" });
    }

    res.status(200).json({ message: "Unfollowed successfully" });
  } catch (error) {
    console.error("Error unfollowing user:", error);
    res.status(500).json({
      message: "Error unfollowing user",
      error: error.message,
    });
  }
};

// Check if following a user
exports.checkFollowStatus = async (req, res) => {
  try {
    const followerId = req.user.userId;
    const { followingId } = req.params;

    if (!followingId) {
      return res.status(400).json({ message: "followingId is required" });
    }

    const isFollowing = await Follow.isFollowing(followerId, followingId);

    res.status(200).json({ isFollowing });
  } catch (error) {
    console.error("Error checking follow status:", error);
    res.status(500).json({
      message: "Error checking follow status",
      error: error.message,
    });
  }
};

// Get followers count
exports.getFollowersCount = async (req, res) => {
  try {
    const { userId } = req.params;

    if (!userId) {
      return res.status(400).json({ message: "userId is required" });
    }

    const count = await Follow.getFollowersCount(userId);

    res.status(200).json({ count });
  } catch (error) {
    console.error("Error getting followers count:", error);
    res.status(500).json({
      message: "Error getting followers count",
      error: error.message,
    });
  }
};

// Get following count
exports.getFollowingCount = async (req, res) => {
  try {
    const { userId } = req.params;

    if (!userId) {
      return res.status(400).json({ message: "userId is required" });
    }

    const count = await Follow.getFollowingCount(userId);

    res.status(200).json({ count });
  } catch (error) {
    console.error("Error getting following count:", error);
    res.status(500).json({
      message: "Error getting following count",
      error: error.message,
    });
  }
};
