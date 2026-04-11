const OnboardingService = require("../services/onboardingService");
const User = require("../models/user");

// Get user's onboarding status
exports.getOnboardingStatus = async (req, res) => {
  try {
    const userId = req.user?.userId || req.user?.id;
    const status = await OnboardingService.getOnboardingStatus(userId);
    
    res.json({
      success: true,
      ...status
    });
  } catch (error) {
    console.error('Error getting onboarding status:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get onboarding status'
    });
  }
};

// Update onboarding step
exports.updateOnboardingStep = async (req, res) => {
  try {
    const userId = req.user?.userId || req.user?.id;
    const stepData = req.body;
    
    const result = await OnboardingService.updateOnboardingStep(userId, stepData);
    
    res.json({
      success: true,
      ...result
    });
  } catch (error) {
    console.error('Error updating onboarding step:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update onboarding step'
    });
  }
};

// Complete onboarding
exports.completeOnboarding = async (req, res) => {
  try {
    const userId = req.user?.userId || req.user?.id;
    const result = await OnboardingService.completeOnboarding(userId);
    
    res.json({
      success: true,
      ...result
    });
  } catch (error) {
    console.error('Error completing onboarding:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to complete onboarding'
    });
  }
};

// Get pending approvals (Admin only)
exports.getPendingApprovals = async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const filters = {
      signup_method: req.query.signup_method,
      date_from: req.query.date_from,
      date_to: req.query.date_to
    };

    console.log('[ONBOARDING] getPendingApprovals called with page:', page, 'limit:', limit, 'filters:', filters);

    // Remove undefined filters
    Object.keys(filters).forEach(key => filters[key] === undefined && delete filters[key]);

    const result = await OnboardingService.getPendingApprovals(page, limit, filters);

    console.log('[ONBOARDING] getPendingApprovals result:', JSON.stringify(result, null, 2));

    res.json({
      success: true,
      ...result
    });
  } catch (error) {
    console.error('Error getting pending approvals:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get pending approvals'
    });
  }
};

// Approve organizer (Admin only)
exports.approveOrganizer = async (req, res) => {
  try {
    const { organizerId } = req.params;
    const adminId = req.user?.userId || req.user?.id;

    console.log('[ONBOARDING] approveOrganizer called with organizerId:', organizerId, 'adminId:', adminId);

    const result = await OnboardingService.approveOrganizer(organizerId, adminId);

    console.log('[ONBOARDING] approveOrganizer result:', JSON.stringify(result, null, 2));

    res.json({
      success: true,
      ...result
    });
  } catch (error) {
    console.error('Error approving organizer:', error);
    res.status(500).json({
      success: false,
      message: error.message || 'Failed to approve organizer'
    });
  }
};

// Reject organizer (Admin only)
exports.rejectOrganizer = async (req, res) => {
  try {
    const { organizerId } = req.params;
    const adminId = req.user?.userId || req.user?.id;
    const { rejection_reason } = req.body;

    console.log('[ONBOARDING] rejectOrganizer called with organizerId:', organizerId, 'reason:', rejection_reason, 'adminId:', adminId);

    if (!rejection_reason || rejection_reason.trim().length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Rejection reason is required'
      });
    }

    const result = await OnboardingService.rejectOrganizer(organizerId, adminId, rejection_reason);

    console.log('[ONBOARDING] rejectOrganizer result:', JSON.stringify(result, null, 2));

    res.json(result);
  } catch (error) {
    console.error('Error rejecting organizer:', error);
    res.status(400).json({
      success: false,
      message: error.message || 'Failed to reject organizer'
    });
  }
};

// Get onboarding statistics (Admin only)
exports.getOnboardingStats = async (req, res) => {
  try {
    const stats = await OnboardingService.getOnboardingStats();
    
    res.json({
      success: true,
      ...stats
    });
  } catch (error) {
    console.error('Error getting onboarding stats:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get onboarding statistics'
    });
  }
};

// Middleware to check if user is onboarded
exports.checkOnboarding = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const user = await User.findById(userId).select('is_onboarded is_approved userType');
    
    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'User not found'
      });
    }
    
    // Check if user is onboarded
    if (!user.is_onboarded) {
      return res.status(403).json({
        success: false,
        message: 'Please complete onboarding to access this feature',
        requires_onboarding: true
      });
    }
    
    // For organizers, check approval status
    if (user.userType === 'Organisator' && !user.is_approved) {
      return res.status(403).json({
        success: false,
        message: 'Your account is waiting for approval',
        requires_approval: true
      });
    }
    
    next();
  } catch (error) {
    console.error('Error checking onboarding status:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to verify onboarding status'
    });
  }
};

// Middleware to check if user is admin
exports.checkAdmin = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const user = await User.findById(userId).select('userType');
    
    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'User not found'
      });
    }
    
    // Check if user is admin (you might want to add an isAdmin field to user model)
    if (user.userType !== 'Admin') {
      return res.status(403).json({
        success: false,
        message: 'Admin access required'
      });
    }
    
    next();
  } catch (error) {
    console.error('Error checking admin status:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to verify admin status'
    });
  }
};
