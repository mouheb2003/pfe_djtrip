const nodemailer = require("nodemailer");

const NODE_ENV = (process.env.NODE_ENV || "development").toLowerCase();
const EMAIL_SERVICE = (
  process.env.EMAIL_PROVIDER ||
  process.env.EMAIL_SERVICE ||
  "gmail"
)
  .trim()
  .toLowerCase();
const EMAIL_USER = (process.env.EMAIL_USER || "").trim();
const EMAIL_PASSWORD = (process.env.EMAIL_PASSWORD || "").trim();
const EMAIL_HOST = (process.env.EMAIL_HOST || "").trim();
const EMAIL_FROM = (
  process.env.EMAIL_FROM ||
  EMAIL_USER ||
  "noreply@djtrip.com"
).trim();
const EMAIL_FROM_NAME = (process.env.EMAIL_FROM_NAME || "DJTrip").trim();
const EMAIL_REPLY_TO = (process.env.EMAIL_REPLY_TO || EMAIL_FROM).trim();
const EMAIL_PORT = Number(
  process.env.EMAIL_PORT ||
    (EMAIL_HOST || EMAIL_SERVICE === "gmail" ? 465 : 587),
);
const EMAIL_SECURE =
  process.env.EMAIL_SECURE != null
    ? ["true", "1", "yes"].includes(process.env.EMAIL_SECURE.toLowerCase())
    : EMAIL_PORT === 465;

function maskEmail(email) {
  if (!email || typeof email !== "string") return "-";

  const [localPart, domainPart] = email.split("@");
  if (!localPart || !domainPart) return "***";

  return `${localPart.slice(0, 2)}***@${domainPart}`;
}

function emailLog(level, message, meta = {}) {
  const payload = Object.keys(meta).length ? ` ${JSON.stringify(meta)}` : "";
  const line = `[email] ${message}${payload}`;

  if (level === "error") return console.error(line);
  if (level === "warn") return console.warn(line);
  return console.info(line);
}

function getFromAddress() {
  return EMAIL_FROM_NAME ? `${EMAIL_FROM_NAME} <${EMAIL_FROM}>` : EMAIL_FROM;
}

function buildTransportConfig() {
  const isProduction = NODE_ENV === "production";
  
  return {
    host: EMAIL_HOST || "smtp.gmail.com",
    port: EMAIL_PORT,
    secure: EMAIL_SECURE,
    requireTLS: !EMAIL_SECURE,
    auth: {
      user: EMAIL_USER,
      pass: EMAIL_PASSWORD,
    },
    // Force IPv4 to avoid IPv6 connection errors (ENETUNREACH)
    family: 4,
    connectionTimeout: isProduction ? 15000 : 10000,
    greetingTimeout: isProduction ? 15000 : 10000,
    socketTimeout: isProduction ? 15000 : 10000,
    // Add DNS options to prioritize IPv4
    dns: {
      family: 4,
    },
  };
}

const transporter = nodemailer.createTransport(buildTransportConfig());

const transporterReady = transporter
  .verify()
  .then(() => {
    emailLog("info", "SMTP transporter verified", {
      provider: EMAIL_SERVICE,
      host:
        EMAIL_HOST ||
        (EMAIL_SERVICE === "gmail" ? "smtp.gmail.com" : EMAIL_SERVICE),
      port: EMAIL_PORT,
      secure: EMAIL_SECURE,
      from: maskEmail(EMAIL_FROM),
    });
    return true;
  })
  .catch((error) => {
    emailLog("error", "SMTP verification failed", {
      message: error.message,
      code: error.code,
      response: error.response,
    });
    return false;
  });

async function ensureTransporterReady() {
  await transporterReady;
}

async function sendMailWithLogging(context, mailOptions) {
  await ensureTransporterReady();

  const startedAt = Date.now();
  emailLog("info", `Sending ${context}`, {
    to: Array.isArray(mailOptions.to)
      ? mailOptions.to.map((value) => maskEmail(value))
      : maskEmail(mailOptions.to),
    subject: mailOptions.subject,
  });

  try {
    const info = await transporter.sendMail(mailOptions);

    emailLog("info", `Sent ${context}`, {
      messageId: info.messageId,
      accepted: info.accepted,
      rejected: info.rejected,
      durationMs: Date.now() - startedAt,
    });

    return info;
  } catch (error) {
    emailLog("error", `Failed ${context}`, {
      message: error.message,
      code: error.code,
      command: error.command,
      response: error.response,
      responseCode: error.responseCode,
      durationMs: Date.now() - startedAt,
    });
    throw error;
  }
}

