const mongoose = require("mongoose");

/**
 * Payment Model
 * Stores Stripe payment transactions for activity bookings
 */
const paymentSchema = new mongoose.Schema(
  {
    // Stripe Checkout session ID (unique identifier from Stripe)
    stripe_session_id: {
      type: String,
      unique: true,
      index: true,
    },
    
    // Stripe Payment Intent ID (for refunds and tracking)
    stripe_payment_intent_id: {
      type: String,
      index: true,
    },
    
    // Payment token (for tracking and verification)
    token: {
      type: String,
      unique: true,
      sparse: true, // Allows multiple null values
      index: true,
    },
    
    // Order ID (unique identifier for our system)
    order_id: {
      type: String,
      required: true,
      unique: true,
      index: true,
    },
    
    // Reference to the user making the payment
    user_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    
    // Reference to the booking/inscription
    inscription_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Inscription",
      index: true,
    },

    // Activity details for post-payment inscription creation (new flow)
    activity_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Activite",
      index: true,
    },
    activity_title: {
      type: String,
    },
    nombre_participants: {
      type: Number,
    },
    adults: {
      type: Number,
    },
    children: {
      type: Number,
    },

    // Payment amount (in USD/EUR)
    amount: {
      type: Number,
      required: true,
      min: 0,
    },
    
    // Currency (USD, EUR, etc.)
    currency: {
      type: String,
      required: true,
      default: "USD",
      uppercase: true,
    },
    
    // Payment description
    description: {
      type: String,
    },
    
    // Payment status from Stripe
    status: {
      type: String,
      enum: ["pending", "paid", "failed", "cancelled", "refunded"],
      default: "pending",
      index: true,
    },
    
    // Stripe Checkout URL (redirect user to this URL to pay)
    payment_url: {
      type: String,
    },
    
    // Success URL for redirect after payment
    success_url: {
      type: String,
    },
    
    // Cancel URL for redirect after cancellation
    cancel_url: {
      type: String,
    },
    
    // Webhook response from Stripe
    webhook_response: {
      type: mongoose.Schema.Types.Mixed,
    },
    
    // Payment method (e.g., "card", "alipay", etc.)
    payment_method: {
      type: String,
    },
    
    // Timestamps
    paid_at: {
      type: Date,
    },
    failed_at: {
      type: Date,
    },
    refunded_at: {
      type: Date,
    },
  },
  {
    timestamps: true,
  }
);

// Index for efficient queries
paymentSchema.index({ user_id: 1, status: 1 });
paymentSchema.index({ inscription_id: 1 });
paymentSchema.index({ stripe_session_id: 1 });
paymentSchema.index({ createdAt: -1 });

/**
 * Static method to find payment by order_id
 */
paymentSchema.statics.findByOrderId = function (order_id) {
  return this.findOne({ order_id });
};

/**
 * Static method to find payment by stripe_session_id
 */
paymentSchema.statics.findBySessionId = function (session_id) {
  return this.findOne({ stripe_session_id: session_id });
};

/**
 * Static method to get user payment history
 */
paymentSchema.statics.getUserPayments = function (user_id) {
  return this.find({ user_id })
    .populate("inscription_id")
    .sort({ createdAt: -1 });
};

const Payment = mongoose.model("Payment", paymentSchema);

module.exports = Payment;
