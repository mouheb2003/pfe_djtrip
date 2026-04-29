const Inscription = require('../models/inscription');
const Activite = require('../models/activite');
const logger = require('../utils/logger');

/**
 * Cancellation Policy Service
 * Handles cancellation rules, refund calculations, and policy enforcement
 */
class CancellationPolicy {
  /**
   * Calculate refund based on time before activity
   * Policy:
   * - 48+ hours before: 100% refund (0% platform fee)
   * - 24-48 hours: 85% refund (15% platform fee)
   * - <24 hours: 70% refund (30% platform fee)
   */
  static calculateRefund(booking, activity) {
    const now = new Date();
    const activityStart = new Date(activity.date_debut);
    const hoursBeforeStart = (activityStart - now) / (1000 * 60 * 60);
    
    // Default policy
    let refundPercent = 0;
    let feePercent = 100;
    
    if (hoursBeforeStart >= 48) {
      refundPercent = 100;
      feePercent = 0;
    } else if (hoursBeforeStart >= 24) {
      refundPercent = 85;
      feePercent = 15;
    } else {
      // Less than 24 hours: 70% refund (30% platform fee)
      refundPercent = 70;
      feePercent = 30;
    }
    
    const refundAmount = (booking.prix_total * refundPercent) / 100;
    const feeAmount = booking.prix_total - refundAmount;
    
    return {
      refundPercent,
      refundAmount,
      feePercent,
      feeAmount,
      hoursBeforeStart: Math.max(0, hoursBeforeStart),
      canCancel: hoursBeforeStart > 0,
      policy: this.getPolicyDescription(hoursBeforeStart)
    };
  }
  
  /**
   * Get human-readable policy description
   */
  static getPolicyDescription(hoursBeforeStart) {
    if (hoursBeforeStart >= 48) {
      return 'Full refund (48+ hours before activity)';
    } else if (hoursBeforeStart >= 24) {
      return '85% refund (24-48 hours before activity - 15% platform fee)';
    } else {
      return '70% refund (<24 hours before activity - 30% platform fee)';
    }
  }
  
  /**
   * Check if booking can be cancelled
   * Policy: Cancellation allowed any time before activity starts
   */
  static canCancel(booking, activity) {
    const now = new Date();
    const activityStart = new Date(activity.date_debut);
    const hoursBeforeStart = (activityStart - now) / (1000 * 60 * 60);
    
    // Cannot cancel if:
    // - Already cancelled
    // - Activity already started
    // - Booking is already checked-in
    // - Booking is no-show
    
    if (booking.statut === 'annulee') {
      return { canCancel: false, reason: 'Already cancelled' };
    }
    
    if (booking.statut === 'verifie') {
      return { canCancel: false, reason: 'Already checked-in' };
    }
    
    if (booking.statut === 'no_show') {
      return { canCancel: false, reason: 'Marked as no-show' };
    }
    
    if (hoursBeforeStart <= 0) {
      return { canCancel: false, reason: 'Activity already started' };
    }
    
    // Cancellation allowed any time before activity starts
    return { canCancel: true, hoursBeforeStart };
  }
  
