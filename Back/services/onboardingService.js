const User = require("../models/user");
const emailService = require("./onboardingEmailService");

class OnboardingService {
  // Get user's onboarding status
  static async getOnboardingStatus(userId) {
    const user = await User.findById(userId).select(
      'is_onboarded is_approved userType signup_method onboarding_step onboarding_data submitted_for_approval'
    );
    
    if (!user) {
      throw new Error('User not found');
    }

    return {
      is_onboarded: user.is_onboarded,
      is_approved: user.is_approved,
      userType: user.userType,
      signup_method: user.signup_method,
      current_step: user.onboarding_step,
      onboarding_data: user.onboarding_data || {},
      submitted_for_approval: user.submitted_for_approval,
      next_step: this.getNextStep(user),
      can_access_app: this.canAccessApp(user)
    };
  }

  // Update onboarding step
  static async updateOnboardingStep(userId, stepData) {
    const user = await User.findById(userId);
    if (!user) {
      throw new Error('User not found');
    }

    // Update onboarding data
    user.onboarding_data = {
      ...user.onboarding_data,
      ...stepData
    };
    user.onboarding_step = (user.onboarding_step || 0) + 1;

    await user.save();

    return {
      success: true,
      current_step: user.onboarding_step,
      next_step: this.getNextStep(user),
      is_completed: user.is_onboarded
    };
  }

  // Complete onboarding
  static async completeOnboarding(userId) {
    const user = await User.findById(userId);
    if (!user) {
      throw new Error('User not found');
    }

    user.is_onboarded = true;
    user.profile_completed = true;

    // For organizers, set approval status to false and submit for approval
    if (user.userType === 'Organisator') {
      user.is_approved = false;
      user.submitted_for_approval = new Date();
      
      // Send notification to admin
      await this.notifyAdminForApproval(user);
    }

    await user.save();

    // Send confirmation email
    try {
      if (user.userType === 'Organisator') {
        await emailService.sendOrganizerSubmittedEmail(
          user.email,
          user.fullname || 'DJTrip User'
        );
      } else {
        await emailService.sendOnboardingCompletedEmail(
          user.email,
          user.fullname || 'DJTrip User'
        );
      }
    } catch (emailError) {
      console.error('Error sending onboarding completion email:', emailError);
    }

    return {
      success: true,
      is_onboarded: true,
      is_approved: user.is_approved,
      requires_approval: user.userType === 'Organisator' && !user.is_approved
    };
  }

  // Get next onboarding step based on user type and current step
  static getNextStep(user) {
    const steps = user.userType === 'Organisator' 
      ? ORGANIZER_ONBOARDING_STEPS 
      : TOURIST_ONBOARDING_STEPS;
    
    const currentStep = user.onboarding_step || 0;
    
    if (currentStep >= steps.length) {
      return null; // Onboarding completed
    }
    
    return steps[currentStep];
  }

  // Check if user can access the app
  static canAccessApp(user) {
    if (!user.is_onboarded) {
      return false;
    }
    
    // Organizers need approval
    if (user.userType === 'Organisator' && !user.is_approved) {
      return false;
    }
    
    return true;
  }

  // Get pending approvals for admin
  static async getPendingApprovals(page = 1, limit = 20, filters = {}) {
    const query = {
      userType: 'Organisator',
      is_onboarded: true,
      is_approved: false,
      submitted_for_approval: { $exists: true }
    };

    // Apply filters
    if (filters.signup_method) {
      query.signup_method = filters.signup_method;
    }
    
    if (filters.date_from) {
      query.submitted_for_approval = {
        ...query.submitted_for_approval,
        $gte: new Date(filters.date_from)
      };
    }
    
    if (filters.date_to) {
      query.submitted_for_approval = {
        ...query.submitted_for_approval,
        $lte: new Date(filters.date_to)
      };
    }

    const skip = (page - 1) * limit;
    
    const [organizers, total] = await Promise.all([
      User.find(query)
        .select('fullname email userType signup_method submitted_for_approval onboarding_data')
        .sort({ submitted_for_approval: -1 })
        .skip(skip)
        .limit(limit)
        .lean(),
      User.countDocuments(query)
    ]);

    return {
      organizers,
      pagination: {
        current_page: page,
        total_pages: Math.ceil(total / limit),
        total_items: total,
        items_per_page: limit
      }
    };
  }

  // Approve organizer
  static async approveOrganizer(organizerId, adminId) {
    const organizer = await User.findById(organizerId);
    if (!organizer) {
      throw new Error('Organizer not found');
    }

    if (organizer.userType !== 'Organisator') {
      throw new Error('User is not an organizer');
    }

    if (organizer.is_approved) {
      throw new Error('Organizer is already approved');
    }

    organizer.is_approved = true;
    organizer.approved_at = new Date();
    organizer.approved_by = adminId;

    await organizer.save();

    // Send approval email
    try {
      await emailService.sendOrganizerApprovedEmail(
        organizer.email,
        organizer.fullname || 'DJTrip User'
      );
    } catch (emailError) {
      console.error('Error sending approval email:', emailError);
    }

    return {
      success: true,
      message: 'Organizer approved successfully',
      organizer: {
        id: organizer._id,
        fullname: organizer.fullname,
        email: organizer.email,
        approved_at: organizer.approved_at
      }
    };
  }

