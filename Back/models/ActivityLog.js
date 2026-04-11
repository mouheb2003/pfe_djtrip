const mongoose = require("mongoose");

const activityLogSchema = new mongoose.Schema(
  {
    actorId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    actorName: {
      type: String,
      trim: true,
      required: true,
      maxlength: 120,
    },
    action: {
      type: String,
      trim: true,
      required: true,
      index: true,
    },
    targetType: {
      type: String,
      trim: true,
      required: true,
      index: true,
    },
    targetId: {
      type: mongoose.Schema.Types.ObjectId,
      required: true,
      index: true,
    },
    metadata: {
      type: mongoose.Schema.Types.Mixed,
      default: {},
    },
    description: {
      type: String,
      trim: true,
      required: true,
      maxlength: 2000,
    },
  },
  {
    timestamps: { createdAt: true, updatedAt: false },
    collection: "activity_logs",
  },
);

activityLogSchema.index({ createdAt: -1 });
activityLogSchema.index({ actorId: 1, createdAt: -1 });
activityLogSchema.index({ action: 1, targetType: 1, createdAt: -1 });

module.exports = mongoose.model("ActivityLog", activityLogSchema);
