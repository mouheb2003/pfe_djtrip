const Invoice = require("../models/invoice");
const Inscription = require("../models/inscription");
const Activite = require("../models/activite");
const User = require("../models/user");
const PDFDocument = require("pdfkit");
const emailService = require("../services/email");

/**
 * Generate invoice from payment
 * POST /api/invoice/generate/:paymentId
 * NOTE: Payment system has been removed. This endpoint is no longer available.
 */
exports.generateInvoice = async (req, res) => {
  return res.status(410).json({
    success: false,
    message: "Invoice generation from payments is no longer supported.",
  });
};

/**
 * Get invoice by ID
 * GET /api/invoice/:invoiceId
 */
exports.getInvoice = async (req, res) => {
  try {
    const { invoiceId } = req.params;
    const userId = req.user.userId;

    const invoice = await Invoice.findById(invoiceId)
      .populate("payment_id")
      .populate("inscription_id")
      .populate("user_id");

    if (!invoice) {
      return res.status(404).json({
        success: false,
        message: "Invoice not found",
      });
    }

    // Security: User can only view their own invoices
    const invoiceUserId = invoice.user_id._id ? invoice.user_id._id.toString() : invoice.user_id.toString();
    const userIdString = userId.toString();
    if (invoiceUserId !== userIdString) {
      console.log(`Invoice authorization failed: invoiceUserId=${invoiceUserId}, userId=${userIdString}`);
      return res.status(403).json({
        success: false,
        message: "Unauthorized: You can only view your own invoices",
      });
    }

    // Mark as viewed
    await invoice.markAsViewed();

    res.status(200).json({
      success: true,
      invoice: invoice,
    });
  } catch (error) {
    console.error("Error fetching invoice:", error);
    res.status(500).json({
      success: false,
      message: "Error fetching invoice",
      error: error.message,
    });
  }
};

/**
 * Get invoice by payment ID
 * GET /api/invoice/payment/:paymentId
 * NOTE: Payment system has been removed.
 */
exports.getInvoiceByPaymentId = async (req, res) => {
  return res.status(410).json({
    success: false,
    message: "Payment-based invoice lookup is no longer supported.",
  });
};

/**
 * Get user invoices
 * GET /api/invoice/user/invoices
 */
