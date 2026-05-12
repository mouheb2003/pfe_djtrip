const Appeal = require("../models/appeal");
const User = require("../models/user");
const emailService = require("../services/appealEmailService");
const notificationEventBus = require("../services/notificationEventBus");
const Notification = require("../models/notification");

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

    // Allow appeals if user is suspended/banned, OR if it's a general reclamation (subject contains 'reclamation')
    const isReclamation = subject.toLowerCase().includes('réclamation') || subject.toLowerCase().includes('reclamation');
    
    if (user.accountStatus === "active" && !isReclamation) {
      return res.status(400).json({
        message: "Only suspended or banned users can submit appeals, or use 'Réclamation' as subject for feedback.",
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

    // Emit event for other listeners
    try {
      notificationEventBus.emitAppealCreated({
        userId: userId,
        appealId: appeal._id,
        userFullName: user.fullname || user.email || `${user.firstName || ''} ${user.lastName || ''}`,
        subject: appeal.subject,
      });
    } catch (emitErr) {
      console.error('[APPEAL] Failed to emit appeal.created:', emitErr);
    }

    // Create admin notifications using Notification.createNotification to ensure DB write + push attempt
    try {
      const admins = await User.find({ userType: { $regex: /^admin$/i } }).select('_id email').lean();
      if (admins && admins.length > 0) {
        const senderName = user.fullname || user.email || 'Someone';
        const subjectText = appeal.subject || 'Appeal';
        await Promise.all(admins.map(async (admin) => {
          try {
            await Notification.createNotification({
              user_id: admin._id,
              type: 'appeal',
              title: `New Appeal from ${senderName}`,
              message: `${senderName} submitted "${subjectText}"`,
              data: { appealId: appeal._id, userId },
              priority: 'high',
              related_entity_type: 'appeal',
              related_entity_id: appeal._id,
            });
          } catch (err) {
            console.error('Error creating admin notification for', admin._id, err);
          }
        }));
        console.log('[APPEAL] Admin notifications created in DB for appeal:', appeal._id);
      }
    } catch (adminNotifErr) {
      console.error('[APPEAL] Failed to create admin DB notifications:', adminNotifErr);
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
      page = 1,
    } = req.query;

    const skip = (parseInt(page) - 1) * parseInt(limit);

    const appeals = await Appeal.findAllAppeals({
      status,
      search,
      limit: parseInt(limit),
      skip: skip,
    });

    // Make account status "live": always reflect the user's current accountStatus
    // and push appeals to bottom if the account is already active before treatment.
    const untreatedStatuses = new Set(["pending", "reviewed"]);
    const normalizeAppeal = (appealDoc) => {
      const appeal = typeof appealDoc?.toObject === "function" ? appealDoc.toObject() : appealDoc;
      const currentUserStatus = appeal?.user_id?.accountStatus ?? null;
      return {
        ...appeal,
        current_user_account_status: currentUserStatus,
      };
    };

    const normalizedAppeals = (Array.isArray(appeals) ? appeals : []).map(normalizeAppeal);

    normalizedAppeals.sort((a, b) => {
      const aUntreated = untreatedStatuses.has(a?.status);
      const bUntreated = untreatedStatuses.has(b?.status);

      const aReactivatedBeforeTreatment = aUntreated && a?.current_user_account_status === "active";
      const bReactivatedBeforeTreatment = bUntreated && b?.current_user_account_status === "active";

      if (aReactivatedBeforeTreatment !== bReactivatedBeforeTreatment) {
        return aReactivatedBeforeTreatment ? 1 : -1; // reactivated ones go last
      }

      // Keep newest first within the same bucket
      const aTime = new Date(a?.createdAt ?? a?.created_at ?? 0).getTime();
      const bTime = new Date(b?.createdAt ?? b?.created_at ?? 0).getTime();
      return bTime - aTime;
    });

    // Get total count for pagination
    const totalQuery = {};
    if (status) totalQuery.status = status;
    const total = await Appeal.countDocuments(totalQuery);

    res.status(200).json({
      success: true,
      appeals: normalizedAppeals,
      total,
      pagination: {
        current_page: parseInt(page),
        total_pages: Math.ceil(total / parseInt(limit)),
        total_items: total,
      },
      limit: parseInt(limit),
      page: parseInt(page),
      hasMore: skip + appeals.length < total,
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

      console.log('[APPEAL] Accepting appeal for user:', user._id, 'current status:', user.accountStatus);

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

      console.log('[APPEAL] User status updated to active for user:', user._id);
    } else if (status === "rejected") {
      const user = appeal.user_id;
      console.log('[APPEAL] Rejecting appeal for user:', user._id, 'account status remains:', user.accountStatus);
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

    // Emit appeal resolved event for notification
    try {
      notificationEventBus.emitAppealResolved({
        userId: appeal.user_id._id,
        appealId: appeal._id,
        status: status,
      });
      console.log('[APPEAL] appeal.resolved event emitted for appealId:', appeal._id, 'status:', status);
    } catch (notifError) {
      console.warn('Failed to send appeal resolved notification:', notifError.message);
    }

    res.status(200).json({
      message: "Appeal status updated successfully",
      appeal,
    });
  } catch (error) {
    console.error("Error updating appeal status:", error);
    res.status(500).json({
      message: "Error updating appeal status",
      error: error.message,
    });
  }
};

// ─── DELETE /admin/appeals/:id ────────────────────────────────────────────────────
// Delete an appeal (admin)
exports.deleteAppeal = async (req, res) => {
  try {
    const { id } = req.params;

    const appeal = await Appeal.findById(id);
    if (!appeal) {
      return res.status(404).json({ message: "Appeal not found" });
    }

    // Delete the appeal
    await Appeal.findByIdAndDelete(id);

    res.status(200).json({
      message: "Appeal deleted successfully",
      appeal_id: id,
    });
  } catch (error) {
    console.error("Error deleting appeal:", error);
    res.status(500).json({
      message: "Error deleting appeal",
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

// POST /appeals/anonymous - Submit appeal without authentication
exports.submitAnonymousAppeal = async (req, res) => {
  try {
    const { email, subject, message } = req.body;

    // Validation
    if (!email || !subject || !message) {
      return res.status(400).json({
        message: "Email, subject, and message are required",
      });
    }

    if (message.trim().length < 10) {
      return res.status(400).json({
        message: "Appeal message must be at least 10 characters long",
      });
    }

    // Find user by email
    const user = await User.findOne({ email: email.toLowerCase().trim() });
    if (!user) {
      return res.status(404).json({ 
        message: "No account found with this email address",
        suggestion: "Please check your email or create an account first"
      });
    }

    // Create appeal
    const appeal = await Appeal.create({
      user_id: user._id,
      subject,
      message: message.trim(),
      metadata: {
        user_account_status: user.accountStatus,
        original_ban_reason: user.banReason,
        original_suspension_reason: user.suspendReason,
        ip_address: req.ip,
        user_agent: req.get("User-Agent"),
        submission_type: "anonymous",
      },
    });
    console.log('[APPEAL-ANON] Appeal created:', appeal._id);

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

    // Emit event for other listeners
    try {
      notificationEventBus.emitAppealCreated({
        userId: user._id,
        appealId: appeal._id,
        userFullName: user.fullname || user.email || `${user.firstName || ''} ${user.lastName || ''}`,
        subject: appeal.subject,
      });
      console.log('[APPEAL-ANON] Event emitted successfully for appeal:', appeal._id);
    } catch (emitErr) {
      console.error('[APPEAL-ANON] Failed to emit appeal.created:', emitErr);
    }

    // Create admin notifications using Notification.createNotification to ensure DB write + push attempt
    console.log('[APPEAL-ANON] Starting admin notification creation for appeal:', appeal._id, 'user:', user._id);
    try {
      console.log('[APPEAL-ANON] Querying admins with regex...');
      const admins = await User.find({ userType: { $regex: /^admin$/i } }).select('_id email').lean();
      console.log('[APPEAL-ANON] Found', admins.length, 'admins');
      
      if (admins && admins.length > 0) {
        const senderName = user.fullname || user.email || 'Someone';
        const subjectText = appeal.subject || 'Appeal';
        console.log('[APPEAL-ANON] Creating notifications for', admins.length, 'admins');
        console.log('[APPEAL-ANON] Sender:', senderName, 'Subject:', subjectText);
        
        const results = await Promise.all(admins.map(async (admin) => {
          try {
            console.log('[APPEAL-ANON] Creating notification for admin:', admin._id);
            const notif = await Notification.createNotification({
              user_id: admin._id,
              type: 'appeal',
              title: `New Appeal from ${senderName}`,
              message: `${senderName} submitted "${subjectText}"`,
              data: { appealId: appeal._id, userId: user._id },
              priority: 'high',
              related_entity_type: 'appeal',
              related_entity_id: appeal._id,
            });
            console.log('[APPEAL-ANON] Notification created successfully:', notif._id);
            return notif;
          } catch (err) {
            console.error('[APPEAL-ANON] Error creating admin notification for', admin._id, ':', err.message);
            throw err;
          }
        }));
        console.log('[APPEAL-ANON] All admin notifications created:', results.length);
      } else {
        console.warn('[APPEAL-ANON] No admins found to notify for appeal:', appeal._id);
      }
    } catch (adminNotifErr) {
      console.error('[APPEAL-ANON] Failed to create admin DB notifications:', adminNotifErr.message);
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
    console.error("Error submitting anonymous appeal:", error);
    res.status(500).json({
      message: "Error submitting appeal",
      error: error.message,
    });
  }
};
