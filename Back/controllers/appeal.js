const Appeal = require("../models/appeal");
const User = require("../models/user");
const emailService = require("../services/appealEmailService");

// ─── POST /appeals ───────────────────────────────────────────────────────────────
// Submit a new appeal
exports.submitAppeal = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { subject, message } = req.body;

    // Validation
    if (!subject || !message) {
      return res.status(400).json({
        message: "Subject and message are required",
      });
    }

    if (message.trim().length < 10) {
      return res.status(400).json({
        message: "Appeal message must be at least 10 characters long",
      });
    }

    // Get user info
    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    // Only allow appeals if user is suspended or banned
    if (user.accountStatus === "active") {
      return res.status(400).json({
        message: "Only suspended or banned users can submit appeals",
      });
    }

    // Create appeal
    const appeal = await Appeal.create({
      user_id: userId,
      subject,
      message: message.trim(),
      metadata: {
        user_account_status: user.accountStatus,
        original_ban_reason: user.banReason,
        original_suspension_reason: user.suspendReason,
        ip_address: req.ip,
        user_agent: req.get("User-Agent"),
      },
    });

    // Send email notifications
    try {
      // Send to admin
      await emailService.sendAdminAppealNotification({
        user,
        appeal,
        req,
      });

      // Send confirmation to user
      await emailService.sendUserAppealConfirmation({
        user,
        appeal,
      });
    } catch (emailError) {
      console.error("Failed to send appeal emails:", emailError);
      // Don't fail the request if email fails
    }

    res.status(201).json({
      message: "Appeal submitted successfully",
      appeal: {
        id: appeal._id,
        subject: appeal.subject,
        status: appeal.status,
        createdAt: appeal.createdAt,
      },
    });
  } catch (error) {
    console.error("Error submitting appeal:", error);
    res.status(500).json({
      message: "Error submitting appeal",
      error: error.message,
    });
  }
};

// ─── GET /appeals/me ───────────────────────────────────────────────────────────
// Get current user's appeals
exports.getUserAppeals = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { status, limit = 10 } = req.query;

    const appeals = await Appeal.findByUser(userId, {
      status,
      limit: parseInt(limit),
    });

    res.status(200).json({
      appeals,
      count: appeals.length,
    });
  } catch (error) {
    console.error("Error getting user appeals:", error);
    res.status(500).json({
      message: "Error retrieving appeals",
      error: error.message,
    });
  }
};

// ─── GET /admin/appeals ───────────────────────────────────────────────────────────
// Get all appeals (admin)
exports.getAllAppeals = async (req, res) => {
  try {
    const {
      status,
      search,
      limit = 20,
      skip = 0,
    } = req.query;

    const appeals = await Appeal.findAllAppeals({
      status,
      search,
      limit: parseInt(limit),
      skip: parseInt(skip),
    });

    // Get total count for pagination
    const totalQuery = {};
    if (status) totalQuery.status = status;
    const total = await Appeal.countDocuments(totalQuery);

    res.status(200).json({
      appeals,
      total,
      limit: parseInt(limit),
      skip: parseInt(skip),
      hasMore: parseInt(skip) + appeals.length < total,
    });
  } catch (error) {
    console.error("Error getting all appeals:", error);
    res.status(500).json({
      message: "Error retrieving appeals",
      error: error.message,
    });
  }
};

// ─── GET /admin/appeals/:id ─────────────────────────────────────────────────────
// Get specific appeal details (admin)
exports.getAppealDetails = async (req, res) => {
  try {
    const { id } = req.params;

    const appeal = await Appeal.findById(id)
      .populate("user_id", "fullname email accountStatus")
      .populate("admin_id", "fullname email");

    if (!appeal) {
      return res.status(404).json({ message: "Appeal not found" });
    }

    res.status(200).json({ appeal });
  } catch (error) {
    console.error("Error getting appeal details:", error);
    res.status(500).json({
      message: "Error retrieving appeal details",
      error: error.message,
    });
  }
};

// ─── PATCH /admin/appeals/:id ────────────────────────────────────────────────────
// Update appeal status (admin)
exports.updateAppealStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const adminId = req.user.userId;
    const { status, admin_response } = req.body;

    // Validate status
    const validStatuses = ["reviewed", "accepted", "rejected"];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({
        message: "Invalid status. Must be: reviewed, accepted, or rejected",
      });
    }

    const appeal = await Appeal.findById(id).populate("user_id");
    if (!appeal) {
      return res.status(404).json({ message: "Appeal not found" });
    }

    // Check if appeal can be updated
    if (!appeal.canBeUpdated()) {
      return res.status(400).json({
        message: "This appeal cannot be updated in its current status",
      });
    }

    // Update appeal
    await appeal.updateStatus(status, adminId, admin_response);

    // If accepted, update user status
    if (status === "accepted") {
      const user = appeal.user_id;
      
      if (user.accountStatus === "suspended") {
        user.accountStatus = "active";
        user.suspendedUntil = undefined;
        user.suspendReason = undefined;
        user.suspendedAt = undefined;
      } else if (user.accountStatus === "banned") {
        user.accountStatus = "active";
        user.banReason = undefined;
        user.bannedAt = undefined;
      }

      await user.save();
    }

    // Send email notification to user
    try {
      await emailService.sendAppealDecisionNotification({
        user: appeal.user_id,
        appeal,
        status,
        admin_response,
      });
    } catch (emailError) {
      console.error("Failed to send appeal decision email:", emailError);
    }

    res.status(200).json({
      message: "Appeal updated successfully",
      appeal: {
        id: appeal._id,
        status: appeal.status,
        admin_response: appeal.admin_response,
        updated_at: appeal.updatedAt,
      },
    });
  } catch (error) {
    console.error("Error updating appeal status:", error);
    res.status(500).json({
      message: "Error updating appeal status",
      error: error.message,
    });
  }
};

// ─── GET /admin/appeals/stats ─────────────────────────────────────────────────────
// Get appeal statistics (admin)
exports.getAppealStats = async (req, res) => {
  try {
    const stats = await Promise.all([
      Appeal.countDocuments({ status: "pending" }),
      Appeal.countDocuments({ status: "reviewed" }),
      Appeal.countDocuments({ status: "accepted" }),
      Appeal.countDocuments({ status: "rejected" }),
      Appeal.countDocuments({ createdAt: { $gte: new Date(Date.now() - 24 * 60 * 60 * 1000) } }),
    ]);

    res.status(200).json({
      pending: stats[0],
      reviewed: stats[1],
      accepted: stats[2],
      rejected: stats[3],
      last24h: stats[4],
    });
  } catch (error) {
    console.error("Error getting appeal stats:", error);
    res.status(500).json({
      message: "Error retrieving appeal statistics",
      error: error.message,
    });
  }
};
