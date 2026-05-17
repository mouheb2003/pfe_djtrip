const mongoose = require("mongoose");

const postReactionSchema = new mongoose.Schema(
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

const postSchema = new mongoose.Schema(
  {
    author_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    content: {
      type: String,
      trim: true,
      maxlength: 1500,
      default: "",
    },
    image_url: {
      type: String,
      trim: true,
      default: "",
    },
    image_urls: {
      type: [String],
      default: [],
    },
    post_type: {
      type: String,
      enum: ["post", "activity"],
      default: "post",
      index: true,
    },
    audience: {
      type: String,
      enum: ["public", "followers"],
      default: "public",
    },
    location_label: {
      type: String,
      trim: true,
      default: "",
    },
    trip_link: {
      type: String,
      trim: true,
      default: "",
    },
    hashtags: {
      type: [String],
      default: [],
    },
    mentions: {
      type: [String],
      default: [],
      index: true,
    },
    hidden_from_profiles: {
      type: [
        {
          type: mongoose.Schema.Types.ObjectId,
          ref: "User",
        },
      ],
      default: [],
      index: true,
    },
    created_at: {
      type: Date,
      default: Date.now,
    },
    updated_at: {
      type: Date,
      default: Date.now,
    },
    is_archived: {
      type: Boolean,
      default: false,
      index: true,
    },
    likes_count: {
      type: Number,
      default: 0,
      min: 0,
    },
    liked_by: {
      type: [
        {
          type: mongoose.Schema.Types.ObjectId,
          ref: "User",
          index: true,
        },
      ],
      default: [],
    },
    reactions: {
      type: [postReactionSchema],
      default: [],
    },
    total_reactions: {
      type: Number,
      default: 0,
      min: 0,
    },
    comments_count: {
      type: Number,
      default: 0,
      min: 0,
    },
    bookmarked_by: {
      type: [
        {
          type: mongoose.Schema.Types.ObjectId,
          ref: "User",
          index: true,
        },
      ],
      default: [],
    },
    bookmarks_count: {
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
    timestamps: true,
    collection: "posts",
  }
);

postSchema.index({ createdAt: -1 });
postSchema.index({ author_id: 1, createdAt: -1 });

// Instance method to get comments count from Comment collection
postSchema.methods.getCommentsCount = async function () {
  const Comment = mongoose.model("Comment");
  return Comment.countDocuments({ post_id: this._id, is_active: true });
};

module.exports = mongoose.model("Post", postSchema);
