const mongoose = require("mongoose");

const postCommentSchema = new mongoose.Schema(
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
      maxlength: 1200,
      required: true,
    },
    parent_comment_id: {
      type: mongoose.Schema.Types.ObjectId,
      default: null,
      index: true,
    },
    is_active: {
      type: Boolean,
      default: true,
      index: true,
    },
  },
  {
    timestamps: true,
    _id: true,
  },
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
    comments_count: {
      type: Number,
      default: 0,
      min: 0,
    },
    comments: {
      type: [postCommentSchema],
      default: [],
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
  },
);

postSchema.index({ createdAt: -1 });
postSchema.index({ author_id: 1, createdAt: -1 });

module.exports = mongoose.model("Post", postSchema);
