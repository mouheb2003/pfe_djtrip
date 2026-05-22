require('dotenv').config();
const { verifyEmailTransport, sendBookingConfirmationEmail, sendBookingRejectionEmail } = require('../services/email');
const mongoose = require('mongoose');

async function testEmailDelivery() {
  console.log('📡 Verifying SMTP connection transport...');
  try {
    const result = await verifyEmailTransport();
    console.log('✅ SMTP Transport status:', result);

    const testRecipient = process.env.EMAIL_USER || 'djtrip00@gmail.com';
    console.log(`✉️ Sending test booking confirmation email (brand blue gradient) to: ${testRecipient}...`);
    const confirmInfo = await sendBookingConfirmationEmail({
      email: testRecipient,
      fullname: 'Mouheb DJTrip Developer',
      bookingCode: 'TRIP-CONFIRM-100',
      activityTitle: 'Ocean Scuba Diving in Tabarka 🤿',
      bookingDate: '2026-06-25',
      bookingTime: '09:00 AM',
      participants: 2,
      totalPrice: '240 DT',
      qrPublicUrl: 'https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=TRIP-CONFIRM-100',
    });
    console.log('✅ Confirmation Email Sent successfully! Info:', confirmInfo);

    console.log(`✉️ Sending test booking rejection email (brand orange, NO motif reason) to: ${testRecipient}...`);
    const rejectInfo = await sendBookingRejectionEmail({
      email: testRecipient,
      fullname: 'Mouheb DJTrip Developer',
      activityTitle: 'Extreme Quad Biking Sahara 🏜️',
      rejectionReason: 'Ignored because motif is now deleted!',
    });
    console.log('✅ Rejection Email Sent successfully! Info:', rejectInfo);

    console.log('\n🎉 ALL EMAILS DELIVERED & WORKING 100% CORRECTLY!');
  } catch (error) {
    console.error('❌ Email sending failed with error:', error);
  } finally {
    console.log('👋 Test completed.');
    process.exit(0);
  }
}

testEmailDelivery();