  /**
   * Cancel booking with refund calculation
   * Uses MongoDB transaction for data consistency
   */
  static async cancelBooking(bookingId, touristId, reason = null) {
    const session = await Inscription.startSession();
    session.startTransaction();
    
    try {
      // Fetch booking
      const booking = await Inscription.findById(bookingId).session(session);
      if (!booking) {
        throw new Error('Booking not found');
      }
      
      // Verify ownership
      const bookingTouristId = booking.touriste_id.toString();
      const requestTouristId = touristId.toString();
      console.log('[CANCELLATION] Ownership check:', {
        bookingTouristId,
        requestTouristId,
        match: bookingTouristId === requestTouristId
      });
      
      if (bookingTouristId !== requestTouristId) {
        throw new Error('Unauthorized to cancel this booking');
      }
      
      // Fetch activity
      const activity = await Activite.findById(booking.activite_id).session(session);
      if (!activity) {
        throw new Error('Activity not found');
      }
      
      // Check if can cancel
      const canCancelCheck = this.canCancel(booking, activity);
      if (!canCancelCheck.canCancel) {
        throw new Error(canCancelCheck.reason);
      }
      
      // Calculate refund
      const refund = this.calculateRefund(booking, activity);
      
      // Check if was approved before changing status (for capacity decrement)
      const wasApproved = booking.statut === 'approuvee';
      
      // Update booking
      booking.statut = 'annulee';
      booking.cancellationPolicy = {
        canCancel: true,
        cancellationDeadline: activity.date_debut,
        cancellationFee: refund.feePercent,
        refundAmount: refund.refundAmount,
        cancelledAt: new Date(),
        cancellationReason: reason,
        refundProcessed: false
      };
      
      await booking.save({ session });
      
      // Decrement capacity if was approved
      if (wasApproved) {
        await Activite.findByIdAndUpdate(
          booking.activite_id,
          { $inc: { nombre_reservations: -booking.nombre_participants } },
          { session }
        );
      }
      
      await session.commitTransaction();
      
      logger.info('Booking cancelled', {
        bookingId,
        touristId,
        refundAmount: refund.refundAmount,
        refundPercent: refund.refundPercent
      });
      
      // Process refund via Stripe if applicable (after transaction commit)
      // Process refund if there's a payment, regardless of approval status
      if (refund.refundAmount > 0) {
        try {
          const Payment = require('../models/payment');
          const stripeService = require('../services/stripeService');
          
          const payment = await Payment.findOne({ inscription_id: bookingId });
          console.log('[CANCELLATION] Looking for payment for booking:', bookingId);
          
          if (payment && payment.stripe_payment_intent_id) {
            const amountInCents = Math.round(refund.refundAmount * 100);
            console.log('[CANCELLATION] Processing Stripe refund:', {
              paymentIntentId: payment.stripe_payment_intent_id,
              amountInCents,
              refundAmount: refund.refundAmount,
              paymentStatus: payment.status
            });
            
            const refundResult = await stripeService.refundPayment(
              payment.stripe_payment_intent_id, 
              amountInCents
            );
            
            console.log('[CANCELLATION] Stripe refund successful:', refundResult);
            
            // Update payment status
            payment.status = "refunded";
            payment.refunded_at = new Date();
            await payment.save();
            
            // Update booking refund processed flag
            booking.cancellationPolicy.refundProcessed = true;
            await booking.save();
            
            logger.info('Refund processed via Stripe', { 
              bookingId, 
              refundAmount: refund.refundAmount,
              refundId: refundResult.id
            });
          } else {
            console.log('[CANCELLATION] No payment found or no payment_intent_id for booking, skipping Stripe refund');
            console.log('[CANCELLATION] Payment:', payment ? { id: payment._id, status: payment.status, hasPaymentIntent: !!payment.stripe_payment_intent_id } : 'null');
            // Queue for retry via event bus if there's a refund amount
            if (refund.refundAmount > 0) {
              const notificationEventBus = require('../services/notificationEventBus');
              await notificationEventBus.emitBookingCancelled(
                bookingId, 
                activity.organisateur_id, 
                touristId, 
                activity.titre, 
                reason, 
                refund.refundAmount
              );
            }
          }
        } catch (refundError) {
          logger.error('Stripe refund failed, queueing for retry', { 
            bookingId, 
            error: refundError.message 
          });
          // Queue for retry via event bus
          const notificationEventBus = require('../services/notificationEventBus');
          await notificationEventBus.emitBookingCancelled(
            bookingId, 
            activity.organisateur_id, 
            touristId, 
            activity.titre, 
            reason, 
            refund.refundAmount
          );
        }
      }
      
      return {
        success: true,
        booking,
        refund: {
          amount: refund.refundAmount,
          percent: refund.refundPercent,
          fee: refund.feeAmount,
          feePercent: refund.feePercent,
          policy: refund.policy
        }
      };
    } catch (error) {
      try {
        await session.abortTransaction();
      } catch (abortError) {
        // Transaction might already be aborted by MongoDB
        console.log('[CANCELLATION] Transaction already aborted or ended:', abortError.message);
      }
      logger.error('Booking cancellation failed', {
        bookingId,
        touristId,
        error: error.message,
        stack: error.stack
      });
      throw error;
    } finally {
      try {
        session.endSession();
      } catch (endError) {
        // Session might already be ended
        console.log('[CANCELLATION] Session already ended:', endError.message);
      }
    }
  }
  
  /**
   * Get cancellation policy for an activity
   */
  static getActivityPolicy(activityId) {
    return {
      rules: [
        { hoursBefore: 48, refund: 100, description: 'Full refund' },
        { hoursBefore: 24, refund: 50, description: '50% refund' },
        { hoursBefore: 12, refund: 25, description: '25% refund' },
        { hoursBefore: 0, refund: 0, description: 'No refund' }
      ],
      note: 'Refund is calculated based on time difference between cancellation and activity start time'
    };
  }
  
  /**
   * Get cancellation statistics for organizer
   */
  static async getCancellationStats(organizerId, startDate, endDate) {
    try {
      const dateFilter = {};
      if (startDate) dateFilter.createdAt = { $gte: startDate };
      if (endDate) dateFilter.createdAt = { $lte: endDate };
      
      const totalBookings = await Inscription.countDocuments({
        organisateur_id: organizerId,
        ...dateFilter
      });
      
      const cancelledBookings = await Inscription.countDocuments({
        organisateur_id: organizerId,
        statut: 'annulee',
        ...dateFilter
      });
      
      const totalRefunded = await Inscription.aggregate([
        {
          $match: {
            organisateur_id: organizerId,
            statut: 'annulee',
            'cancellationPolicy.refundAmount': { $exists: true },
            ...dateFilter
          }
        },
        {
          $group: {
            _id: null,
            totalRefundAmount: { $sum: '$cancellationPolicy.refundAmount' }
          }
        }
      ]);
      
      const cancellationRate = totalBookings > 0 ? (cancelledBookings / totalBookings) * 100 : 0;
      
      return {
        totalBookings,
        cancelledBookings,
        cancellationRate: Math.round(cancellationRate * 10) / 10,
        totalRefundAmount: totalRefunded[0]?.totalRefundAmount || 0
      };
    } catch (error) {
      logger.error('Failed to get cancellation stats', { organizerId, error: error.message });
      throw error;
    }
  }
}

module.exports = CancellationPolicy;
