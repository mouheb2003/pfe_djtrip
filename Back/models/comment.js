const mongoose = require("mongoose");

const reactionSchema = new mongoose.Schema(
  {
    user_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    type: {
      type: String,
      enum: ["like", "love", "laugh", "wow", "sad", "angry"],
      required: true,
    },
    created_at: {
      type: Date,
      default: Date.now,
    },
  },
  { _id: false }
);

const commentSchema = new mongoose.Schema(
  {
    post_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Post",
      required: true,
      index: true,
    },
    user_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    content: {
      type: String,
      trim: true,
      maxlength: 1200,
      required: true,
    },
    parent_comment_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Comment",
      default: null,
      index: true,
    },
    depth: {
      type: Number,
      default: 0,
      min: 0,
      max: 3,
    },
    replies_count: {
      type: Number,
      default: 0,
      min: 0,
    },
    mentions: {
      type: [mongoose.Schema.Types.ObjectId],
      ref: "User",
      default: [],
    },
    reactions: {
      type: [reactionSchema],
      default: [],
    },
    total_reactions: {
      type: Number,
      default: 0,
      min: 0,
    },
    is_active: {
      type: Boolean,
      default: true,
      index: true,
    },
  },
  {
    timestamps: { createdAt: "created_at", updatedAt: "updated_at" },
    collection: "comments",
  }
);

// Indexes for performance
commentSchema.index({ post_id: 1, created_at: -1 });
commentSchema.index({ user_id: 1, created_at: -1 });
commentSchema.index({ parent_comment_id: 1, created_at: -1 });
commentSchema.index({ is_active: 1, created_at: -1 });
commentSchema.index({ mentions: 1 });

// Instance method to check if user can edit comment
commentSchema.methods.canEdit = function (userId) {
  return String(this.user_id) === String(userId);
};

// Instance method to check if user can delete comment
commentSchema.methods.canDelete = function (userId, isPostOwner, isAdmin) {
  if (isAdmin) return true;
  if (String(this.user_id) === String(userId)) return true;
  if (isPostOwner) return true;
  return false;
};

// Static method to get comment count for a post
commentSchema.statics.getCommentCount = async function (postId) {
  return this.countDocuments({ post_id: postId, is_active: true });
};

// Static method to get all comments for a post with pagination
commentSchema.statics.getPostCommentsPaginated = async function (
  postId,
  options = {}
) {
  const page = parseInt(options.page) || 1;
  const limit = parseInt(options.limit) || 20; // Default to 20 comments per page
  const skip = (page - 1) * limit;

  // Fetch ONLY root comments (parent_comment_id: null)
  const comments = await this.find({ post_id: postId, parent_comment_id: null, is_active: true })
    .populate("user_id", "fullname avatar userType")
    .sort({ created_at: -1 })
    .skip(skip)
    .limit(limit)
    .lean();

  // Count only root comments for pagination
  const total = await this.countDocuments({ post_id: postId, parent_comment_id: null, is_active: true });

  return {
    comments,
    pagination: {
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit),
      hasNext: page < Math.ceil(total / limit),
      hasPrev: page > 1,
    },
  };
};

// Static method to get replies for a specific comment with pagination
commentSchema.statics.getCommentRepliesPaginated = async function (
  parentCommentId,
  options = {}
) {
  const page = parseInt(options.page) || 1;
  const limit = parseInt(options.limit) || 5; // Default to 5 replies per page
  const skip = (page - 1) * limit;

  const replies = await this.find({ parent_comment_id: parentCommentId, is_active: true })
    .populate("user_id", "fullname avatar userType")
    .sort({ created_at: 1 }) // Sort by oldest first for replies
    .skip(skip)
    .limit(limit)
    .lean();

  const total = await this.countDocuments({ parent_comment_id: parentCommentId, is_active: true });

  return {
    replies,
    pagination: {
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit),
      hasNext: page < Math.ceil(total / limit),
      hasPrev: page > 1,
    },
  };
};

module.exports = mongoose.model("Comment", commentSchema);
