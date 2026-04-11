const Inscription = require('../models/inscription');
const Activite = require('../models/activite');
const CheckinLog = require('../models/checkinLog');
const logger = require('../utils/logger');

/**
 * No-Show Detection Service
 * Automatically marks approved bookings as no-show if:
 * - Booking status is "approuvee"
 * - User did not check-in (qr_used_at is null)
 * - Activity end time has passed
 */
class NoShowService {
  /**
   * Mark no-shows for activities that have ended
   * This should be called by a cron job or scheduled task
   */
  static async markNoShows() {
    try {
      const now = new Date();
      
      // Find all activities that have ended
      const activitiesEnded = await Activite.find({
        date_fin: { $lt: now },
        statut: 'active'
      }).distinct('_id');
      
      if (activitiesEnded.length === 0) {
        logger.info('No-show check: No ended activities found');
        return { marked: 0, activitiesChecked: 0 };
      }
      
      logger.info(`No-show check: Checking ${activitiesEnded.length} ended activities`);
      
      // Find all approved bookings for ended activities without check-in
      const noShows = await Inscription.updateMany(
        {
          activite_id: { $in: activitiesEnded },
          statut: 'approuvee',
          qr_used_at: { $exists: false },
          'noShow.isNoShow': { $ne: true } // Not already marked
        },
        {
          $set: {
            'noShow.isNoShow': true,
            'noShow.markedAt': now,
            statut: 'no_show' // Optional: change status to no_show
          }
        }
      );
      
      logger.info(`No-show check: Marked ${noShows.modifiedCount} bookings as no-show`);
      
      return {
        marked: noShows.modifiedCount,
        activitiesChecked: activitiesEnded.length,
        timestamp: now
      };
    } catch (error) {
      logger.error('No-show detection failed', { error: error.message });
      throw error;
    }
  }
  
  /**
   * Get no-show rate for a specific organizer
   */
  static async getNoShowRate(organizerId, startDate, endDate) {
    try {
      const dateFilter = {};
      if (startDate) dateFilter.date_debut = { $gte: startDate };
      if (endDate) dateFilter.date_fin = { $lte: endDate };
      
      // Get all approved bookings for the organizer
      const totalApproved = await Inscription.countDocuments({
        organisateur_id: organizerId,
        statut: 'approuvee',
        ...dateFilter
      });
      
      if (totalApproved === 0) {
        return { rate: 0, totalApproved: 0, totalNoShow: 0 };
      }
      
      // Get no-show count
      const totalNoShow = await Inscription.countDocuments({
        organisateur_id: organizerId,
        'noShow.isNoShow': true,
        ...dateFilter
      });
      
      const rate = (totalNoShow / totalApproved) * 100;
      
      return {
        rate: Math.round(rate * 10) / 10, // Round to 1 decimal
        totalApproved,
        totalNoShow,
        startDate,
        endDate
      };
    } catch (error) {
      logger.error('Failed to calculate no-show rate', { organizerId, error: error.message });
      throw error;
    }
  }
  
  /**
   * Get no-show statistics for all activities
   */
  static async getGlobalNoShowStats(startDate, endDate) {
    try {
      const dateFilter = {};
      if (startDate) dateFilter.createdAt = { $gte: startDate };
      if (endDate) dateFilter.createdAt = { $lte: endDate };
      
      const totalApproved = await Inscription.countDocuments({
        statut: 'approuvee',
        ...dateFilter
      });
      
      const totalNoShow = await Inscription.countDocuments({
        'noShow.isNoShow': true,
        ...dateFilter
      });
      
      const totalCheckedIn = await Inscription.countDocuments({
        statut: 'verifie',
        ...dateFilter
      });
      
      const rate = totalApproved > 0 ? (totalNoShow / totalApproved) * 100 : 0;
      
      return {
        rate: Math.round(rate * 10) / 10,
        totalApproved,
        totalNoShow,
        totalCheckedIn,
        checkInRate: totalApproved > 0 ? (totalCheckedIn / totalApproved) * 100 : 0
      };
    } catch (error) {
      logger.error('Failed to get global no-show stats', { error: error.message });
      throw error;
    }
  }
  
  /**
   * Manually mark a booking as no-show (for admin use)
   */
  static async markAsNoShow(bookingId, markedBy, reason) {
    try {
      const booking = await Inscription.findById(bookingId);
      
      if (!booking) {
        throw new Error('Booking not found');
      }
      
      if (booking.statut !== 'approuvee') {
        throw new Error(`Cannot mark as no-show. Current status: ${booking.statut}`);
      }
      
      if (booking.qr_used_at) {
        throw new Error('Booking already checked-in');
      }
      
      booking.noShow = {
        isNoShow: true,
        markedAt: new Date(),
        markedBy,
        reason
      };
      booking.statut = 'no_show';
      
      await booking.save();
      
      logger.info('Booking manually marked as no-show', { bookingId, markedBy });
      
      return booking;
    } catch (error) {
      logger.error('Failed to mark booking as no-show', { bookingId, error: error.message });
      throw error;
    }
  }
  
  /**
   * Undo no-show mark (for admin use)
   */
  static async undoNoShow(bookingId) {
    try {
      const booking = await Inscription.findById(bookingId);
      
      if (!booking) {
        throw new Error('Booking not found');
      }
      
      if (!booking.noShow?.isNoShow) {
        throw new Error('Booking is not marked as no-show');
      }
      
      booking.noShow = {
        isNoShow: false,
        markedAt: null,
        markedBy: null,
        reason: null
      };
      booking.statut = 'approuvee'; // Restore to approved
      
      await booking.save();
      
      logger.info('No-show mark removed', { bookingId });
      
      return booking;
    } catch (error) {
      logger.error('Failed to undo no-show', { bookingId, error: error.message });
      throw error;
    }
  }
  
  /**
   * Get no-show bookings list with pagination
   */
  static async getNoShowBookings(filters = {}, page = 1, limit = 20) {
    try {
      const skip = (page - 1) * limit;
      
      const query = { 'noShow.isNoShow': true, ...filters };
      
      const [bookings, total] = await Promise.all([
        Inscription.find(query)
          .populate('touriste_id', 'fullname email avatar')
          .populate('activite_id', 'titre date_debut date_fin lieu')
          .populate('organisateur_id', 'fullname email')
          .sort({ 'noShow.markedAt': -1 })
          .skip(skip)
          .limit(limit),
        Inscription.countDocuments(query)
      ]);
      
      return {
        bookings,
        pagination: {
          page,
          limit,
          total,
          pages: Math.ceil(total / limit)
        }
      };
    } catch (error) {
      logger.error('Failed to get no-show bookings', { error: error.message });
      throw error;
    }
  }
}

module.exports = NoShowService;