exports.getUserInvoices = async (req, res) => {
  try {
    const userId = req.user.id;
    const { page = 1, limit = 10 } = req.query;

    const invoices = await Invoice.find({ user_id: userId })
      .populate("payment_id")
      .populate("inscription_id")
      .sort({ createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(parseInt(limit));

    const total = await Invoice.countDocuments({ user_id: userId });

    res.status(200).json({
      success: true,
      invoices: invoices,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: total,
        pages: Math.ceil(total / limit),
      },
    });
  } catch (error) {
    console.error("Error fetching user invoices:", error);
    res.status(500).json({
      success: false,
      message: "Error fetching user invoices",
      error: error.message,
    });
  }
};

/**
 * Generate PDF for invoice
 * GET /api/invoice/:invoiceId/pdf
 */
exports.generateInvoicePDF = async (req, res) => {
  try {
    const { invoiceId } = req.params;
    const userId = req.user.userId;

    const invoice = await Invoice.findById(invoiceId)
      .populate("payment_id")
      .populate("inscription_id")
      .populate("user_id");

    if (!invoice) {
      return res.status(404).json({
        success: false,
        message: "Invoice not found",
      });
    }

    // Security: User can only download their own invoices
    const invoiceUserId = invoice.user_id._id ? invoice.user_id._id.toString() : invoice.user_id.toString();
    const userIdString = userId.toString();
    if (invoiceUserId !== userIdString) {
      console.log(`Invoice PDF authorization failed: invoiceUserId=${invoiceUserId}, userId=${userIdString}`);
      return res.status(403).json({
        success: false,
        message: "Unauthorized: You can only download your own invoices",
      });
    }

    // Create PDF
    const doc = new PDFDocument({
      size: "A4",
      margin: 50,
      bufferPages: true,
    });

    // Set response headers
    res.setHeader("Content-Type", "application/pdf");
    res.setHeader(
      "Content-Disposition",
      `attachment; filename=facture_${invoice.invoice_number}.pdf`
    );

    // Pipe PDF to response
    doc.pipe(res);

    // Invoice content
    const details = invoice.invoice_details;
    const company = details.company;
    const customer = details.customer;
    const payment = details.payment;
    const items = details.items;
    const totals = details.totals;

    // Colors
    const primaryColor = "#0066CC"; // Match app's blue color
    const secondaryColor = "#64748B";
    const lightGray = "#F1F5F9";

    // Header
    doc.rect(0, 0, doc.page.width, 80).fill(primaryColor);
    
    // Company name (no logo to speed up generation)
    doc.fillColor("white")
       .fontSize(32)
       .font("Helvetica-Bold")
       .text(company.name, 50, 35, { align: "left" });
    
    doc.fillColor("white")
       .fontSize(12)
       .font("Helvetica")
       .text("Electronic Invoice", 50, 55, { align: "left" });

    // Invoice number and date
    doc.fillColor(secondaryColor)
       .fontSize(10)
       .font("Helvetica")
       .text(`Invoice Number: ${invoice.invoice_number}`, 400, 25, { align: "right" });
    
    doc.fillColor(secondaryColor)
       .fontSize(10)
       .text(`Date: ${new Date(invoice.createdAt).toLocaleDateString()}`, 400, 40, { align: "right" });
    
    doc.fillColor(secondaryColor)
       .fontSize(10)
       .text(`Status: ${invoice.status.toUpperCase()}`, 400, 55, { align: "right" });

    // Reset position
    doc.y = 110;

    // Bill To section
    doc.fillColor(primaryColor)
       .fontSize(14)
       .font("Helvetica-Bold")
       .text("Bill To", 50, doc.y);
    
    doc.y += 5;
    
    doc.fillColor(secondaryColor)
       .fontSize(11)
       .font("Helvetica")
       .text(customer.name || "Customer", 50, doc.y);
    
    doc.y += 5;
    
    if (customer.email) {
      doc.fillColor(secondaryColor)
         .fontSize(10)
         .text(customer.email, 50, doc.y);
      doc.y += 5;
    }
    
    if (customer.phone) {
      doc.fillColor(secondaryColor)
         .fontSize(10)
         .text(customer.phone, 50, doc.y);
      doc.y += 5;
    }
    
    if (customer.address) {
      doc.fillColor(secondaryColor)
         .fontSize(10)
         .text(customer.address, 50, doc.y);
    }

    // Company Info section
    const companyY = 110;
    doc.fillColor(primaryColor)
       .fontSize(14)
       .font("Helvetica-Bold")
       .text("From", 400, companyY);
    
    doc.y = companyY + 5;
    
    doc.fillColor(secondaryColor)
       .fontSize(11)
       .font("Helvetica")
       .text(company.name, 400, doc.y);
    
    doc.y += 5;
    
    if (company.address) {
      doc.fillColor(secondaryColor)
         .fontSize(10)
         .text(company.address, 400, doc.y);
      doc.y += 5;
    }
    
    if (company.email) {
      doc.fillColor(secondaryColor)
         .fontSize(10)
         .text(company.email, 400, doc.y);
      doc.y += 5;
    }
    
    if (company.phone) {
      doc.fillColor(secondaryColor)
         .fontSize(10)
         .text(company.phone, 400, doc.y);
    }

    doc.y += 30;

    // Payment Details
    doc.rect(50, doc.y, 495, 40).fill(lightGray);
    doc.fillColor(primaryColor)
       .fontSize(12)
       .font("Helvetica-Bold")
       .text("Payment Details", 65, doc.y + 12);
    
    doc.y += 50;

    doc.fillColor(secondaryColor)
       .fontSize(10)
       .font("Helvetica")
       .text(`Transaction ID: ${payment.transaction_id || "N/A"}`, 50, doc.y);
    
    doc.y += 5;
    
    doc.fillColor(secondaryColor)
       .fontSize(10)
       .text(`Payment Method: ${payment.payment_method || "Card"}`, 50, doc.y);
    
    doc.y += 5;
    
    doc.fillColor(secondaryColor)
       .fontSize(10)
       .text(`Payment Date: ${payment.payment_date ? new Date(payment.payment_date).toLocaleString() : "N/A"}`, 50, doc.y);

    doc.y += 30;

    // Items table header
    const tableTop = doc.y;
    const tableWidth = 495;
    const col1 = 50;
    const col2 = 300;
    const col3 = 400;
    const col4 = 500;

    doc.rect(col1, tableTop, tableWidth, 30).fill(lightGray);
    
    doc.fillColor(primaryColor)
       .fontSize(10)
       .font("Helvetica-Bold")
       .text("Description", col1 + 10, tableTop + 10);
    
    doc.fillColor(primaryColor)
       .text("Quantity", col2, tableTop + 10);
    
    doc.fillColor(primaryColor)
       .text("Unit Price", col3, tableTop + 10);
    
    doc.fillColor(primaryColor)
       .text("Total", col4 - 40, tableTop + 10);

    doc.y = tableTop + 40;

    // Items
    items.forEach((item, index) => {
      const y = tableTop + 40 + (index * 25);
      
      doc.fillColor(secondaryColor)
         .fontSize(10)
         .font("Helvetica")
         .text(item.description, col1 + 10, y);
      
      doc.fillColor(secondaryColor)
         .text(item.quantity.toString(), col2, y);
      
      doc.fillColor(secondaryColor)
         .text(`${payment.currency} ${item.unit_price.toFixed(2)}`, col3, y);
      
      doc.fillColor(secondaryColor)
         .text(`${payment.currency} ${item.total.toFixed(2)}`, col4 - 40, y);
    });

    doc.y = tableTop + 40 + (items.length * 25) + 20;

    // Check if we need a new page for totals
    if (doc.y > 650) {
      doc.addPage();
      doc.y = 50;
    }

    // Totals
    const totalsX = 350;
    
    // Ensure totals object exists
    const safeTotals = totals || {
      subtotal: 0,
      tax_rate: 0.19,
      tax_amount: 0,
      total: 0,
      currency: payment.currency || 'TND'
    };
    
    doc.fillColor(secondaryColor)
       .fontSize(10)
       .font("Helvetica")
       .text("Subtotal:", totalsX, doc.y);
    
    doc.fillColor(secondaryColor)
       .text(`${payment.currency} ${safeTotals.subtotal.toFixed(2)}`, 500, doc.y, { align: "right" });
    
    doc.y += 15;
    
    doc.fillColor(secondaryColor)
       .text(`VAT (${(safeTotals.tax_rate * 100).toFixed(0)}%):`, totalsX, doc.y);
    
    doc.fillColor(secondaryColor)
       .text(`${payment.currency} ${safeTotals.tax_amount.toFixed(2)}`, 500, doc.y, { align: "right" });
    
    doc.y += 20;
    
    doc.rect(totalsX - 10, doc.y, 165, 30).fill(primaryColor);
    
    doc.fillColor("white")
       .fontSize(12)
       .font("Helvetica-Bold")
       .text("TOTAL:", totalsX, doc.y + 8);
    
    doc.fillColor("white")
       .text(`${payment.currency} ${safeTotals.total.toFixed(2)}`, 500, doc.y + 8, { align: "right" });

    doc.y += 50;

    // Footer
    doc.fillColor(secondaryColor)
       .fontSize(9)
       .font("Helvetica")
       .text("Thank you for your business!", 50, doc.y, { align: "center" });
    
    doc.y += 10;
    
    doc.fillColor(secondaryColor)
       .fontSize(8)
       .text("This is a computer-generated invoice and does not require a signature.", 50, doc.y, { align: "center" });

    // Finalize PDF
    doc.end();
  } catch (error) {
    console.error("Error generating PDF:", error);
    res.status(500).json({
      success: false,
      message: "Error generating PDF",
      error: error.message,
    });
  }
};

/**
 * Send invoice by email
 * POST /api/invoice/:invoiceId/send-email
 */
exports.sendInvoiceByEmail = async (req, res) => {
  try {
    const { invoiceId } = req.params;
    const userId = req.user.userId;

    console.log(`[INVOICE EMAIL] Attempting to send invoice ${invoiceId} for user ${userId}`);

    const invoice = await Invoice.findById(invoiceId)
      .populate("payment_id")
      .populate("inscription_id")
      .populate("user_id");

    if (!invoice) {
      console.log(`[INVOICE EMAIL] Invoice not found: ${invoiceId}`);
      return res.status(404).json({
        success: false,
        message: "Invoice not found",
      });
    }

    // Security: User can only send their own invoices
    const invoiceUserId = invoice.user_id._id ? invoice.user_id._id.toString() : invoice.user_id.toString();
    const userIdString = userId.toString();
    if (invoiceUserId !== userIdString) {
      console.log(`Invoice email authorization failed: invoiceUserId=${invoiceUserId}, userId=${userIdString}`);
      return res.status(403).json({
        success: false,
        message: "Unauthorized: You can only send your own invoices",
      });
    }

    const customer = invoice.invoice_details.customer;
    const recipientEmail = customer.email;

    console.log(`[INVOICE EMAIL] Customer email: ${recipientEmail}`);

    if (!recipientEmail) {
      console.log(`[INVOICE EMAIL] Customer email not found in invoice details`);
      return res.status(400).json({
        success: false,
        message: "Customer email not found",
      });
    }

    // Generate PDF in memory
    console.log(`[INVOICE EMAIL] Generating PDF...`);
    const pdfBuffer = await generatePDFBuffer(invoice);
    console.log(`[INVOICE EMAIL] PDF generated, size: ${pdfBuffer.length} bytes`);

    // Send email with PDF attachment
    console.log(`[INVOICE EMAIL] Sending email to ${recipientEmail}...`);
    const emailResult = await emailService.sendEmailWithAttachment({
      to: recipientEmail,
      subject: `Invoice ${invoice.invoice_number} from DJTrip`,
      html: generateInvoiceEmailHTML(invoice),
      attachments: [
        {
          filename: `facture_${invoice.invoice_number}.pdf`,
          content: pdfBuffer,
          contentType: "application/pdf",
        },
      ],
    });

    console.log(`[INVOICE EMAIL] Email result:`, emailResult);

    // Mark invoice as sent
    await invoice.markAsSent(recipientEmail);

    res.status(200).json({
      success: true,
      message: "Invoice sent successfully",
      emailResult: emailResult,
    });
  } catch (error) {
    console.error("[INVOICE EMAIL] Error sending invoice by email:", error);
    res.status(500).json({
      success: false,
      message: "Error sending invoice by email",
      error: error.message,
    });
  }
};

/**
 * Generate PDF buffer for email attachment
 */
async function generatePDFBuffer(invoice) {
  return new Promise((resolve, reject) => {
    try {
      const doc = new PDFDocument({
        size: "A4",
        margin: 50,
        bufferPages: true,
      });

      const chunks = [];
      doc.on("data", (chunk) => chunks.push(chunk));
      doc.on("end", () => resolve(Buffer.concat(chunks)));
      doc.on("error", reject);

      // Generate PDF content (same as generateInvoicePDF)
      const details = invoice.invoice_details;
      const company = details.company;
      const customer = details.customer;
      const payment = details.payment;
      const items = details.items;
      const totals = details.totals;

      const primaryColor = "#0066CC"; // Match app's blue color
      const secondaryColor = "#64748B";
      const lightGray = "#F1F5F9";

      // Header
      doc.rect(0, 0, doc.page.width, 80).fill(primaryColor);
      
      // Company name (no logo to speed up generation)
      doc.fillColor("white")
         .fontSize(32)
         .font("Helvetica-Bold")
         .text(company.name, 50, 35, { align: "left" });
      
      doc.fillColor("white")
         .fontSize(12)
         .font("Helvetica")
         .text("Electronic Invoice", 50, 55, { align: "left" });

      doc.fillColor(secondaryColor)
         .fontSize(10)
         .font("Helvetica")
         .text(`Invoice Number: ${invoice.invoice_number}`, 400, 25, { align: "right" });
      
      doc.fillColor(secondaryColor)
         .fontSize(10)
         .text(`Date: ${new Date(invoice.createdAt).toLocaleDateString()}`, 400, 40, { align: "right" });
      
      doc.fillColor(secondaryColor)
         .fontSize(10)
         .text(`Status: ${invoice.status.toUpperCase()}`, 400, 55, { align: "right" });

      doc.y = 110;

      // Bill To
      doc.fillColor(primaryColor)
         .fontSize(14)
         .font("Helvetica-Bold")
         .text("Bill To", 50, doc.y);
      
      doc.y += 5;
      
      doc.fillColor(secondaryColor)
         .fontSize(11)
         .font("Helvetica")
         .text(customer.name || "Customer", 50, doc.y);
      
      doc.y += 5;
      
      if (customer.email) {
        doc.fillColor(secondaryColor)
           .fontSize(10)
           .text(customer.email, 50, doc.y);
        doc.y += 5;
      }
      
      if (customer.phone) {
        doc.fillColor(secondaryColor)
           .fontSize(10)
           .text(customer.phone, 50, doc.y);
        doc.y += 5;
      }
      
      if (customer.address) {
        doc.fillColor(secondaryColor)
           .fontSize(10)
           .text(customer.address, 50, doc.y);
      }

      // Company Info
      const companyY = 110;
      doc.fillColor(primaryColor)
         .fontSize(14)
         .font("Helvetica-Bold")
         .text("From", 400, companyY);
      
      doc.y = companyY + 5;
      
      doc.fillColor(secondaryColor)
         .fontSize(11)
         .font("Helvetica")
         .text(company.name, 400, doc.y);
      
      doc.y += 5;
      
      if (company.address) {
        doc.fillColor(secondaryColor)
           .fontSize(10)
           .text(company.address, 400, doc.y);
        doc.y += 5;
      }
      
      if (company.email) {
        doc.fillColor(secondaryColor)
           .fontSize(10)
           .text(company.email, 400, doc.y);
        doc.y += 5;
      }
      
      if (company.phone) {
        doc.fillColor(secondaryColor)
           .fontSize(10)
           .text(company.phone, 400, doc.y);
      }

      doc.y += 30;

      // Payment Details
      doc.rect(50, doc.y, 495, 40).fill(lightGray);
      doc.fillColor(primaryColor)
         .fontSize(12)
         .font("Helvetica-Bold")
         .text("Payment Details", 65, doc.y + 12);
      
      doc.y += 50;

      doc.fillColor(secondaryColor)
         .fontSize(10)
         .font("Helvetica")
         .text(`Transaction ID: ${payment.transaction_id || "N/A"}`, 50, doc.y);
      
      doc.y += 5;
      
      doc.fillColor(secondaryColor)
         .fontSize(10)
         .text(`Payment Method: ${payment.payment_method || "Card"}`, 50, doc.y);
      
      doc.y += 5;
      
      doc.fillColor(secondaryColor)
         .fontSize(10)
         .text(`Payment Date: ${payment.payment_date ? new Date(payment.payment_date).toLocaleString() : "N/A"}`, 50, doc.y);

      doc.y += 30;

      // Items table
      const tableTop = doc.y;
      const tableWidth = 495;
      const col1 = 50;
      const col2 = 300;
      const col3 = 400;
      const col4 = 500;

      doc.rect(col1, tableTop, tableWidth, 30).fill(lightGray);
      
      doc.fillColor(primaryColor)
         .fontSize(10)
         .font("Helvetica-Bold")
         .text("Description", col1 + 10, tableTop + 10);
      
      doc.fillColor(primaryColor)
         .text("Quantity", col2, tableTop + 10);
      
      doc.fillColor(primaryColor)
         .text("Unit Price", col3, tableTop + 10);
      
      doc.fillColor(primaryColor)
         .text("Total", col4 - 40, tableTop + 10);

      doc.y = tableTop + 40;

      items.forEach((item, index) => {
        const y = tableTop + 40 + (index * 25);
        
        doc.fillColor(secondaryColor)
           .fontSize(10)
           .font("Helvetica")
           .text(item.description, col1 + 10, y);
        
        doc.fillColor(secondaryColor)
           .text(item.quantity.toString(), col2, y);
        
        doc.fillColor(secondaryColor)
           .text(`${payment.currency} ${item.unit_price.toFixed(2)}`, col3, y);
        
        doc.fillColor(secondaryColor)
           .text(`${payment.currency} ${item.total.toFixed(2)}`, col4 - 40, y);
      });

      doc.y = tableTop + 40 + (items.length * 25) + 20;

      // Check if we need a new page for totals
      if (doc.y > 650) {
        doc.addPage();
        doc.y = 50;
      }

      // Totals
      const totalsX = 350;
      
      // Ensure totals object exists
      const safeTotals = totals || {
        subtotal: 0,
        tax_rate: 0.19,
        tax_amount: 0,
        total: 0,
        currency: payment.currency || 'TND'
      };
      
      doc.fillColor(secondaryColor)
         .fontSize(10)
         .font("Helvetica")
         .text("Subtotal:", totalsX, doc.y);
      
      doc.fillColor(secondaryColor)
         .text(`${payment.currency} ${safeTotals.subtotal.toFixed(2)}`, 500, doc.y, { align: "right" });
      
      doc.y += 15;
      
      doc.fillColor(secondaryColor)
         .text(`VAT (${(safeTotals.tax_rate * 100).toFixed(0)}%):`, totalsX, doc.y);
      
      doc.fillColor(secondaryColor)
         .text(`${payment.currency} ${safeTotals.tax_amount.toFixed(2)}`, 500, doc.y, { align: "right" });
      
      doc.y += 20;
      
      doc.rect(totalsX - 10, doc.y, 165, 30).fill(primaryColor);
      
      doc.fillColor("white")
         .fontSize(12)
         .font("Helvetica-Bold")
         .text("TOTAL:", totalsX, doc.y + 8);
      
      doc.fillColor("white")
         .text(`${payment.currency} ${safeTotals.total.toFixed(2)}`, 500, doc.y + 8, { align: "right" });

      doc.y += 50;

      // Footer
      doc.fillColor(secondaryColor)
         .fontSize(9)
         .font("Helvetica")
         .text("Thank you for your business!", 50, doc.y, { align: "center" });
      
      doc.y += 10;
      
      doc.fillColor(secondaryColor)
         .fontSize(8)
         .text("This is a computer-generated invoice and does not require a signature.", 50, doc.y, { align: "center" });

      doc.end();
    } catch (error) {
      reject(error);
    }
  });
}

/**
 * Generate HTML email content for invoice
 */
function generateInvoiceEmailHTML(invoice) {
  const details = invoice.invoice_details;
  const company = details.company;
  const customer = details.customer;
  const totals = details.totals;

  return `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Invoice ${invoice.invoice_number}</title>
      <style>
        body {
          font-family: Arial, sans-serif;
          line-height: 1.6;
          color: #333;
          max-width: 600px;
          margin: 0 auto;
          padding: 20px;
        }
        .header {
          background: linear-gradient(135deg, #0066CC 0%, #004D99 100%);
          color: white;
          padding: 30px;
          border-radius: 10px 10px 0 0;
          text-align: center;
        }
        .content {
          background: #f9fafb;
          padding: 30px;
          border-radius: 0 0 10px 10px;
        }
        .invoice-details {
          background: white;
          padding: 20px;
          border-radius: 8px;
          margin: 20px 0;
          box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .total {
          font-size: 24px;
          font-weight: bold;
          color: #0F766E;
          text-align: right;
          margin-top: 20px;
        }
        .button {
          display: inline-block;
          background: #0F766E;
          color: white;
          padding: 12px 30px;
          text-decoration: none;
          border-radius: 5px;
          margin-top: 20px;
        }
        .footer {
          text-align: center;
          margin-top: 30px;
          color: #64748B;
          font-size: 12px;
        }
      </style>
    </head>
    <body>
      <div class="header">
        <h1>🧾 Invoice ${invoice.invoice_number}</h1>
        <p>Thank you for your payment!</p>
      </div>
      
      <div class="content">
        <p>Hello ${customer.name || "Customer"},</p>
        
        <p>Your payment has been processed successfully. Please find your invoice attached to this email.</p>
        
        <div class="invoice-details">
          <h3>Invoice Summary</h3>
          <p><strong>Invoice Number:</strong> ${invoice.invoice_number}</p>
          <p><strong>Date:</strong> ${new Date(invoice.createdAt).toLocaleDateString()}</p>
          <p><strong>Status:</strong> ${invoice.status.toUpperCase()}</p>
          <hr>
          <p><strong>Total Amount:</strong> ${totals.currency || 'TND'} ${totals.total.toFixed(2)}</p>
        </div>
        
        <p>If you have any questions about this invoice, please don't hesitate to contact us.</p>
        
        <div class="total">
          Total: ${totals.currency || 'TND'} ${totals.total.toFixed(2)}
        </div>
      </div>
      
      <div class="footer">
        <p>${company.name} | ${company.address || 'Djerba, Tunisia'}</p>
        <p>${company.email || 'contact@djtrip.com'}</p>
        <p>This is an automated email. Please do not reply.</p>
      </div>
    </body>
    </html>
  `;
}

/**
 * Delete invoice (admin only)
 * DELETE /api/invoice/:invoiceId
 */
exports.deleteInvoice = async (req, res) => {
  try {
    const { invoiceId } = req.params;

    const invoice = await Invoice.findByIdAndDelete(invoiceId);

    if (!invoice) {
      return res.status(404).json({
        success: false,
        message: "Invoice not found",
      });
    }

    res.status(200).json({
      success: true,
      message: "Invoice deleted successfully",
    });
  } catch (error) {
    console.error("Error deleting invoice:", error);
    res.status(500).json({
      success: false,
      message: "Error deleting invoice",
      error: error.message,
    });
  }
};

