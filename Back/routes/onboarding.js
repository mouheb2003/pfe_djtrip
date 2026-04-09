const express = require('express');
const router = express.Router();
const onboardingController = require('../controllers/onboarding');

// User onboarding routes
router.get('/status', onboardingController.getOnboardingStatus);
router.post('/step', onboardingController.updateOnboardingStep);
router.post('/complete', onboardingController.completeOnboarding);

// Admin approval routes
router.get('/approvals/pending', onboardingController.getPendingApprovals);
router.post('/approvals/:organizerId/approve', onboardingController.approveOrganizer);
router.post('/approvals/:organizerId/reject', onboardingController.rejectOrganizer);

// Admin statistics
router.get('/stats', onboardingController.getOnboardingStats);

module.exports = router;
