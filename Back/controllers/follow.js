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

// Get followers count and list
exports.getFollowersCount = async (req, res) => {
  try {
    const { userId } = req.params;

    if (!userId) {
      return res.status(400).json({ message: "userId is required" });
    }

    // Fetch the follows and populate the follower_id with user details
    const follows = await Follow.find({ following_id: userId })
      .populate("follower_id", "nom prenom username photo_profil profileImage userType")
      .exec();

    // Map to an array of just the users, filtering out any nulls if a user was deleted
    const followers = follows.map(f => f.follower_id).filter(f => f != null);

    res.status(200).json({ 
      count: followers.length,
      followers: followers
    });
  } catch (error) {
    console.error("Error getting followers:", error);
    res.status(500).json({
      message: "Error getting followers",
      error: error.message,
    });
  }
};

// Get following count and list
exports.getFollowingCount = async (req, res) => {
  try {
    const { userId } = req.params;

    if (!userId) {
      return res.status(400).json({ message: "userId is required" });
    }

    // Fetch the follows and populate the following_id with user details
    const follows = await Follow.find({ follower_id: userId })
      .populate("following_id", "nom prenom username photo_profil profileImage userType")
      .exec();

    // Map to an array of just the users, filtering out any nulls if a user was deleted
    const following = follows.map(f => f.following_id).filter(f => f != null);

    res.status(200).json({ 
      count: following.length,
      following: following
    });
  } catch (error) {
    console.error("Error getting following:", error);
    res.status(500).json({
      message: "Error getting following",
      error: error.message,
    });
  }
};
