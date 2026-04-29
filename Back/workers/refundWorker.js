const { refundQueue } = require('../queues');
const stripeService = require('../services/stripeService');
const Payment = require('../models/payment');
const Inscription = require('../models/inscription');

/**
 * Refund Worker
 * Processes refund jobs from the refund queue
 * This is a fallback mechanism when direct Stripe refund fails
 */

refundQueue.process('process-refund', async (job) => {
  const { bookingId, refundAmount, touristId } = job.data;
  
  console.log('[REFUND WORKER] Processing refund job:', {
    bookingId,
    refundAmount,
    touristId
  });
  
  try {
    // Find booking
    const booking = await Inscription.findById(bookingId);
    if (!booking) {
      console.log('[REFUND WORKER] Booking not found:', bookingId);
      return;
    }
    
    // Check if refund already processed
    if (booking.cancellationPolicy?.refundProcessed) {
      console.log('[REFUND WORKER] Refund already processed for booking:', bookingId);
      return;
    }
    
    // Find payment
    const payment = await Payment.findOne({ inscription_id: bookingId });
    if (!payment) {
      console.log('[REFUND WORKER] No payment found for booking:', bookingId);
      return;
    }
    
    if (!payment.stripe_payment_intent_id) {
      console.log('[REFUND WORKER] No Stripe payment intent ID for booking:', bookingId);
      return;
    }
    
    // Process Stripe refund
    const amountInCents = Math.round(refundAmount * 100);
    console.log('[REFUND WORKER] Calling Stripe refund:', {
      paymentIntentId: payment.stripe_payment_intent_id,
      amountInCents
    });
    
    const refundResult = await stripeService.refundPayment(
      payment.stripe_payment_intent_id, 
      amountInCents
    );
    
    console.log('[REFUND WORKER] Stripe refund successful:', refundResult);
    
    // Update payment status
    payment.status = "refunded";
    payment.refunded_at = new Date();
    await payment.save();
    
    // Update booking refund processed flag
    booking.cancellationPolicy.refundProcessed = true;
    await booking.save();
    
    console.log('[REFUND WORKER] Refund processed successfully for booking:', bookingId);
  } catch (error) {
    console.error('[REFUND WORKER] Error processing refund:', error.message);
    
    // Retry with exponential backoff
    if (job.attemptsMade < 5) {
      console.log('[REFUND WORKER] Retrying (attempt ' + (job.attemptsMade + 1) + ')');
      throw error; // This will trigger a retry
    } else {
      console.error('[REFUND WORKER] Max retries reached, giving up for booking:', bookingId);
      // Mark as failed but don't retry further
      // Could send notification to admin here
    }
  }
});

console.log('[REFUND WORKER] Refund worker initialized and listening for jobs');