function getBaseMailOptions({ to, subject, html, text, attachments = [] }) {
  return {
    from: getFromAddress(),
    replyTo: EMAIL_REPLY_TO,
    to,
    subject,
    html,
    text,
    attachments,
  };
}

emailLog("info", "Email service initialized", {
  env: NODE_ENV,
  provider: EMAIL_SERVICE,
  host: EMAIL_HOST || "smtp.gmail.com",
  port: EMAIL_PORT,
  secure: EMAIL_SECURE,
  from: maskEmail(EMAIL_FROM),
  hasUser: Boolean(EMAIL_USER),
  hasPassword: Boolean(EMAIL_PASSWORD),
});

if (NODE_ENV === "production" && (!EMAIL_USER || !EMAIL_PASSWORD)) {
  emailLog("warn", "Production email credentials are missing or incomplete.", {
    hasUser: Boolean(EMAIL_USER),
    hasPassword: Boolean(EMAIL_PASSWORD),
  });
}

if (NODE_ENV === "production" && EMAIL_SERVICE === "gmail") {
  emailLog(
    "warn",
    "Gmail SMTP is less reliable for production than SendGrid, Mailgun, or Resend.",
  );
}

exports.getEmailConfigStatus = () => ({
  env: NODE_ENV,
  provider: EMAIL_SERVICE,
  host: EMAIL_HOST || "smtp.gmail.com",
  port: EMAIL_PORT,
  secure: EMAIL_SECURE,
  from: getFromAddress(),
  replyTo: EMAIL_REPLY_TO,
  hasUser: Boolean(EMAIL_USER),
  hasPassword: Boolean(EMAIL_PASSWORD),
});

exports.verifyEmailTransport = async () => {
  await ensureTransporterReady();
  return {
    success: true,
    config: exports.getEmailConfigStatus(),
  };
};

exports.sendTestEmail = async ({
  to,
  fullname = "Test User",
  subject,
  message,
}) => {
  if (!to) {
    throw new Error("Recipient email is required for the test email");
  }

  const mailOptions = getBaseMailOptions({
    to,
    subject: subject || "DJTrip email test",
    html: `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
      </head>
      <body style="font-family: Arial, sans-serif; color: #1f2937; line-height: 1.6;">
        <div style="max-width: 600px; margin: 0 auto; padding: 24px; border: 1px solid #e5e7eb; border-radius: 16px;">
          <h1 style="margin-top: 0; color: #ff6b1a;">DJTrip email test</h1>
          <p>Hello ${fullname},</p>
          <p>${message || "This is a test email sent from the DJTrip production backend."}</p>
          <p style="color: #6b7280; font-size: 13px;">If you received this email, the SMTP configuration is working.</p>
        </div>
      </body>
      </html>
    `,
    text: `Hello ${fullname},\n\n${message || "This is a test email sent from the DJTrip production backend."}\n\nIf you received this email, the SMTP configuration is working.`,
  });

  const info = await sendMailWithLogging("test email", mailOptions);
  return { success: true, messageId: info.messageId };
};

// Generate a 6-digit verification code
exports.generateVerificationCode = () => {
  return Math.floor(100000 + Math.random() * 900000).toString();
};

