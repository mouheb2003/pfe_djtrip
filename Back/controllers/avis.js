const Avis = require("../models/avis");
const Activite = require("../models/activite");
const Organisator = require("../models/organisator");
const Inscription = require("../models/inscription");
const notificationEventBus = require("../services/notificationEventBus");

// ─── GET /avis/touriste/:touristeId ─────────────────────────────────────────
// Get all reviews submitted by a tourist (public)
exports.getTouristeReviews = async (req, res) => {
  try {
    const { touristeId } = req.params;
    
    const reviews = await Avis.find({ touriste_id: touristeId })
      .populate('activite_id', 'titre')
      .populate('organisateur_id', 'fullname')
      .sort({ createdAt: -1 });
    
    res.json({
      success: true,
      count: reviews.length,
      avis: reviews,
    });
  } catch (error) {
    console.error('Error fetching tourist reviews:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Error fetching reviews' 
    });
  }
};

// ─── Helper: recalculate and persist activity stats ─────────────────────────
async function refreshActiviteStats(activiteId) {
  try {
    const all = await Avis.find({ activite_id: activiteId, type: "activite" });
    const noteMoyenne =
      all.length > 0
        ? Math.round((all.reduce((s, a) => s + a.note, 0) / all.length) * 10) / 10
        : 0;
    await Activite.findByIdAndUpdate(activiteId, {
      note_moyenne: noteMoyenne,
      nombre_avis: all.length,
    });
  } catch (error) {
    console.error('[refreshActiviteStats] Error:', error);
  }
}

// ─── Helper: recalculate and persist organizer stats ─────────────────────────
async function refreshOrganisateurStats(organisateurId) {
  try {
    // Get all activities for this organizer that have reviews
    const activities = await Activite.find({ 
      organisateur_id: organisateurId,
      nombre_avis: { $gt: 0 }
    });

    // Calculate average of activity ratings
    const noteMoyenne =
      activities.length > 0
        ? Math.round((activities.reduce((s, a) => s + a.note_moyenne, 0) / activities.length) * 10) / 10
        : 0;

    // Total count of reviews across all activities
    const totalAvis = activities.reduce((s, a) => s + a.nombre_avis, 0);

    await Organisator.findByIdAndUpdate(organisateurId, {
      note_moyenne: noteMoyenne,
      nombre_avis: totalAvis,
    });
  } catch (error) {
    console.error('[refreshOrganisateurStats] Error:', error);
  }
}

// ─── POST /avis/activite/:activiteId ─────────────────────────────────────────
// Tourist submits a review for an activity they participated in
exports.submitActivityReview = async (req, res) => {
  try {
    const { activiteId } = req.params;
    const touristeId = req.user.userId;
    const { note, commentaire, tags } = req.body;

    if (!note || note < 1 || note > 5) {
      return res.status(400).json({ message: "Note must be between 1 and 5" });
    }

    // Verify the tourist has an approved inscription for this activity
    const inscription = await Inscription.findOne({
      touriste_id: touristeId,
      activite_id: activiteId,
      statut: "approuvee",
    });
    if (!inscription) {
      return res.status(403).json({
        message:
          "You must have participated in this activity to leave a review",
      });
    }

    // Check if organizer exists and is active
    const User = require("../models/user");
    const organizer = await User.findById(inscription.organisateur_id);
    if (!organizer) {
      return res.status(404).json({ message: "Organizer not found" });
    }
    if (organizer.accountStatus !== "active") {
      return res.status(403).json({
        message: "Cannot review activities from inactive organizers",
      });
    }

    const avis = await Avis.create({
      touriste_id: touristeId,
      activite_id: activiteId,
      organisateur_id: inscription.organisateur_id,
      type: "activite",
      note,
      commentaire: commentaire?.trim() || null,
      tags: tags && Array.isArray(tags) ? tags.slice(0, 3) : [], // Max 3 tags
      inscription_id: inscription._id,
    });

    // Mark inscription as reviewed
    await inscription.marquerCommeReviewed();

    await refreshActiviteStats(activiteId);
    await refreshOrganisateurStats(inscription.organisateur_id);

    // Emit review created event for notification
    try {
      const tourist = await require("../models/touriste").findById(touristeId);
      notificationEventBus.emitReviewCreated({
        organizerId: inscription.organisateur_id,
        touristName: tourist?.fullname || 'A tourist',
        activityTitle: activity.titre,
        rating: note,
        reviewId: avis._id,
      });
    } catch (notifError) {
      console.warn("Failed to send review notification:", notifError.message);
    }

    res.status(201).json({
      message: "Review submitted successfully",
      avis,
      review: {
        id: avis._id,
        rating: note,
        comment: commentaire,
        tags: tags || [],
        createdAt: avis.createdAt
      }
    });
  } catch (e) {
    if (e.code === 11000) {
      return res
        .status(400)
        .json({ message: "You have already reviewed this activity" });
    }
    res.status(500).json({ message: e.message });
  }
};

