const nodemailer = require('nodemailer');
const dns = require('dns');

// Force IPv4 resolution to avoid ENETUNREACH on IPv6
if (dns.setDefaultResultOrder) {
  dns.setDefaultResultOrder('ipv4first');
}

// Create transporter using environment variables
const NODE_ENV = (process.env.NODE_ENV || "development").toLowerCase();
const EMAIL_PORT = Number(process.env.EMAIL_PORT) || 465;
const EMAIL_SECURE = process.env.EMAIL_SECURE === "true" || EMAIL_PORT === 465;
const isProduction = NODE_ENV === "production";

const transporter = nodemailer.createTransport({
  host: process.env.EMAIL_HOST || "smtp.gmail.com",
  port: EMAIL_PORT,
  secure: EMAIL_SECURE,
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASSWORD,
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
});

class OnboardingEmailService {
  static async _sendMailWithFallback(mailOptions, contextMessage) {
    try {
      await transporter.sendMail(mailOptions);
      console.log(`${contextMessage} sent via SMTP to ${mailOptions.to}`);
      return { success: true };
    } catch (error) {
      console.error(`SMTP Error sending ${contextMessage}:`, error.message);
      
      // Fallback to Resend
      if (process.env.RESEND_API_KEY) {
        console.log(`Attempting fallback with Resend for ${contextMessage}...`);
        try {
          const { Resend } = require('resend');
          const resend = new Resend(process.env.RESEND_API_KEY);
          const fromAddress = process.env.RESEND_FROM || mailOptions.from;
          
          const { data, error: resendError } = await resend.emails.send({
            from: fromAddress,
            to: Array.isArray(mailOptions.to) ? mailOptions.to : [mailOptions.to],
            subject: mailOptions.subject,
            text: mailOptions.text,
            html: mailOptions.html,
          });
          
          if (resendError) {
            throw new Error(resendError.message);
          }
          
          console.log(`${contextMessage} sent via Resend to ${mailOptions.to}`);
          return { success: true };
        } catch (rsError) {
          console.error(`Resend fallback failed for ${contextMessage}:`, rsError.message);
        }
      }
      
      return { success: false, error: error.message };
    }
  }