// Send verification email
exports.sendVerificationEmail = async (email, code, fullname) => {
  try {
    const mailOptions = getBaseMailOptions({
      to: email,
      subject: "Verify your email - DJTrip",
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <style>
            body {
              font-family: Arial, sans-serif;
              line-height: 1.6;
              color: #333;
            }
            .container {
              max-width: 600px;
              margin: 0 auto;
              padding: 20px;
            }
            .header {
              background-color: #FF6B1A;
              color: white;
              padding: 20px;
              text-align: center;
              border-radius: 10px 10px 0 0;
            }
            .content {
              background-color: #f9f9f9;
              padding: 30px;
              border-radius: 0 0 10px 10px;
            }
            .code {
              background-color: white;
              border: 2px solid #FF6B1A;
              padding: 20px;
              text-align: center;
              font-size: 32px;
              font-weight: bold;
              letter-spacing: 8px;
              margin: 20px 0;
              border-radius: 8px;
              color: #FF6B1A;
            }
            .footer {
              text-align: center;
              margin-top: 20px;
              color: #666;
              font-size: 12px;
            }
            .button {
              display: inline-block;
              padding: 12px 30px;
              background-color: #FF6B1A;
              color: white;
              text-decoration: none;
              border-radius: 5px;
              margin: 20px 0;
            }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1>Welcome to DJTrip!</h1>
            </div>
            <div class="content">
              <h2>Hello ${fullname},</h2>
              <p>Thank you for registering with DJTrip. To complete your registration, please verify your email address.</p>
              
              <p>Your verification code is:</p>
              
              <div class="code">${code}</div>
              
              <p>This code will expire in <strong>15 minutes</strong>.</p>
              
              <p>If you didn't create an account with DJTrip, please ignore this email.</p>
              
              <div style="margin-top: 30px; padding: 15px; background-color: #e8f4f8; border-left: 4px solid #3498db; border-radius: 4px;">
                <p style="margin: 0;"><strong>Security tip:</strong> Never share this code with anyone. Travelo will never ask for your verification code.</p>
              </div>
            </div>
            <div class="footer">
              <p>© 2026 DJTrip. All rights reserved.</p>
              <p>This is an automated email, please do not reply.</p>
            </div>
          </div>
        </body>
        </html>
      `,
      text: `Hello ${fullname},\n\nThank you for registering with DJTrip. Your verification code is: ${code}\n\nThis code will expire in 15 minutes.\n\nIf you didn't create an account with DJTrip, please ignore this email.\n\n© 2026 DJTrip. All rights reserved.`,
    });

    const info = await sendMailWithLogging("verification email", mailOptions);
    return { success: true, messageId: info.messageId };
  } catch (error) {
    emailLog("error", "Error sending verification email", {
      message: error.message,
      code: error.code,
    });
    return { success: false, error: error.message };
  }
};

