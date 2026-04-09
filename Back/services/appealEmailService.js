const nodemailer = require("nodemailer");

// Email transporter configuration
const EMAIL_PORT = Number(process.env.EMAIL_PORT) || 465;
const EMAIL_SECURE = process.env.EMAIL_SECURE === "true" || EMAIL_PORT === 465;

const transporter = nodemailer.createTransport({
  host: process.env.EMAIL_HOST || "smtp.gmail.com",
  port: EMAIL_PORT,
  secure: EMAIL_SECURE,
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASSWORD,
  },
});

// ─── Helper Functions ───────────────────────────────────────────────────────────────

const sendEmail = async (options) => {
  try {
    const info = await transporter.sendMail({
      from: process.env.EMAIL_FROM || process.env.EMAIL_USER || `"DJTrip Support" <root@localhost>`,
      ...options,
    });
    
    console.log("Email sent successfully:", info.messageId);
    return { success: true, messageId: info.messageId };
  } catch (error) {
    console.error("Email sending failed:", error);
    return { success: false, error: error.message };
  }
};

// ─── Email Templates ───────────────────────────────────────────────────────────────

const adminAppealTemplate = ({ user, appeal, req }) => `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>New Appeal Submitted - DJTrip</title>
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: #4B63FF; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }
        .content { background: #f9f9f9; padding: 30px; border: 1px solid #ddd; border-top: none; border-radius: 0 0 8px 8px; }
        .user-info { background: #e8f5ff; padding: 15px; border-radius: 5px; margin: 20px 0; }
        .appeal-content { background: white; padding: 20px; border-left: 4px solid #4B63FF; margin: 20px 0; }
        .footer { text-align: center; margin-top: 30px; color: #666; font-size: 12px; }
        .btn { display: inline-block; background: #4B63FF; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; margin: 20px 0; }
        .status-badge { display: inline-block; padding: 4px 8px; border-radius: 12px; font-size: 12px; font-weight: bold; }
        .status-banned { background: #ff4757; color: white; }
        .status-suspended { background: #ffa502; color: white; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🚨 New Appeal Submitted</h1>
    </div>
    
    <div class="content">
        <h2>User Information</h2>
        <div class="user-info">
            <p><strong>Name:</strong> ${user.fullname || 'N/A'}</p>
            <p><strong>Email:</strong> ${user.email}</p>
            <p><strong>Account Status:</strong> 
                <span class="status-badge status-${user.accountStatus}">${user.accountStatus.toUpperCase()}</span>
            </p>
            <p><strong>Submitted:</strong> ${new Date(appeal.createdAt).toLocaleString()}</p>
        </div>

        <h2>Appeal Details</h2>
        <div class="appeal-content">
            <p><strong>Subject:</strong> ${appeal.subject}</p>
            <p><strong>Message:</strong></p>
            <div style="background: #f5f5f5; padding: 15px; border-radius: 5px; margin: 10px 0;">
                ${appeal.message.replace(/\n/g, '<br>')}
            </div>
            ${appeal.metadata?.original_ban_reason ? `<p><strong>Original Ban Reason:</strong> ${appeal.metadata.original_ban_reason}</p>` : ''}
            ${appeal.metadata?.original_suspension_reason ? `<p><strong>Original Suspension Reason:</strong> ${appeal.metadata.original_suspension_reason}</p>` : ''}
        </div>

        <h2>Technical Details</h2>
        <div style="background: #f0f0f0; padding: 15px; border-radius: 5px; font-size: 12px;">
            <p><strong>IP Address:</strong> ${appeal.metadata?.ip_address || 'N/A'}</p>
            <p><strong>User Agent:</strong> ${appeal.metadata?.user_agent || 'N/A'}</p>
        </div>

        <div style="text-align: center;">
            <a href="${process.env.ADMIN_DASHBOARD_URL || 'http://localhost:3000/admin'}/appeals" class="btn">
                Review Appeal in Admin Dashboard
            </a>
        </div>
    </div>

    <div class="footer">
        <p>This is an automated notification from DJTrip Support System.</p>
        <p>Please review this appeal as soon as possible.</p>
    </div>
</body>
</html>
`;

const userAppealConfirmationTemplate = ({ user, appeal }) => `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Your Appeal Has Been Received - DJTrip</title>
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: #4B63FF; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }
        .content { background: #f9f9f9; padding: 30px; border: 1px solid #ddd; border-top: none; border-radius: 0 0 8px 8px; }
        .appeal-info { background: #e8f5ff; padding: 20px; border-radius: 5px; margin: 20px 0; }
        .footer { text-align: center; margin-top: 30px; color: #666; font-size: 12px; }
        .status-badge { display: inline-block; padding: 4px 8px; border-radius: 12px; font-size: 12px; font-weight: bold; background: #4B63FF; color: white; }
    </style>
</head>
<body>
    <div class="header">
        <h1>✅ Appeal Received</h1>
    </div>
    
    <div class="content">
        <p>Dear ${user.fullname || 'User'},</p>
        
        <p>Thank you for submitting your appeal. We have received your request and our team will review it shortly.</p>
        
        <div class="appeal-info">
            <h3>Appeal Details</h3>
            <p><strong>Appeal ID:</strong> ${appeal._id}</p>
            <p><strong>Subject:</strong> ${appeal.subject}</p>
            <p><strong>Status:</strong> 
                <span class="status-badge">${appeal.status.toUpperCase()}</span>
            </p>
            <p><strong>Submitted:</strong> ${new Date(appeal.createdAt).toLocaleString()}</p>
        </div>

        <h3>What happens next?</h3>
        <ul>
            <li>Our admin team will review your appeal within 24-48 hours</li>
            <li>You will receive an email notification when a decision is made</li>
            <li>If your appeal is accepted, your account status will be updated accordingly</li>
            <li>You can check the status of your appeal in your account settings</li>
        </ul>

        <h3>Contact Information</h3>
        <p>If you have any questions or need to provide additional information, please contact us at:</p>
        <p><strong>Email:</strong> ${process.env.SUPPORT_EMAIL || 'support@djtrip.com'}</p>

        <div style="background: #fff3cd; border: 1px solid #ffeaa7; padding: 15px; border-radius: 5px; margin: 20px 0;">
            <p><strong>⚠️ Important:</strong> Please do not submit multiple appeals for the same issue, as this may delay the review process.</p>
        </div>
    </div>

    <div class="footer">
        <p>Best regards,<br>DJTrip Support Team</p>
        <p>This is an automated message. Please do not reply to this email.</p>
    </div>
</body>
</html>
`;

