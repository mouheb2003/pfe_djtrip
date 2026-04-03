const mongoose = require("mongoose");

const messageSchema = new mongoose.Schema(
  {
    sender_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    receiver_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    content: {
      type: String,
      trim: true,
      maxlength: 2000,
    },
    message_type: {
      type: String,
      enum: ["text", "image", "audio", "video"],
      default: "text",
    },
    media_url: {
      type: String,
      default: "",
    },
    media_duration: {
      type: Number,
      default: 0,
      min: 0,
    },
    is_read: {
      type: Boolean,
      default: false,
    },
    read_at: {
      type: Date,
      default: null,
    },
    is_edited: {
      type: Boolean,
      default: false,
    },
    edited_at: {
      type: Date,
      default: null,
    },
  },
  { timestamps: true },
);

messageSchema.index({ sender_id: 1, receiver_id: 1, createdAt: -1 });
messageSchema.index({ receiver_id: 1, is_read: 1 });

messageSchema.pre("validate", function () {
  const hasText = !!(this.content && this.content.trim());
  const hasMedia = !!(this.media_url && this.media_url.trim());
  if (!hasText && !hasMedia) {
    throw new Error("Message content or media is required");
  }
});

module.exports = mongoose.model("Message", messageSchema);