// Send welcome email after verification
exports.sendWelcomeEmail = async (email, fullname) => {
  try {
    const mailOptions = getBaseMailOptions({
      to: email,
      subject: "Welcome to DJTrip!",
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <style>
            body {
              font-family: Arial, sans-serif;
              line-height: 1.6;
              color: #333;
            }
            .container {
              max-width: 600px;
              margin: 0 auto;
              padding: 20px;
            }
            .header {
              background-color: #FF6B1A;
              color: white;
              padding: 30px;
              text-align: center;
              border-radius: 10px;
            }
            .content {
              padding: 30px 0;
            }
            .footer {
              text-align: center;
              margin-top: 20px;
              color: #666;
              font-size: 12px;
            }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1>🎉 Welcome to DJTrip!</h1>
            </div>
            <div class="content">
              <h2>Hello ${fullname},</h2>
              <p>Your email has been successfully verified!</p>
              <p>You're now ready to explore amazing travel experiences and connect with fellow travelers.</p>
              <p>Start your journey today!</p>
            </div>
            <div class="footer">
              <p>© 2026 DJTrip. All rights reserved.</p>
            </div>
          </div>
        </body>
        </html>
      `,
    });

    const info = await sendMailWithLogging("welcome email", mailOptions);
    return { success: true, messageId: info.messageId };
  } catch (error) {
    emailLog("error", "Error sending welcome email", {
      message: error.message,
      code: error.code,
    });
    return { success: false, error: error.message };
  }
};

// Send booking confirmation email with QR code
exports.sendBookingConfirmationEmail = async ({
  email,
  fullname,
  bookingCode,
  activityTitle,
  bookingDate,
  bookingTime,
  participants,
  totalPrice,
  qrDataUrl,
}) => {
  try {
    const qrAttachment = (() => {
      if (!qrDataUrl) return null;
      const match = qrDataUrl.match(
        /^data:(image\/(?:png|jpeg|jpg));base64,(.+)$/i,
      );
      if (!match) return null;

      const mimeType =
        match[1].toLowerCase() === "image/jpg"
          ? "image/jpeg"
          : match[1].toLowerCase();
      const base64Data = match[2];
      return {
        filename: "booking-qr.png",
        content: Buffer.from(base64Data, "base64"),
        cid: "booking-qr-code",
        contentType: mimeType,
      };
    })();

    const mailOptions = getBaseMailOptions({
      to: email,
      subject: "Your booking is confirmed - DJTrip",
      attachments: qrAttachment ? [qrAttachment] : [],
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <style>
            body { font-family: Arial, sans-serif; background:#f7f9fc; color:#1e293b; }
            .container { max-width: 680px; margin: 0 auto; padding: 24px; }
            .card { background:#fff; border-radius:20px; overflow:hidden; box-shadow:0 10px 30px rgba(15,23,42,.08); }
            .header { background: linear-gradient(135deg, #1d4ed8, #4f6bff); color:#fff; padding: 28px; }
            .content { padding: 28px; }
            .qr { text-align:center; padding: 18px; border:1px solid #e2e8f0; border-radius:16px; background:#f8fbff; }
            .meta { margin: 18px 0; padding: 16px; background:#f8fafc; border-radius:16px; }
            .meta p { margin: 6px 0; }
            .code { font-weight:700; letter-spacing:1px; color:#1d4ed8; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="card">
              <div class="header">
                <h1 style="margin:0; font-size:24px;">Booking Confirmed</h1>
                <p style="margin:8px 0 0; opacity:.92;">Hello ${fullname}, your booking is approved.</p>
              </div>
              <div class="content">
                <p>Keep this QR code for check-in at the activity.</p>
                ${qrAttachment ? `<div class="qr"><img src="cid:booking-qr-code" alt="Booking QR code" width="220" height="220" /></div>` : ""}
                <div class="meta">
                  <p><strong>Activity:</strong> ${activityTitle}</p>
                  <p><strong>Date:</strong> ${bookingDate}</p>
                  <p><strong>Time:</strong> ${bookingTime}</p>
                  <p><strong>Participants:</strong> ${participants}</p>
                  <p><strong>Total:</strong> ${totalPrice}</p>
                  <p><strong>Booking code:</strong> <span class="code">${bookingCode}</span></p>
                </div>
                <p>If you need help, open the Help Center inside the app.</p>
              </div>
            </div>
          </div>
        </body>
        </html>
      `,
      text: `Hello ${fullname},\n\nYour booking is confirmed.\n\nActivity: ${activityTitle}\nDate: ${bookingDate}\nTime: ${bookingTime}\nParticipants: ${participants}\nTotal: ${totalPrice}\nBooking code: ${bookingCode}\n\nOpen the app and present your QR code at check-in.`,
    });

    const info = await sendMailWithLogging(
      "booking confirmation email",
      mailOptions,
    );
    return { success: true, messageId: info.messageId };
  } catch (error) {
    emailLog("error", "Error sending booking confirmation email", {
      message: error.message,
      code: error.code,
    });
    return { success: false, error: error.message };
  }
};

// Send password reset email
exports.sendPasswordResetEmail = async (email, code, fullname) => {
  try {
    const mailOptions = getBaseMailOptions({
      to: email,
      subject: "Reset Your Password - DJTrip",
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <style>
            body {
              font-family: Arial, sans-serif;
              line-height: 1.6;
              color: #333;
            }
            .container {
              max-width: 600px;
              margin: 0 auto;
              padding: 20px;
            }
            .header {
              background-color: #2D5016;
              color: white;
              padding: 20px;
              text-align: center;
              border-radius: 10px 10px 0 0;
            }
            .content {
              background-color: #f9f9f9;
              padding: 30px;
              border-radius: 0 0 10px 10px;
            }
            .code {
              background-color: white;
              border: 2px solid #2D5016;
              padding: 20px;
              text-align: center;
              font-size: 32px;
              font-weight: bold;
              letter-spacing: 8px;
              margin: 20px 0;
              border-radius: 8px;
              color: #2D5016;
            }
            .footer {
              text-align: center;
              margin-top: 20px;
              color: #666;
              font-size: 12px;
            }
            .warning {
              margin-top: 30px;
              padding: 15px;
              background-color: #fff3cd;
              border-left: 4px solid #ffc107;
              border-radius: 4px;
            }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1>🔐 Password Reset Request</h1>
            </div>
            <div class="content">
              <h2>Hello ${fullname},</h2>
              <p>We received a request to reset your DJTrip password.</p>
              
              <p>Your password reset code is:</p>
              
              <div class="code">${code}</div>
              
              <p>This code will expire in <strong>15 minutes</strong>.</p>
              
              <div class="warning">
                <p style="margin: 0;"><strong>⚠️ Security Notice:</strong> If you didn't request a password reset, please ignore this email or contact our support team if you have concerns about your account security.</p>
              </div>
              
              <p style="margin-top: 20px;">Never share this code with anyone. DJTrip will never ask for your reset code.</p>
            </div>
            <div class="footer">
              <p>© 2026 DJTrip. All rights reserved.</p>
              <p>This is an automated email, please do not reply.</p>
            </div>
          </div>
        </body>
        </html>
      `,
      text: `Hello ${fullname},\n\nWe received a request to reset your DJTrip password.\n\nYour password reset code is: ${code}\n\nThis code will expire in 15 minutes.\n\nIf you didn't request a password reset, please ignore this email.\n\n© 2026 DJTrip. All rights reserved.`,
    });

    const info = await sendMailWithLogging("password reset email", mailOptions);
    return { success: true, messageId: info.messageId };
  } catch (error) {
    emailLog("error", "Error sending password reset email", {
      message: error.message,
      code: error.code,
    });
    return { success: false, error: error.message };
  }
};

