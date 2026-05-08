const express = require("express");
const router = express.Router();
const paymentController = require("../controllers/payment");
const authMiddleware = require("../middleware/auth");

/**
 * Payment Routes
 * All payment-related endpoints for the DJTrip platform using Stripe
 */

// POST /api/payments/create-checkout-session
// Create a Stripe Checkout session (recommended for mobile apps)
router.post("/create-checkout-session", authMiddleware.verifyToken, paymentController.createCheckoutSession);

// POST /api/payments/create-payment-intent
// Create a Stripe Payment Intent (for custom payment flows)
router.post("/create-payment-intent", authMiddleware.verifyToken, paymentController.createPaymentIntent);

// POST /api/payments/complete-payment
// Manual payment completion for testing (simulates webhook)
// Note: This requires authentication
router.post("/complete-payment", authMiddleware.verifyToken, paymentController.completePayment);

// POST /api/payments/cancel-payment
// Cancel a pending payment
// Note: This requires authentication
router.post("/cancel-payment", authMiddleware.verifyToken, paymentController.cancelPayment);

// POST /api/payments/webhook
// Webhook endpoint for Stripe payment notifications
// Note: This should NOT require authentication (Stripe calls this)
router.post("/webhook", paymentController.webhook);

// GET /payment/success
// Stripe redirects here after successful payment
// Note: This should NOT require authentication (Stripe calls this)
router.get("/payment/success", paymentController.paymentSuccess);

// GET /payment/cancel
// Stripe redirects here after cancelled payment
// Note: This should NOT require authentication (Stripe calls this)
router.get("/payment/cancel", paymentController.paymentCancel);

// GET /api/payments/check
// Check payment status
// Query params: session_id or order_id
router.get("/check", authMiddleware.verifyToken, paymentController.checkPayment);

// POST /api/payments/:inscription_id/accept
// Organizer accepts a paid reservation
router.post("/:inscription_id/accept", authMiddleware.verifyToken, paymentController.acceptReservation);

// POST /api/payments/:inscription_id/reject
// Organizer rejects a paid reservation and refunds user via Stripe
router.post("/:inscription_id/reject", authMiddleware.verifyToken, paymentController.rejectReservation);

// GET /api/payments/user
// Get user's payment history
router.get("/user", authMiddleware.verifyToken, paymentController.getUserPayments);

// GET /api/payments/wallet
// Get user's wallet balance
router.get("/wallet", authMiddleware.verifyToken, paymentController.getWalletBalance);

// GET /api/payments/all
// Get all payments (admin only)
router.get("/all", authMiddleware.verifyToken, paymentController.getAllPayments);

// DELETE /api/payments/:paymentId
// Delete payment record (admin only)
router.delete("/:paymentId", authMiddleware.verifyToken, paymentController.deletePayment);

// POST /api/payments/:paymentId/refund
// Manual refund for admin (admin only)
router.post("/:paymentId/refund", authMiddleware.verifyToken, paymentController.manualRefund);

module.exports = router;