// ─── POST /avis/organisateur/:organisateurId ─────────────────────────────────
// Tourist submits a rating for an organizer they have participated with
exports.submitOrganisateurRating = async (req, res) => {
  try {
    const { organisateurId } = req.params;
    const touristeId = req.user.userId;
    const { note, commentaire, tags } = req.body;

    if (!note || note < 1 || note > 5) {
      return res.status(400).json({ message: "Note must be between 1 and 5" });
    }

    // Check if organizer exists and is active
    const User = require("../models/user");
    const organizer = await User.findById(organisateurId);
    if (!organizer) {
      return res.status(404).json({ message: "Organizer not found" });
    }
    if (organizer.accountStatus !== "active") {
      return res.status(403).json({
        message: "Cannot rate inactive organizers",
      });
    }

    // Verify the tourist has an approved inscription for at least one of this organizer's activities
    const inscription = await Inscription.findOne({
      touriste_id: touristeId,
      organisateur_id: organisateurId,
      statut: "approuvee",
    });
    if (!inscription) {
      return res.status(403).json({
        message:
          "You must have participated in one of this organizer's activities to rate them",
      });
    }

    const avis = await Avis.create({
      touriste_id: touristeId,
      organisateur_id: organisateurId,
      type: "organisateur",
      note,
      commentaire: commentaire?.trim() || null,
      tags: tags && Array.isArray(tags) ? tags.slice(0, 3) : [], // Max 3 tags
      inscription_id: inscription._id,
    });

    await refreshOrganisateurStats(organisateurId);

    res.status(201).json({
      message: "Rating submitted successfully",
      avis,
      review: {
        id: avis._id,
        rating: note,
        comment: commentaire,
        tags: tags || [],
        createdAt: avis.createdAt
      }
    });
  } catch (e) {
    if (e.code === 11000) {
      return res
        .status(400)
        .json({ message: "You have already rated this organizer" });
    }
    res.status(500).json({ message: e.message });
  }
};