// Send ban notification email
exports.sendBanNotification = async (email, fullname, reason) => {
  try {
    const mailOptions = getBaseMailOptions({
      to: email,
      subject: "Account Banned - DJTrip",
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <style>
            body {
              font-family: Arial, sans-serif;
              line-height: 1.6;
              color: #333;
            }
            .container {
              max-width: 600px;
              margin: 0 auto;
              padding: 20px;
            }
            .header {
              background-color: #d32f2f;
              color: white;
              padding: 20px;
              text-align: center;
              border-radius: 10px 10px 0 0;
            }
            .content {
              background-color: #f9f9f9;
              padding: 30px;
              border-radius: 0 0 10px 10px;
            }
            .reason-box {
              background-color: white;
              border: 2px solid #d32f2f;
              padding: 20px;
              margin: 20px 0;
              border-radius: 8px;
              border-left: 4px solid #d32f2f;
            }
            .footer {
              text-align: center;
              margin-top: 20px;
              color: #666;
              font-size: 12px;
            }
            .appeal-section {
              margin-top: 20px;
              padding: 15px;
              background-color: #e3f2fd;
              border-left: 4px solid #1976d2;
              border-radius: 4px;
            }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1>⛔ Account Banned</h1>
            </div>
            <div class="content">
              <h2>Hello ${fullname},</h2>
              <p>We regret to inform you that your DJTrip account has been banned effective immediately.</p>
              
              <p><strong>Reason for ban:</strong></p>
              <div class="reason-box">
                <p>${reason}</p>
              </div>
              
              <p>This means you will no longer be able to access your account or use our services.</p>
              
              <div class="appeal-section">
                <p><strong>Appeal Process:</strong></p>
                <p>If you believe this action was taken in error, you may appeal by contacting our support team at support@djtrip.com with your account details and an explanation.</p>
              </div>
              
              <p style="margin-top: 20px;">For more information about our community guidelines and policies, please visit our website.</p>
            </div>
            <div class="footer">
              <p>© 2026 DJTrip. All rights reserved.</p>
              <p>This is an automated email, please do not reply.</p>
            </div>
          </div>
        </body>
        </html>
      `,
      text: `Hello ${fullname},\n\nWe regret to inform you that your DJTrip account has been banned effective immediately.\n\nReason for ban:\n${reason}\n\nYou will no longer be able to access your account or use our services.\n\nIf you believe this action was taken in error, you may appeal by contacting our support team at support@djtrip.com.\n\n© 2026 DJTrip. All rights reserved.`,
    });

    const info = await sendMailWithLogging(
      "ban notification email",
      mailOptions,
    );
    return { success: true, messageId: info.messageId };
  } catch (error) {
    emailLog("error", "Error sending ban notification email", {
      message: error.message,
      code: error.code,
    });
    return { success: false, error: error.message };
  }
};

// Send account restoration email when a suspension/ban is lifted
exports.sendAccountRestoredEmail = async (
  email,
  fullname,
  previousStatus,
  previousReason,
) => {
  try {
    const normalizedStatus =
      (previousStatus || "").toString().trim().toLowerCase() || "restricted";
    const statusLabel = normalizedStatus === "banned" ? "ban" : "suspension";
    const reasonText = (previousReason || "").toString().trim();

    const mailOptions = getBaseMailOptions({
      to: email,
      subject: "Your DJTrip account is active again",
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background-color: #1b9c53; color: white; padding: 20px; text-align: center; border-radius: 10px 10px 0 0; }
            .content { background-color: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px; }
            .reason-box { background-color: white; border: 1px solid #d1fae5; padding: 14px; margin: 16px 0; border-radius: 8px; }
            .footer { text-align: center; margin-top: 20px; color: #666; font-size: 12px; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1>✅ Account Restored</h1>
            </div>
            <div class="content">
              <h2>Hello ${fullname},</h2>
              <p>Your DJTrip account has been reactivated. You can now sign in and use the app again.</p>
              <p><strong>Previous restriction:</strong> ${statusLabel}</p>
              ${reasonText ? `<div class="reason-box"><p style="margin:0;"><strong>Reason shown previously:</strong> ${reasonText}</p></div>` : ""}
              <p>If you still face access issues, please contact support@djtrip.com.</p>
            </div>
            <div class="footer">
              <p>© 2026 DJTrip. All rights reserved.</p>
              <p>This is an automated email, please do not reply.</p>
            </div>
          </div>
        </body>
        </html>
      `,
      text: `Hello ${fullname},\n\nYour DJTrip account has been reactivated. You can now sign in again.\n\nPrevious restriction: ${statusLabel}${reasonText ? `\nReason shown previously: ${reasonText}` : ""}\n\nIf you still face access issues, contact support@djtrip.com.\n\n© 2026 DJTrip. All rights reserved.`,
    });

    const info = await sendMailWithLogging(
      "account restored email",
      mailOptions,
    );
    return { success: true, messageId: info.messageId };
  } catch (error) {
    emailLog("error", "Error sending account restored email", {
      message: error.message,
      code: error.code,
    });
    return { success: false, error: error.message };
  }
};