const appealDecisionTemplate = ({ user, appeal, status, admin_response }) => {
  const isAccepted = status === "accepted";
  const statusColor = isAccepted ? "#00b894" : "#ff4757";
  const statusIcon = isAccepted ? "✅" : "❌";
  const statusText = isAccepted ? "ACCEPTED" : "REJECTED";

  return `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Appeal Decision - DJTrip</title>
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: ${statusColor}; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }
        .content { background: #f9f9f9; padding: 30px; border: 1px solid #ddd; border-top: none; border-radius: 0 0 8px 8px; }
        .decision-box { background: ${isAccepted ? '#d1f2eb' : '#fadbd8'}; padding: 20px; border-radius: 5px; margin: 20px 0; text-align: center; }
        .admin-response { background: white; padding: 20px; border-left: 4px solid ${statusColor}; margin: 20px 0; }
        .footer { text-align: center; margin-top: 30px; color: #666; font-size: 12px; }
        .btn { display: inline-block; background: #4B63FF; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; margin: 20px 0; }
    </style>
</head>
<body>
    <div class="header">
        <h1>${statusIcon} Appeal ${statusText}</h1>
    </div>
    
    <div class="content">
        <p>Dear ${user.fullname || 'User'},</p>
        
        <div class="decision-box">
            <h3>Your appeal has been ${statusText.toLowerCase()}</h3>
            ${isAccepted 
                ? '<p>Congratulations! Your appeal has been accepted and your account status has been updated.</p>'
                : '<p>We have carefully reviewed your appeal, but unfortunately we cannot accommodate your request at this time.</p>'
            }
        </div>

        ${admin_response ? `
        <h3>Admin Response</h3>
        <div class="admin-response">
            ${admin_response.replace(/\n/g, '<br>')}
        </div>
        ` : ''}

        ${isAccepted ? `
        <h3>Account Status Updated</h3>
        <p>Your account status has been updated to <strong>ACTIVE</strong>. You can now:</p>
        <ul>
            <li>Access your account normally</li>
            <li>Book activities</li>
            <li>Post and interact with the community</li>
        </ul>
        ` : `
        <h3>Current Status</h3>
        <p>Your current account status remains <strong>${user.accountStatus?.toUpperCase()}</strong>.</p>
        <p>If you believe this decision was made in error, you may submit a new appeal after 30 days.</p>
        `}

        <h3>Appeal Reference</h3>
        <div style="background: #f0f0f0; padding: 15px; border-radius: 5px;">
            <p><strong>Appeal ID:</strong> ${appeal._id}</p>
            <p><strong>Original Subject:</strong> ${appeal.subject}</p>
            <p><strong>Decision Date:</strong> ${new Date().toLocaleString()}</p>
        </div>

        <div style="text-align: center;">
            <a href="${process.env.FRONTEND_URL || 'http://localhost:3000'}/login" class="btn">
                ${isAccepted ? 'Access Your Account' : 'View Your Account'}
            </a>
        </div>
    </div>

    <div class="footer">
        <p>Best regards,<br>DJTrip Support Team</p>
        <p>This is an automated message. Please do not reply to this email.</p>
    </div>
</body>
</html>
`;
};

// ─── Export Functions ───────────────────────────────────────────────────────────────

// Send notification to admin about new appeal
exports.sendAdminAppealNotification = async ({ user, appeal, req }) => {
  const html = adminAppealTemplate({ user, appeal, req });
  
  return await sendEmail({
    to: process.env.ADMIN_EMAIL,
    subject: `🚨 New Appeal Submitted - ${appeal.subject}`,
    html,
  });
};

// Send confirmation to user
exports.sendUserAppealConfirmation = async ({ user, appeal }) => {
  const html = userAppealConfirmationTemplate({ user, appeal });
  
  return await sendEmail({
    to: user.email,
    subject: "✅ Your Appeal Has Been Received - DJTrip",
    html,
  });
};

// Send decision notification to user
exports.sendAppealDecisionNotification = async ({ user, appeal, status, admin_response }) => {
  const html = appealDecisionTemplate({ user, appeal, status, admin_response });
  const isAccepted = status === "accepted";
  
  return await sendEmail({
    to: user.email,
    subject: `${isAccepted ? '✅' : '❌'} Appeal Decision - DJTrip`,
    html,
  });
};

// Generic email sending function
exports.sendEmail = sendEmail;
