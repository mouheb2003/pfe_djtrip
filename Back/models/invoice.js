const mongoose = require("mongoose");

/**
 * Invoice Model
 * Stores electronic invoices for successful payments
 */
const invoiceSchema = new mongoose.Schema(
  {
    // Unique invoice number (e.g., INV-2024-001234)
    invoice_number: {
      type: String,
      required: true,
      unique: true,
      index: true,
    },

    // Reference to the payment
    payment_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Payment",
      required: true,
      index: true,
    },

    // Reference to the booking/inscription
    inscription_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Inscription",
      required: true,
      index: true,
    },

    // Reference to the user who paid
    user_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },

    // Invoice status
    status: {
      type: String,
      enum: ["generated", "sent", "viewed"],
      default: "generated",
    },

    // Invoice details (snapshot at time of generation)
    invoice_details: {
      // Company information
      company: {
        name: {
          type: String,
          default: "DJTrip",
        },
        address: {
          type: String,
          default: "Djerba, Tunisia",
        },
        email: {
          type: String,
          default: "contact@djtrip.com",
        },
        phone: {
          type: String,
          default: "+216 XX XXX XXX",
        },
        tax_id: {
          type: String,
          default: "TAX-123456",
        },
      },

      // Customer information (snapshot)
      customer: {
        name: String,
        email: String,
        phone: String,
        address: String,
      },

      // Payment information
      payment: {
        transaction_id: String,
        payment_method: String,
        payment_date: Date,
        currency: String,
      },

      // Order items
      items: [
        {
          description: String,
          quantity: Number,
          unit_price: Number,
          total: Number,
        },
      ],

      // Totals
      totals: {
        subtotal: Number,
        tax_rate: {
          type: Number,
          default: 0.19, // 19% VAT
        },
        tax_amount: Number,
        total: Number,
      },
    },

    // PDF file path (if stored locally)
    pdf_path: String,

    // PDF URL (if stored in cloud)
    pdf_url: String,

    // Email sent status
    email_sent: {
      sent: {
        type: Boolean,
        default: false,
      },
      sent_at: Date,
      email_to: String,
    },

    // When invoice was viewed by customer
    viewed_at: {
      type: Date,
    },
  },
  {
    timestamps: true,
  }
);

// Indexes for efficient queries
invoiceSchema.index({ invoice_number: 1 });
invoiceSchema.index({ payment_id: 1 });
invoiceSchema.index({ inscription_id: 1 });
invoiceSchema.index({ user_id: 1, createdAt: -1 });
invoiceSchema.index({ createdAt: -1 });

/**
 * Static method to generate invoice number
 * Format: INV-YYYY-XXXXXX
 */
invoiceSchema.statics.generateInvoiceNumber = async function () {
  const year = new Date().getFullYear();
  const count = await this.countDocuments({
    invoice_number: new RegExp(`^INV-${year}`),
  });
  const sequence = (count + 1).toString().padStart(6, "0");
  return `INV-${year}-${sequence}`;
};

/**
 * Static method to find invoice by payment_id
 */
invoiceSchema.statics.findByPaymentId = function (payment_id) {
  return this.findOne({ payment_id }).populate("payment_id").populate("inscription_id").populate("user_id");
};

/**
 * Static method to find invoice by inscription_id
 */
invoiceSchema.statics.findByInscriptionId = function (inscription_id) {
  return this.findOne({ inscription_id }).populate("payment_id").populate("inscription_id").populate("user_id");
};

/**
 * Static method to get user invoices
 */
invoiceSchema.statics.getUserInvoices = function (user_id) {
  return this.find({ user_id })
    .populate("payment_id")
    .populate("inscription_id")
    .sort({ createdAt: -1 });
};

/**
 * Method to mark invoice as sent
 */
invoiceSchema.methods.markAsSent = function (email_to) {
  this.status = "sent";
  this.email_sent = {
    sent: true,
    sent_at: new Date(),
    email_to: email_to,
  };
  return this.save();
};

/**
 * Method to mark invoice as viewed
 */
invoiceSchema.methods.markAsViewed = function () {
  this.status = "viewed";
  this.viewed_at = new Date();
  return this.save();
};

const Invoice = mongoose.model("Invoice", invoiceSchema);

module.exports = Invoice;