  // Send onboarding completed email for tourists
  static async sendOnboardingCompletedEmail(email, fullname) {
    const mailOptions = {
      from: process.env.EMAIL_FROM,
      to: email,
      subject: 'Welcome to DJTrip! 🎉 Your Account is Ready',
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>Welcome to DJTrip!</title>
          <style>
            body {
              font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
              line-height: 1.6;
              color: #333;
              max-width: 600px;
              margin: 0 auto;
              padding: 20px;
            }
            .header {
              background: linear-gradient(135deg, #4B63FF, #3A54E0);
              color: white;
              padding: 30px;
              border-radius: 12px 12px 0 0;
              text-align: center;
            }
            .logo {
              font-size: 28px;
              font-weight: bold;
              margin-bottom: 10px;
            }
            .content {
              background: white;
              padding: 30px;
              border-radius: 0 0 12px 12px;
              box-shadow: 0 4px 12px rgba(0,0,0,0.1);
            }
            .welcome-title {
              font-size: 24px;
              font-weight: bold;
              color: #1E225E;
              margin-bottom: 20px;
            }
            .feature-list {
              background: #F8F9FF;
              padding: 20px;
              border-radius: 8px;
              margin: 20px 0;
            }
            .feature-item {
              display: flex;
              align-items: center;
              margin-bottom: 15px;
            }
            .feature-icon {
              width: 40px;
              height: 40px;
              background: #4B63FF;
              color: white;
              border-radius: 50%;
              display: flex;
              align-items: center;
              justify-content: center;
              margin-right: 15px;
              font-size: 18px;
            }
            .cta-button {
              display: inline-block;
              background: #4B63FF;
              color: white;
              padding: 15px 30px;
              text-decoration: none;
              border-radius: 8px;
              font-weight: bold;
              margin: 20px 0;
            }
            .footer {
              text-align: center;
              padding: 20px;
              color: #6C757D;
              font-size: 14px;
            }
          </style>
        </head>
        <body>
          <div class="header">
            <div class="logo">DJTrip</div>
            <div>Your Adventure Starts Here!</div>
          </div>
          
          <div class="content">
            <h1 class="welcome-title">Welcome, ${fullname}! 🎉</h1>
            <p>Congratulations! Your account setup is complete and you're ready to explore amazing experiences around the world.</p>
            
            <div class="feature-list">
              <div class="feature-item">
                <div class="feature-icon">🔍</div>
                <div>
                  <strong>Discover Activities</strong>
                  <p>Find unique experiences tailored to your interests</p>
                </div>
              </div>
              <div class="feature-item">
                <div class="feature-icon">📅</div>
                <div>
                  <strong>Book with Confidence</strong>
                  <p>Secure payments and verified organizers</p>
                </div>
              </div>
              <div class="feature-item">
                <div class="feature-icon">⭐</div>
                <div>
                  <strong>Share Your Experience</strong>
                  <p>Rate and review activities you've enjoyed</p>
                </div>
              </div>
            </div>
            
            <div style="text-align: center;">
              <a href="${process.env.FRONTEND_URL}/home" class="cta-button">Start Exploring</a>
            </div>
          </div>
          
          <div class="footer">
            <p>This email was sent to ${email} because you recently completed onboarding for DJTrip.</p>
            <p>© 2024 DJTrip. All rights reserved.</p>
          </div>
        </body>
        </html>
      `,
    };

    return await this._sendMailWithFallback(mailOptions, 'onboarding completed email');
  }


  // Send organizer submitted for approval email
  static async sendOrganizerSubmittedEmail(email, fullname) {
    const mailOptions = {
      from: process.env.EMAIL_FROM,
      to: email,
      subject: 'DJTrip Organizer Application Received 📋',
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>Organizer Application Received</title>
          <style>
            body {
              font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
              line-height: 1.6;
              color: #333;
              max-width: 600px;
              margin: 0 auto;
              padding: 20px;
            }
            .header {
              background: linear-gradient(135deg, #00B894, #00A085);
              color: white;
              padding: 30px;
              border-radius: 12px 12px 0 0;
              text-align: center;
            }
            .logo {
              font-size: 28px;
              font-weight: bold;
              margin-bottom: 10px;
            }
            .content {
              background: white;
              padding: 30px;
              border-radius: 0 0 12px 12px;
              box-shadow: 0 4px 12px rgba(0,0,0,0.1);
            }
            .status-box {
              background: #FFF3CD;
              border-left: 4px solid #FFA502;
              padding: 20px;
              border-radius: 8px;
              margin: 20px 0;
            }
            .timeline {
              background: #F8F9FF;
              padding: 20px;
              border-radius: 8px;
              margin: 20px 0;
            }
            .timeline-item {
              display: flex;
              align-items: flex-start;
              margin-bottom: 15px;
            }
            .timeline-icon {
              width: 30px;
              height: 30px;
              background: #4B63FF;
              color: white;
              border-radius: 50%;
              display: flex;
              align-items: center;
              justify-content: center;
              margin-right: 15px;
              font-size: 14px;
              flex-shrink: 0;
            }
            .timeline-icon.completed {
              background: #00B894;
            }
            .footer {
              text-align: center;
              padding: 20px;
              color: #6C757D;
              font-size: 14px;
            }
          </style>
        </head>
        <body>
          <div class="header">
            <div class="logo">DJTrip</div>
            <div>Organizer Application</div>
          </div>
          
          <div class="content">
            <h1 style="color: #1E225E; margin-bottom: 20px;">Application Received! 📋</h1>
            <p>Hi <strong>${fullname}</strong>,</p>
            <p>Thank you for your interest in becoming a DJTrip organizer! We've received your application and it's now under review.</p>
            
            <div class="status-box">
              <h3 style="margin-top: 0; color: #856404;">⏱️ Under Review</h3>
              <p>Your application is being reviewed by our team. This process typically takes 1-3 business days.</p>
            </div>
            
            <h3 style="color: #1E225E;">What happens next?</h3>
            <div class="timeline">
              <div class="timeline-item">
                <div class="timeline-icon completed">✓</div>
                <div>
                  <strong>Application Received</strong>
                  <p style="margin: 5px 0 0 0;">Your application has been submitted successfully</p>
                </div>
              </div>
              <div class="timeline-item">
                <div class="timeline-icon">🔍</div>
                <div>
                  <strong>Review Process</strong>
                  <p style="margin: 5px 0 0 0;">Our team reviews your information and verifies your credentials</p>
                </div>
              </div>
              <div class="timeline-item">
                <div class="timeline-icon">📧</div>
                <div>
                  <strong>Decision</strong>
                  <p style="margin: 5px 0 0 0;">You'll receive an email with our decision</p>
                </div>
              </div>
            </div>
            
            <p style="margin-top: 30px;">While you wait, you can:</p>
            <ul>
              <li>Explore our platform as a tourist</li>
              <li>Prepare your activity listings</li>
              <li>Read our organizer guidelines</li>
            </ul>
          </div>
          
          <div class="footer">
            <p>This email was sent to ${email} regarding your DJTrip organizer application.</p>
            <p>© 2024 DJTrip. All rights reserved.</p>
          </div>
        </body>
        </html>
      `,
    };

    return await this._sendMailWithFallback(mailOptions, 'organizer submitted email');
  }

  // Send organizer approved email
  static async sendOrganizerApprovedEmail(email, fullname) {
    const mailOptions = {
      from: process.env.EMAIL_FROM,
      to: email,
      subject: '🎉 Congratulations! Your DJTrip Organizer Account is Approved',
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>Organizer Account Approved</title>
          <style>
            body {
              font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
              line-height: 1.6;
              color: #333;
              max-width: 600px;
              margin: 0 auto;
              padding: 20px;
            }
            .header {
              background: linear-gradient(135deg, #00B894, #00A085);
              color: white;
              padding: 30px;
              border-radius: 12px 12px 0 0;
              text-align: center;
            }
            .logo {
              font-size: 28px;
              font-weight: bold;
              margin-bottom: 10px;
            }
            .content {
              background: white;
              padding: 30px;
              border-radius: 0 0 12px 12px;
              box-shadow: 0 4px 12px rgba(0,0,0,0.1);
            }
            .success-box {
              background: #D4EDDA;
              border-left: 4px solid #00B894;
              padding: 20px;
              border-radius: 8px;
              margin: 20px 0;
            }
            .feature-grid {
              display: grid;
              grid-template-columns: 1fr 1fr;
              gap: 20px;
              margin: 20px 0;
            }
            .feature-item {
              background: #F8F9FF;
              padding: 20px;
              border-radius: 8px;
              text-align: center;
            }
            .feature-icon {
              font-size: 32px;
              margin-bottom: 10px;
            }
            .cta-button {
              display: inline-block;
              background: #00B894;
              color: white;
              padding: 15px 30px;
              text-decoration: none;
              border-radius: 8px;
              font-weight: bold;
              margin: 20px 0;
            }
            .footer {
              text-align: center;
              padding: 20px;
              color: #6C757D;
              font-size: 14px;
            }
          </style>
        </head>
        <body>
          <div class="header">
            <div class="logo">DJTrip</div>
            <div>Approved Organizer</div>
          </div>
          
          <div class="content">
            <h1 style="color: #1E225E; margin-bottom: 20px;">🎉 Congratulations, ${fullname}!</h1>
            <p>Your DJTrip organizer account has been <strong style="color: #00B894;">approved</strong>! You're now ready to start creating amazing experiences for travelers.</p>
            
            <div class="success-box">
              <h3 style="margin-top: 0; color: #155724;">✅ Account Approved</h3>
              <p>Your organizer account is now active and you can access all organizer features.</p>
            </div>
            
            <h3 style="color: #1E225E;">What can you do now?</h3>
            <div class="feature-grid">
              <div class="feature-item">
                <div class="feature-icon">📝</div>
                <strong>Create Activities</strong>
                <p>List your experiences and activities</p>
              </div>
              <div class="feature-item">
                <div class="feature-icon">📅</div>
                <strong>Manage Bookings</strong>
                <p>Handle reservations and communications</p>
              </div>
              <div class="feature-item">
                <div class="feature-icon">💰</div>
                <strong>Receive Payments</strong>
                <p>Secure payment processing</p>
              </div>
              <div class="feature-item">
                <div class="feature-icon">📊</div>
                <strong>Track Performance</strong>
                <p>Analytics and insights</p>
              </div>
            </div>
            
            <div style="text-align: center;">
              <a href="${process.env.FRONTEND_URL}/organizer/dashboard" class="cta-button">Go to Dashboard</a>
            </div>
          </div>
          
          <div class="footer">
            <p>This email was sent to ${email} because your DJTrip organizer account was approved.</p>
            <p>© 2024 DJTrip. All rights reserved.</p>
          </div>
        </body>
        </html>
      `,
    };

    return await this._sendMailWithFallback(mailOptions, 'organizer approved email');
  }

  // Send organizer rejected email
  static async sendOrganizerRejectedEmail(email, fullname, rejectionReason) {
    const mailOptions = {
      from: process.env.EMAIL_FROM,
      to: email,
      subject: 'DJTrip Organizer Application Update',
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>Organizer Application Update</title>
          <style>
            body {
              font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
              line-height: 1.6;
              color: #333;
              max-width: 600px;
              margin: 0 auto;
              padding: 20px;
            }
            .header {
              background: linear-gradient(135deg, #FF4757, #E74C3C);
              color: white;
              padding: 30px;
              border-radius: 12px 12px 0 0;
              text-align: center;
            }
            .logo {
              font-size: 28px;
              font-weight: bold;
              margin-bottom: 10px;
            }
            .content {
              background: white;
              padding: 30px;
              border-radius: 0 0 12px 12px;
              box-shadow: 0 4px 12px rgba(0,0,0,0.1);
            }
            .rejection-box {
              background: #F8D7DA;
              border-left: 4px solid #DC3545;
              padding: 20px;
              border-radius: 8px;
              margin: 20px 0;
            }
            .next-steps {
              background: #F8F9FF;
              padding: 20px;
              border-radius: 8px;
              margin: 20px 0;
            }
            .footer {
              text-align: center;
              padding: 20px;
              color: #6C757D;
              font-size: 14px;
            }
          </style>
        </head>
        <body>
          <div class="header">
            <div class="logo">DJTrip</div>
            <div>Application Update</div>
          </div>
          
          <div class="content">
            <h1 style="color: #1E225E; margin-bottom: 20px;">Application Update</h1>
            <p>Hi <strong>${fullname}</strong>,</p>
            <p>Thank you for your interest in becoming a DJTrip organizer. After careful consideration of your application, we've decided not to proceed with your application at this time.</p>
            
            <div class="rejection-box">
              <h3 style="margin-top: 0; color: #721C24;">❌ Application Not Approved</h3>
              <p><strong>Reason:</strong> ${rejectionReason || 'No specific reason provided'}</p>
            </div>
            
            <div class="next-steps">
              <h3 style="color: #1E225E;">What can you do?</h3>
              <ul>
                <li>Review our organizer requirements and guidelines</li>
                <li>Improve your profile and documentation</li>
                <li>Wait 30 days before reapplying</li>
                <li>Contact support if you have questions</li>
              </ul>
            </div>
            
            <p style="margin-top: 30px;">You can still use DJTrip as a tourist to discover amazing experiences around the world.</p>
          </div>
          
          <div class="footer">
            <p>This email was sent to ${email} regarding your DJTrip organizer application.</p>
            <p>© 2024 DJTrip. All rights reserved.</p>
          </div>
        </body>
        </html>
      `,
    };

    return await this._sendMailWithFallback(mailOptions, 'organizer rejected email');
  }
}

module.exports = OnboardingEmailService;