// Send suspension notification email
exports.sendSuspensionNotification = async (
  email,
  fullname,
  reason,
  suspendedUntil,
) => {
  try {
    const suspendedUntilText = suspendedUntil
      ? new Date(suspendedUntil).toLocaleString("fr-FR")
      : "jusqu'à nouvelle décision";

    const mailOptions = getBaseMailOptions({
      to: email,
      subject: "Account Suspended - DJTrip",
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background-color: #f57c00; color: white; padding: 20px; text-align: center; border-radius: 10px 10px 0 0; }
            .content { background-color: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px; }
            .reason-box { background-color: white; border: 2px solid #f57c00; padding: 20px; margin: 20px 0; border-radius: 8px; border-left: 4px solid #f57c00; }
            .footer { text-align: center; margin-top: 20px; color: #666; font-size: 12px; }
            .info-box { margin-top: 20px; padding: 15px; background-color: #fff3e0; border-left: 4px solid #f57c00; border-radius: 4px; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1>⏸ Account Suspended</h1>
            </div>
            <div class="content">
              <h2>Hello ${fullname},</h2>
              <p>Your DJTrip account has been suspended.</p>
              <p><strong>Suspension reason:</strong></p>
              <div class="reason-box"><p>${reason}</p></div>
              <p><strong>Suspended until:</strong> ${suspendedUntilText}</p>
              <div class="info-box">
                <p style="margin: 0;">If you need help, contact support@djtrip.com.</p>
              </div>
            </div>
            <div class="footer">
              <p>© 2026 DJTrip. All rights reserved.</p>
              <p>This is an automated email, please do not reply.</p>
            </div>
          </div>
        </body>
        </html>
      `,
      text: `Hello ${fullname},\n\nYour DJTrip account has been suspended.\n\nSuspension reason: ${reason}\nSuspended until: ${suspendedUntilText}\n\nIf you need help, contact support@djtrip.com.\n\n© 2026 DJTrip. All rights reserved.`,
    });

    const info = await sendMailWithLogging(
      "suspension notification email",
      mailOptions,
    );
    return { success: true, messageId: info.messageId };
  } catch (error) {
    emailLog("error", "Error sending suspension notification email", {
      message: error.message,
      code: error.code,
    });
    return { success: false, error: error.message };
  }
};
