const mongoose = require("mongoose");

const appealSchema = new mongoose.Schema(
  {
    // User who submitted the appeal
    user_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    // Appeal subject/category
    subject: {
      type: String,
      required: true,
      enum: ["Ban Appeal", "Suspension Appeal", "Other"],
    },
    // Appeal message content
    message: {
      type: String,
      required: true,
      maxlength: [2000, "Appeal message cannot exceed 2000 characters"],
      trim: true,
    },
    // Appeal status
    status: {
      type: String,
      enum: ["pending", "reviewed", "accepted", "rejected"],
      default: "pending",
      index: true,
    },
    // Admin response to the appeal
    admin_response: {
      type: String,
      maxlength: [1000, "Admin response cannot exceed 1000 characters"],
      default: null,
    },
    // Admin who responded
    admin_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null,
    },
    // Optional attachments
    attachments: [{
      type: String, // URLs to files
    }],
    // Appeal metadata
    metadata: {
      user_account_status: String, // User's status when appeal was submitted
      original_ban_reason: String,
      original_suspension_reason: String,
      ip_address: String,
      user_agent: String,
    },
  },
  {
    timestamps: true,
    collection: "appeals",
  },
);

// Indexes for performance
appealSchema.index({ user_id: 1, createdAt: -1 });
appealSchema.index({ status: 1, createdAt: -1 });
appealSchema.index({ createdAt: -1 });

// Virtual for formatted creation date
appealSchema.virtual("created_at").get(function () {
  return this.createdAt;
});

// Virtual for formatted update date
appealSchema.virtual("updated_at").get(function () {
  return this.updatedAt;
});

// Method to update appeal status
appealSchema.methods.updateStatus = function (status, adminId, response) {
  this.status = status;
  this.admin_id = adminId;
  if (response) {
    this.admin_response = response;
  }
  return this.save();
};

// Method to check if appeal can be updated
appealSchema.methods.canBeUpdated = function () {
  return this.status === "pending" || this.status === "reviewed";
};

// Static method to find appeals by user
appealSchema.statics.findByUser = function (userId, options = {}) {
  const query = { user_id: userId };
  
  if (options.status) {
    query.status = options.status;
  }
  
  return this.find(query)
    .populate("user_id", "fullname email")
    .populate("admin_id", "fullname email")
    .sort({ createdAt: -1 })
    .limit(options.limit || 50);
};

// Static method for admin dashboard
appealSchema.statics.findAllAppeals = function (options = {}) {
  const query = {};
  
  if (options.status) {
    query.status = options.status;
  }
  
  if (options.search) {
    query.$or = [
      { "user_id.fullname": { $regex: options.search, $options: "i" } },
      { "user_id.email": { $regex: options.search, $options: "i" } },
      { subject: { $regex: options.search, $options: "i" } },
      { message: { $regex: options.search, $options: "i" } },
    ];
  }
  
  return this.find(query)
    .populate("user_id", "fullname email accountStatus")
    .populate("admin_id", "fullname email")
    .sort({ createdAt: -1 })
    .limit(options.limit || 20)
    .skip(options.skip || 0);
};

const Appeal = mongoose.model("Appeal", appealSchema);

module.exports = Appeal;
