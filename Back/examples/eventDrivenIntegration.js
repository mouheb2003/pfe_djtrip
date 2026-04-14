/**
 * Example: Updating Existing Controllers to Use Event-Driven Notification System
 * 
 * This file demonstrates how to refactor existing controllers to emit events
 * instead of directly calling notification services.
 */

const notificationEventBus = require('../services/notificationEventBus');

// ============================================
// BEFORE: Direct notification calls (Old Approach)
// ============================================

// controllers/inscription.js (OLD)
async function approveBooking(req, res) {
  try {
    const booking = await Inscription.findByIdAndUpdate(
      req.params.id,
      { status: 'APPROVED' },
      { new: true }
    );

    // ❌ Direct notification call - tightly coupled
    const { sendBookingApprovedNotification } = require('../services/notificationService');
    await sendBookingApprovedNotification({
      touristId: booking.touriste_id,
      activityTitle: booking.activite_id.titre,
      bookingId: booking._id,
    });

    res.json({ success: true, booking });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
}

// ============================================
// AFTER: Event-driven approach (New Approach)
// ============================================

// controllers/inscription.js (NEW)
async function approveBooking(req, res) {
  try {
    const booking = await Inscription.findByIdAndUpdate(
      req.params.id,
      { status: 'APPROVED' },
      { new: true }
    ).populate('activite_id touriste_id organisateur_id');

    // ✅ Emit event - decoupled from notification logic
    notificationEventBus.emitBookingApproved({
      touristId: booking.touriste_id._id,
      organizerId: booking.organisateur_id._id,
      activityTitle: booking.activite_id.titre,
      bookingId: booking._id,
      activityId: booking.activite_id._id,
    });

    res.json({ success: true, booking });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
}

// ============================================
// More Examples for Different Controllers
// ============================================

// controllers/activite.js - Activity Creation
async function createActivity(req, res) {
  try {
    const activity = await Activite.create(req.body);

    // Get organizer's followers
    const followers = await Follow.find({ followingId: activity.organisateur_id });
    const followerIds = followers.map(f => f.followerId);

    // ✅ Emit activity.created event
    notificationEventBus.emitActivityCreated({
      organizerId: activity.organisateur_id,
      organizerName: activity.organisateur_id.fullname,
      activityTitle: activity.titre,
      activityId: activity._id,
      followerIds,
    });

    res.json({ success: true, activity });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
}

// controllers/message.js - New Message
async function sendMessage(req, res) {
  try {
    const message = await Message.create(req.body);

    // ✅ Emit message.received event
    notificationEventBus.emitMessageReceived({
      recipientId: message.recipientId,
      senderId: message.senderId,
      senderName: message.senderName,
      conversationId: message.conversationId,
      messageId: message._id,
      message: message.content,
    });

    res.json({ success: true, message });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
}

// controllers/avis.js - New Review
async function createReview(req, res) {
  try {
    const review = await Avis.create(req.body);

    // ✅ Emit review.created event
    notificationEventBus.emitReviewCreated({
      organizerId: review.organisateur_id,
      touristId: review.touriste_id,
      touristName: review.touriste_id.fullname,
      activityTitle: review.activite_id.titre,
      rating: review.note,
      reviewId: review._id,
    });

    res.json({ success: true, review });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
}

// controllers/follow.js - New Follow
async function createFollow(req, res) {
  try {
    const follow = await Follow.create(req.body);

    // ✅ Emit follow.created event
    notificationEventBus.emitFollowCreated({
      userId: follow.followingId,
      followerId: follow.followerId,
      followerName: follow.followerId.fullname,
    });

    res.json({ success: true, follow });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
}

// controllers/payment.js - Payment Completion
async function completePayment(req, res) {
  try {
    const payment = await Payment.findByIdAndUpdate(
      req.params.id,
      { status: 'COMPLETED' },
      { new: true }
    ).populate('inscription_id');

    // ✅ Emit payment.completed event
    notificationEventBus.emitPaymentCompleted({
      userId: payment.user_id,
      amount: payment.amount,
      activityTitle: payment.inscription_id.activite_id.titre,
      paymentId: payment._id,
    });

    res.json({ success: true, payment });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
}

// controllers/inscription.js - Check-in
async function performCheckIn(req, res) {
  try {
    const booking = await Inscription.findByIdAndUpdate(
      req.params.id,
      { checkin_status: 'COMPLETED', checkin_date: new Date() },
      { new: true }
    ).populate('activite_id');

    // ✅ Emit booking.checkin event
    notificationEventBus.emitBookingCheckIn({
      touristId: booking.touriste_id,
      activityTitle: booking.activite_id.titre,
      bookingId: booking._id,
      activityId: booking.activite_id._id,
    });

    res.json({ success: true, booking });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
}

// ============================================
// System Announcement Example (Admin)
// ============================================

// controllers/admin.js - System Announcement
async function sendSystemAnnouncement(req, res) {
  try {
    const { title, message, targetRole = 'all', priority = 'high' } = req.body;

    // Get users based on target role
    let userIds;
    if (targetRole === 'all') {
      userIds = await User.find({ accountStatus: 'active' }).distinct('_id');
    } else {
      userIds = await User.find({ 
        accountStatus: 'active',
        role: targetRole 
      }).distinct('_id');
    }

    // ✅ Emit system.announcement event
    notificationEventBus.emitSystemAnnouncement({
      title,
      message,
      userIds,
      targetRole,
      priority,
      data: req.body.data || {},
    });

    res.json({ success: true, message: 'Announcement sent' });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
}

module.exports = {
  approveBooking,
  createActivity,
  sendMessage,
  createReview,
  createFollow,
  completePayment,
  performCheckIn,
  sendSystemAnnouncement,
};