  // Reject organizer
  static async rejectOrganizer(organizerId, adminId, rejectionReason) {
    const organizer = await User.findById(organizerId);
    if (!organizer) {
      throw new Error('Organizer not found');
    }

    if (organizer.userType !== 'Organisator') {
      throw new Error('User is not an organizer');
    }

    if (organizer.is_approved) {
      throw new Error('Cannot reject an already approved organizer');
    }

    organizer.is_approved = false;
    organizer.rejection_reason = rejectionReason;
    organizer.approved_by = adminId;
    organizer.rejected_at = new Date();
    // Remove submitted_for_approval to remove from pending list
    organizer.submitted_for_approval = undefined;

    await organizer.save();

    // Send rejection email
    try {
      await emailService.sendOrganizerRejectedEmail(
        organizer.email,
        organizer.fullname || 'DJTrip User',
        rejectionReason
      );
    } catch (emailError) {
      console.error('Error sending rejection email:', emailError);
    }

    return {
      success: true,
      message: 'Organizer rejected successfully',
      organizer: {
        id: organizer._id,
        fullname: organizer.fullname,
        email: organizer.email,
        rejection_reason: organizer.rejection_reason
      }
    };
  }

  // Get onboarding statistics for admin dashboard
  static async getOnboardingStats() {
    const [
      totalUsers,
      onboardedUsers,
      pendingApprovals,
      googleSignups,
      emailSignups,
      facebookSignups
    ] = await Promise.all([
      User.countDocuments(),
      User.countDocuments({ is_onboarded: true }),
      User.countDocuments({ 
        userType: 'Organisator', 
        is_onboarded: true, 
        is_approved: false 
      }),
      User.countDocuments({ signup_method: 'google' }),
      User.countDocuments({ signup_method: 'email' }),
      User.countDocuments({ signup_method: 'facebook' })
    ]);

    return {
      total_users: totalUsers,
      onboarded_users: onboardedUsers,
      pending_approvals: pendingApprovals,
      onboarding_completion_rate: totalUsers > 0 ? (onboardedUsers / totalUsers * 100).toFixed(1) : 0,
      signup_methods: {
        google: googleSignups,
        email: emailSignups,
        facebook: facebookSignups
      }
    };
  }

  // Notify admin for new approval request
  static async notifyAdminForApproval(user) {
    // This would typically send a notification to admin dashboard
    // For now, we'll just log it
    console.log(`New organizer approval request: ${user.email} (${user._id})`);
    
    // TODO: Implement admin notification system
    // Could be: WebSocket notification, email to admin, dashboard alert, etc.
  }
}

// Onboarding step definitions
const TOURIST_ONBOARDING_STEPS = [
  {
    id: 'phone',
    title: 'Phone Number',
    description: 'Add your phone number for better communication',
    required: true,
    fields: ['num_tel', 'pays_telephone']
  },
  {
    id: 'profile_picture',
    title: 'Profile Picture',
    description: 'Add a profile picture to personalize your account',
    required: false,
    fields: ['avatar']
  },
  {
    id: 'country',
    title: 'Country',
    description: 'Tell us where you\'re from',
    required: true,
    fields: ['pays_origine']
  },
  {
    id: 'language',
    title: 'Preferred Language',
    description: 'Choose your preferred language',
    required: true,
    fields: ['langue_preferee']
  }
];

const ORGANIZER_ONBOARDING_STEPS = [
  {
    id: 'phone',
    title: 'Phone Number',
    description: 'Add your phone number for better communication',
    required: true,
    fields: ['num_tel', 'pays_telephone']
  },
  {
    id: 'profile_picture',
    title: 'Profile Picture',
    description: 'Add a profile picture to personalize your account',
    required: true,
    fields: ['avatar']
  },
  {
    id: 'country',
    title: 'Country',
    description: 'Tell us where you\'re from',
    required: true,
    fields: ['pays_origine']
  },
  {
    id: 'language',
    title: 'Preferred Language',
    description: 'Choose your preferred language',
    required: true,
    fields: ['langue_preferee']
  },
  {
    id: 'specialized_activities',
    title: 'Specialized Activities',
    description: 'What types of activities do you specialize in?',
    required: true,
    fields: ['specialites_activites']
  },
  {
    id: 'spoken_languages',
    title: 'Languages You Speak',
    description: 'What languages do you offer tours in?',
    required: true,
    fields: ['langues_proposees']
  }
];

module.exports = OnboardingService;
