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
   * - 48+ hours before: 100% refund
   * - 24-48 hours: 50% refund
   * - 12-24 hours: 25% refund
   * - <12 hours: 0% refund
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
      refundPercent = 50;
      feePercent = 50;
    } else if (hoursBeforeStart >= 12) {
      refundPercent = 25;
      feePercent = 75;
    } else {
      refundPercent = 0;
      feePercent = 100;
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
      return '50% refund (24-48 hours before activity)';
    } else if (hoursBeforeStart >= 12) {
      return '25% refund (12-24 hours before activity)';
    } else {
      return 'No refund (<12 hours before activity)';
    }
  }
  
  /**
   * Check if booking can be cancelled
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
        await session.abortTransaction();
        throw new Error('Booking not found');
      }
      
      // Verify ownership
      if (booking.touriste_id.toString() !== touristId) {
        await session.abortTransaction();
        throw new Error('Unauthorized to cancel this booking');
      }
      
      // Fetch activity
      const activity = await Activite.findById(booking.activite_id).session(session);
      if (!activity) {
        await session.abortTransaction();
        throw new Error('Activity not found');
      }
      
      // Check if can cancel
      const canCancelCheck = this.canCancel(booking, activity);
      if (!canCancelCheck.canCancel) {
        await session.abortTransaction();
        throw new Error(canCancelCheck.reason);
      }
      
      // Calculate refund
      const refund = this.calculateRefund(booking, activity);
      
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
      if (booking.statut === 'approuvee') {
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
      await session.abortTransaction();
      logger.error('Booking cancellation failed', {
        bookingId,
        touristId,
        error: error.message
      });
      throw error;
    } finally {
      session.endSession();
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