// ─── GET /avis/activite/:activiteId ──────────────────────────────────────────
// Get all reviews for an activity (public)
exports.getActivityReviews = async (req, res) => {
  try {
    const { activiteId } = req.params;
    const avis = await Avis.find({ activite_id: activiteId, type: "activite" })
      .populate("touriste_id", "fullname avatar")
      .sort({ createdAt: -1 });
    res.json(avis);
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
};

// ─── GET /avis/organisateur/:organisateurId ───────────────────────────────────
// Get all ratings for an organizer (public) - includes both direct organizer reviews and activity reviews
exports.getOrganisateurRatings = async (req, res) => {
  try {
    const { organisateurId } = req.params;
    console.log('🔍 getOrganisateurRatings called with ID:', organisateurId);
    
    // Get all activities for this organizer
    const Activite = require("../models/activite");
    const activities = await Activite.find({ organisateur_id: organisateurId }).select('_id');
    const activityIds = activities.map(a => a._id);
    
    console.log('🔍 Found activities for organizer:', activityIds.length);
    
    // Get direct organizer reviews
    const organizerReviews = await Avis.find({
      organisateur_id: organisateurId,
      type: "organisateur",
    })
      .populate("touriste_id", "fullname avatar")
      .sort({ createdAt: -1 });
    
    // Get activity reviews for this organizer's activities
    const activityReviews = await Avis.find({
      activite_id: { $in: activityIds },
      type: "activite",
    })
      .populate("touriste_id", "fullname avatar")
      .sort({ createdAt: -1 });
    
    const allReviews = [...organizerReviews, ...activityReviews];
    console.log('🔍 Found reviews - Direct:', organizerReviews.length, 'Activity:', activityReviews.length, 'Total:', allReviews.length);
    
    res.json(allReviews);
  } catch (e) {
    console.error('❌ Error in getOrganisateurRatings:', e);
    res.status(500).json({ message: e.message });
  }
};

// ─── GET /avis/my-review/activite/:activiteId ────────────────────────────────
// Check if the authenticated tourist already reviewed an activity
exports.getMyActivityReview = async (req, res) => {
  try {
    const { activiteId } = req.params;
    const touristeId = req.user.userId;
    const avis = await Avis.findOne({
      touriste_id: touristeId,
      activite_id: activiteId,
      type: "activite",
    });
    res.json({ hasReviewed: !!avis, avis: avis || null });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
};

// ─── GET /avis/my-rating/organisateur/:organisateurId ───────────────────────
// Check if the authenticated tourist already rated an organizer
exports.getMyOrganisateurRating = async (req, res) => {
  try {
    const { organisateurId } = req.params;
    const touristeId = req.user.userId;
    const avis = await Avis.findOne({
      touriste_id: touristeId,
      organisateur_id: organisateurId,
      type: "organisateur",
    });
    res.json({ hasRated: !!avis, avis: avis || null });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
};

// ─── PUT /avis/:avisId ───────────────────────────────────────────────────────
// Tourist updates their own review/rating
exports.updateAvis = async (req, res) => {
  try {
    const { avisId } = req.params;
    const touristeId = req.user.userId;
    const { note, commentaire, tags } = req.body;

    if (!note || note < 1 || note > 5) {
      return res.status(400).json({ message: "Note must be between 1 and 5" });
    }

    const avis = await Avis.findOne({ _id: avisId, touriste_id: touristeId });
    if (!avis) {
      return res
        .status(404)
        .json({ message: "Review not found or not yours to update" });
    }

    // Check if organizer is still active before allowing update
    const User = require("../models/user");
    if (avis.type === "activite" && avis.activite_id) {
      const inscription = await Inscription.findOne({
        touriste_id: touristeId,
        activite_id: avis.activite_id,
        statut: "approuvee",
      });
      if (inscription) {
        const organizer = await User.findById(inscription.organisateur_id);
        if (organizer && organizer.accountStatus !== "active") {
          return res.status(403).json({
            message: "Cannot update review for inactive organizers",
          });
        }
      }
    } else if (avis.type === "organisateur" && avis.organisateur_id) {
      const organizer = await User.findById(avis.organisateur_id);
      if (organizer && organizer.accountStatus !== "active") {
        return res.status(403).json({
          message: "Cannot update rating for inactive organizers",
        });
      }
    }

    // Update the review
    avis.note = note;
    avis.commentaire = commentaire?.trim() || null;
    avis.tags = tags && Array.isArray(tags) ? tags.slice(0, 3) : [];
    await avis.save();

    // Refresh stats
    const { type, activite_id, organisateur_id } = avis;
    if (type === "activite" && activite_id) {
      await refreshActiviteStats(activite_id);
    } else if (type === "organisateur" && organisateur_id) {
      await refreshOrganisateurStats(organisateur_id);
    }

    res.json({
      message: "Review updated successfully",
      avis,
      review: {
        id: avis._id,
        rating: note,
        comment: avis.commentaire,
        tags: avis.tags,
        updatedAt: avis.updatedAt
      }
    });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
};

// ─── DELETE /avis/:avisId ────────────────────────────────────────────────────
// Tourist deletes their own review/rating
exports.deleteAvis = async (req, res) => {
  try {
    const { avisId } = req.params;
    const touristeId = req.user.userId;

    const avis = await Avis.findOne({ _id: avisId, touriste_id: touristeId });
    if (!avis) {
      return res
        .status(404)
        .json({ message: "Review not found or not yours to delete" });
    }

    const { type, activite_id, organisateur_id } = avis;
    await avis.deleteOne();

    if (type === "activite" && activite_id) {
      await refreshActiviteStats(activite_id);
    } else if (type === "organisateur" && organisateur_id) {
      await refreshOrganisateurStats(organisateur_id);
    }

    res.json({ message: "Review deleted successfully" });
  } catch (error) {
    console.error("Error deleting review:", error);
    res.status(500).json({ message: "Error deleting review" });
  }
};

// ─── DELETE /avis/admin/:avisId ────────────────────────────────────────────────
// Admin deletes any review
exports.deleteAvisAdmin = async (req, res) => {
  try {
    const { avisId } = req.params;

    const avis = await Avis.findById(avisId);
    if (!avis) {
      return res
        .status(404)
        .json({ message: "Review not found" });
    }

    const { type, activite_id, organisateur_id } = avis;
    await avis.deleteOne();

    if (type === "activite" && activite_id) {
      await refreshActiviteStats(activite_id);
    } else if (type === "organisateur" && organisateur_id) {
      await refreshOrganisateurStats(organisateur_id);
    }

    res.json({ message: "Review deleted successfully by admin" });
  } catch (error) {
    console.error("Error deleting review by admin:", error);
    res.status(500).json({ message: "Error deleting review" });
  }
};
