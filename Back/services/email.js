const nodemailer = require("nodemailer");

// Email transporter configuration
// For development, you can use Gmail or other email services
// For production, use a proper email service like SendGrid, Mailgun, etc.
const transporter = nodemailer.createTransport({
  service: process.env.EMAIL_SERVICE || "gmail",
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASSWORD,
  },
  // Add timeout configurations
  connectionTimeout: 10000, // 10 seconds
  greetingTimeout: 10000, // 10 seconds
  socketTimeout: 10000, // 10 seconds
});

// Generate a 6-digit verification code
exports.generateVerificationCode = () => {
  return Math.floor(100000 + Math.random() * 900000).toString();
};

// Send verification email
exports.sendVerificationEmail = async (email, code, fullname) => {
  try {
    const mailOptions = {
      from: process.env.EMAIL_USER || "noreply@DJTrip.com",
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
    };

    const info = await transporter.sendMail(mailOptions);
    console.log("Verification email sent:", info.messageId);
    return { success: true, messageId: info.messageId };
  } catch (error) {
    console.error("Error sending verification email:", error);
    return { success: false, error: error.message };
  }
};

// Send welcome email after verification
exports.sendWelcomeEmail = async (email, fullname) => {
  try {
    const mailOptions = {
      from: process.env.EMAIL_USER || "noreply@djtrip.com",
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
    };

    const info = await transporter.sendMail(mailOptions);
    console.log("Welcome email sent:", info.messageId);
    return { success: true, messageId: info.messageId };
  } catch (error) {
    console.error("Error sending welcome email:", error);
    return { success: false, error: error.message };
  }
};

// Send password reset email
exports.sendPasswordResetEmail = async (email, code, fullname) => {
  try {
    const mailOptions = {
      from: process.env.EMAIL_USER || "noreply@DJTrip.com",
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
    };

    const info = await transporter.sendMail(mailOptions);
    console.log("Password reset email sent:", info.messageId);
    return { success: true, messageId: info.messageId };
  } catch (error) {
    console.error("Error sending password reset email:", error);
    return { success: false, error: error.message };
  }
};

// Send ban notification email
exports.sendBanNotification = async (email, fullname, reason) => {
  try {
    const mailOptions = {
      from: process.env.EMAIL_USER || "noreply@DJTrip.com",
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
              <h1>⛔ Account Suspended</h1>
            </div>
            <div class="content">
              <h2>Hello ${fullname},</h2>
              <p>We regret to inform you that your DJTrip account has been suspended effective immediately.</p>
              
              <p><strong>Reason for suspension:</strong></p>
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
      text: `Hello ${fullname},\n\nWe regret to inform you that your DJTrip account has been suspended effective immediately.\n\nReason for suspension:\n${reason}\n\nYou will no longer be able to access your account or use our services.\n\nIf you believe this action was taken in error, you may appeal by contacting our support team at support@djtrip.com.\n\n© 2026 DJTrip. All rights reserved.`,
    };

    const info = await transporter.sendMail(mailOptions);
    console.log("Ban notification email sent:", info.messageId);
    return { success: true, messageId: info.messageId };
  } catch (error) {
    console.error("Error sending ban notification email:", error);
    return { success: false, error: error.message };
  }
};

// Send suspension notification email
exports.sendSuspensionNotification = async (email, fullname, reason, suspendedUntil) => {
  try {
    const suspendedUntilText = suspendedUntil
      ? new Date(suspendedUntil).toLocaleString("fr-FR")
      : "jusqu'à nouvelle décision";

    const mailOptions = {
      from: process.env.EMAIL_USER || "noreply@DJTrip.com",
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
    };

    const info = await transporter.sendMail(mailOptions);
    console.log("Suspension notification email sent:", info.messageId);
    return { success: true, messageId: info.messageId };
  } catch (error) {
    console.error("Error sending suspension notification email:", error);
    return { success: false, error: error.message };
  }
};
