// Test Mode - Display verification code in console instead of sending email
// This is useful for testing without configuring email service

// In controllers/user.js, modify the signUp function:

// Option 1: Console only (no email sent)
/*
  // Generate verification code
  const verificationCode = emailService.generateVerificationCode();
  const verificationCodeExpiry = new Date(Date.now() + 15 * 60 * 1000);
  
  // Display code in console instead of sending email
  console.log('\n========================================');
  console.log('📧 EMAIL VERIFICATION CODE');
  console.log('========================================');
  console.log('User:', fullname);
  console.log('Email:', email);
  console.log('Code:', verificationCode);
  console.log('Expires:', verificationCodeExpiry);
  console.log('========================================\n');
*/

// Option 2: Send email but also log to console
/*
  // Send verification email
  const emailResult = await emailService.sendVerificationEmail(
    email,
    verificationCode,
    fullname,
  );

  // Log to console for development
  if (process.env.NODE_ENV === 'development') {
    console.log('\n📧 Verification Code (DEV MODE):', verificationCode, '\n');
  }

  if (!emailResult.success) {
    console.error("Failed to send verification email:", emailResult.error);
  }
*/

// To enable test mode:
// 1. Set NODE_ENV=development in .env
// 2. Comment out email sending in signUp function
// 3. Log the verification code to console
// 4. Copy the code from console and use it in the app
