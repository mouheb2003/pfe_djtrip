const express = require("express");
const router = express.Router();
const {
  generateInvoice,
  getInvoice,
  getInvoiceByPaymentId,
  getUserInvoices,
  generateInvoicePDF,
  sendInvoiceByEmail,
  deleteInvoice,
} = require("../controllers/invoice");
const authMiddleware = require("../middleware/auth");

// All routes require authentication
router.use(authMiddleware.verifyToken);

// Generate invoice from payment
router.post("/generate/:paymentId", generateInvoice);

// Get invoice by ID
router.get("/:invoiceId", getInvoice);

// Get invoice by payment ID
router.get("/payment/:paymentId", getInvoiceByPaymentId);

// Get user invoices
router.get("/user/invoices", getUserInvoices);

// Generate PDF for invoice
router.get("/:invoiceId/pdf", generateInvoicePDF);

// Send invoice by email
router.post("/:invoiceId/send-email", sendInvoiceByEmail);

// Delete invoice (admin only - add admin middleware if needed)
router.delete("/:invoiceId", deleteInvoice);

module.exports = router;
