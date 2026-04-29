const mongoose = require("mongoose");

const followSchema = new mongoose.Schema(
  {
    follower_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: [true, "Follower is required"],
    },
    following_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: [true, "Following is required"],
    },
  },
  {
    timestamps: true,
  },
);

// Prevent duplicate follows
followSchema.index({ follower_id: 1, following_id: 1 }, { unique: true });

// Method to check if a user is following another
followSchema.statics.isFollowing = async function (followerId, followingId) {
  const follow = await this.findOne({
    follower_id: followerId,
    following_id: followingId,
  });
  return !!follow;
};

// Method to get followers count
followSchema.statics.getFollowersCount = async function (userId) {
  return this.countDocuments({ following_id: userId });
};

// Method to get following count
followSchema.statics.getFollowingCount = async function (userId) {
  return this.countDocuments({ follower_id: userId });
};

const Follow = mongoose.model("Follow", followSchema);

module.exports = Follow;
