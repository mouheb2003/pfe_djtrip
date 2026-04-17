const express = require('express');
const router = express.Router();
const onboardingController = require('../controllers/onboarding');
const { verifyToken, verifyAdmin } = require('../middleware/auth');

// User onboarding routes
router.get('/status', verifyToken, onboardingController.getOnboardingStatus);
router.post('/step', verifyToken, onboardingController.updateOnboardingStep);
router.put('/user-type', verifyToken, onboardingController.updateUserType);
router.post('/complete', verifyToken, onboardingController.completeOnboarding);

// Admin approval routes
router.get(
  '/approvals/pending',
  verifyToken,
  verifyAdmin,
  onboardingController.getPendingApprovals
);
router.post(
  '/approvals/:organizerId/approve',
  verifyToken,
  verifyAdmin,
  onboardingController.approveOrganizer
);
router.post(
  '/approvals/:organizerId/reject',
  verifyToken,
  verifyAdmin,
  onboardingController.rejectOrganizer
);

// Admin statistics
router.get('/stats', verifyToken, verifyAdmin, onboardingController.getOnboardingStats);

module.exports = router;
