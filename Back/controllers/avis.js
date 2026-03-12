const Avis = require("../models/avis");
const Activite = require("../models/activite");
const Organisator = require("../models/organisator");
const Inscription = require("../models/inscription");

// ─── Helper: recalculate and persist activity stats ─────────────────────────
async function refreshActiviteStats(activiteId) {
  const all = await Avis.find({ activite_id: activiteId, type: "activite" });
  const noteMoyenne =
    all.length > 0
      ? Math.round((all.reduce((s, a) => s + a.note, 0) / all.length) * 10) / 10
      : 0;
  await Activite.findByIdAndUpdate(activiteId, {
    note_moyenne: noteMoyenne,
    nombre_avis: all.length,
  });
}

// ─── Helper: recalculate and persist organizer stats ─────────────────────────
async function refreshOrganisateurStats(organisateurId) {
  const all = await Avis.find({
    organisateur_id: organisateurId,
    type: "organisateur",
  });
  const noteMoyenne =
    all.length > 0
      ? Math.round((all.reduce((s, a) => s + a.note, 0) / all.length) * 10) / 10
      : 0;
  await Organisator.findByIdAndUpdate(organisateurId, {
    note_moyenne: noteMoyenne,
    nombre_avis: all.length,
  });
}

// ─── POST /avis/activite/:activiteId ─────────────────────────────────────────
// Tourist submits a review for an activity they participated in
exports.submitActivityReview = async (req, res) => {
  try {
    const { activiteId } = req.params;
    const touristeId = req.user.userId;
    const { note, commentaire } = req.body;

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

    const avis = await Avis.create({
      touriste_id: touristeId,
      activite_id: activiteId,
      organisateur_id: inscription.organisateur_id,
      type: "activite",
      note,
      commentaire: commentaire?.trim() || null,
      inscription_id: inscription._id,
    });

    await refreshActiviteStats(activiteId);

    res.status(201).json({ message: "Review submitted successfully", avis });
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
    const { note, commentaire } = req.body;

    if (!note || note < 1 || note > 5) {
      return res.status(400).json({ message: "Note must be between 1 and 5" });
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
      inscription_id: inscription._id,
    });

    await refreshOrganisateurStats(organisateurId);

    res.status(201).json({ message: "Rating submitted successfully", avis });
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
// Get all ratings for an organizer (public)
exports.getOrganisateurRatings = async (req, res) => {
  try {
    const { organisateurId } = req.params;
    const avis = await Avis.find({
      organisateur_id: organisateurId,
      type: "organisateur",
    })
      .populate("touriste_id", "fullname avatar")
      .sort({ createdAt: -1 });
    res.json(avis);
  } catch (e) {
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
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
};
