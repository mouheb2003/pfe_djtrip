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
    return {
      refundPercent: 0,
      refundAmount: 0,
      feePercent: 0,
      feeAmount: 0,
      hoursBeforeStart: 0,
      canCancel: true,
      policy: "No refund policy"
    };
  }
  
  /**
   * Get human-readable policy description
   */
  static getPolicyDescription(hoursBeforeStart) {
    return 'Cancellations do not include a refund.';
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
    
    if (booking.statut === 'cancelled') {
      return { canCancel: false, reason: 'Already cancelled' };
    }
    
    if (booking.statut === 'verified') {
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
      
      // Calculate refund (removed)
      const refund = { refundAmount: 0, feePercent: 0, refundPercent: 0, feeAmount: 0, policy: "No refund" };
      
      // Check if was approved before changing status (for capacity decrement)
      const wasApproved = booking.statut === 'approved';
      
      // Update booking
      booking.statut = 'cancelled';
      booking.cancellationPolicy = {
        canCancel: true,
        cancellationDeadline: activity.date_debut,
        cancellationFee: 0,
        refundAmount: 0,
        cancelledAt: new Date(),
        cancellationReason: reason,
        refundProcessed: true
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
      
      // Trigger notification for organizer
      try {
        const notificationEventBus = require('./notificationEventBus');
        notificationEventBus.emitBookingCancelled({
          organizerId: booking.organisateur_id,
          activityTitle: activity.titre,
          bookingId: booking._id.toString(),
          touristId: touristId,
          reason: reason || "No reason provided"
        });
      } catch (notifError) {
        console.warn('Failed to emit booking cancelled event:', notifError.message);
      }
      
      logger.info('Booking cancelled', {
        bookingId,
        touristId
      });
      
      return {
        success: true,
        booking,
        refund: {
          amount: 0,
          percent: 0,
          fee: 0,
          feePercent: 0,
          policy: "No refund"
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
        statut: 'cancelled',
        ...dateFilter
      });
      
      const totalRefunded = await Inscription.aggregate([
        {
          $match: {
            organisateur_id: organizerId,
            statut: 'cancelled',
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
