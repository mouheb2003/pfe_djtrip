const Inscription = require("../models/inscription");
const Activite = require("../models/activite");
const Touriste = require("../models/touriste");
const CheckinLog = require("../models/checkinLog");
const Avis = require("../models/avis");
const QRCode = require("qrcode");
const jwt = require("jsonwebtoken");
const mongoose = require("mongoose");
const emailService = require("../services/email");
const { createActivityLog } = require("../services/activityLogService");
const notificationEventBus = require("../services/notificationEventBus");

const QR_BOOKING_SECRET =
  process.env.QR_BOOKING_SECRET || process.env.JWT_SECRET;

function normalizeDateValue(value) {
  if (!value) return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

function getActivityDeadline(activite) {
  return (
    normalizeDateValue(activite?.date_fin) ||
    normalizeDateValue(activite?.date_debut)
  );
}

function createBookingQrToken(inscription, activite) {
  if (!QR_BOOKING_SECRET) {
    throw new Error("QR booking secret is not configured");
  }

  const deadline = getActivityDeadline(activite);
  const expiresInSeconds = deadline
    ? Math.max(300, Math.floor((deadline.getTime() - Date.now()) / 1000))
    : 86400;

  return jwt.sign(
    {
      purpose: "booking-checkin",
      bookingId: inscription._id.toString(),
      organizerId: inscription.organisateur_id.toString(),
      activityId: inscription.activite_id.toString(),
    },
    QR_BOOKING_SECRET,
    { expiresIn: expiresInSeconds },
  );
}

// Export helper functions for use in other controllers
module.exports.createBookingQrToken = createBookingQrToken;
module.exports.getActivityDeadline = getActivityDeadline;

function parseQrPayload(qrData) {
  const rawValue = (qrData || "").toString().trim();
  if (!rawValue) {
    return { valid: false, reason: "QR code is empty" };
  }

  const prefix = "DJTRIP_BOOKING:";
  const payload = rawValue.startsWith(prefix)
    ? rawValue.slice(prefix.length).trim()
    : rawValue;

  if (!payload) {
    return { valid: false, reason: "QR code is invalid" };
  }

  if (payload.includes(".")) {
    try {
      const decoded = jwt.verify(payload, QR_BOOKING_SECRET);
      if (!decoded || decoded.purpose !== "booking-checkin") {
        return { valid: false, reason: "QR token is not valid" };
      }

      return {
        valid: true,
        bookingId: decoded.bookingId,
        tokenType: "signed",
        tokenPayload: decoded,
      };
    } catch (error) {
      return { valid: false, reason: "QR token is expired or invalid" };
    }
  }

  return {
    valid: true,
    bookingId: payload,
    tokenType: "legacy",
  };
}

async function inspectBookingForQr({ qrData, organiserId, markUsed = false }) {
  try {
    console.log('[INSPECT BOOKING] Function called');
    console.log('[INSPECT BOOKING] QR Data:', qrData);
    console.log('[INSPECT BOOKING] Organiser ID:', organiserId);
    console.log('[INSPECT BOOKING] Mark used:', markUsed);

    if (!QR_BOOKING_SECRET) {
      console.log('[INSPECT BOOKING] QR secret missing');
      return {
        ok: false,
        statusCode: 500,
        code: "QR_SECRET_MISSING",
        message: "QR booking secret is not configured",
      };
    }

    const parsed = parseQrPayload(qrData);
    console.log('[INSPECT BOOKING] Parsed result:', parsed);
    if (!parsed.valid) {
      return {
        ok: false,
        statusCode: 400,
        code: "INVALID_TOKEN",
        message: parsed.reason,
      };
    }

    const inscription = await Inscription.findById(parsed.bookingId)
      .populate("touriste_id", "fullname email avatar num_tel")
      .populate("activite_id")
      .populate("organisateur_id", "fullname email avatar num_tel");

    if (!inscription) {
      return {
        ok: false,
        statusCode: 404,
        code: "BOOKING_NOT_FOUND",
        message: "Booking not found",
      };
    }

    // organisateur_id is populated, so we need to compare _id
    const bookingOrganizerId = inscription.organisateur_id._id
      ? inscription.organisateur_id._id.toString()
      : inscription.organisateur_id.toString();

    const organiserIdString = organiserId.toString().trim();

    console.log('[QR VALIDATION] Booking organizer ID:', bookingOrganizerId);
    console.log('[QR VALIDATION] Request organizer ID:', organiserIdString);
    console.log('[QR VALIDATION] Match:', bookingOrganizerId === organiserIdString);

    if (bookingOrganizerId !== organiserIdString) {
      return {
        ok: false,
        statusCode: 403,
        code: "UNAUTHORIZED",
        message: "Unauthorized to verify this booking",
      };
    }

    console.log('[QR VALIDATION] Organizer ID check passed');
    console.log('[QR VALIDATION] Booking status:', inscription.statut);
    console.log('[QR VALIDATION] QR used at:', inscription.qr_used_at);

    const activityDeadline = getActivityDeadline(inscription.activite_id);
    const activityStartDate = normalizeDateValue(inscription.activite_id?.date_debut);
    const now = new Date();
    const activityStartDateWithGrace = activityStartDate ? new Date(activityStartDate.getTime() + 15 * 60 * 1000) : null; // +15 minutes
    console.log('[QR VALIDATION] Activity start date:', activityStartDate);
    console.log('[QR VALIDATION] Activity start date + 15min:', activityStartDateWithGrace);
    console.log('[QR VALIDATION] Activity deadline:', activityDeadline);
    console.log('[QR VALIDATION] Current time:', now);
    console.log('[QR VALIDATION] Is expired:', activityDeadline && now > activityDeadline);

    // Check if activity has already started (with 15 min grace period)
    if (activityStartDateWithGrace && now >= activityStartDateWithGrace) {
      return {
        ok: false,
        statusCode: 400,
        code: "ACTIVITY_ALREADY_STARTED",
        message: "This activity has already started",
        booking: inscription,
      };
    }

    if (activityDeadline && now > activityDeadline) {
      return {
        ok: false,
        statusCode: 400,
        code: "ACTIVITY_EXPIRED",
        message: "This activity has already passed",
        booking: inscription,
      };
    }

    if (inscription.statut === "verified" || inscription.qr_used_at) {
      return {
        ok: false,
        statusCode: 400,
        code: "ALREADY_USED",
        message: "This booking has already been used",
        booking: inscription,
      };
    }

    if (inscription.statut !== "approved") {
      console.log('[QR VALIDATION] Status check failed - not approved');
      return {
        ok: false,
        statusCode: 400,
        code: "NOT_CONFIRMED",
        message: `Booking must be confirmed first. Current status: ${inscription.statut}`,
        booking: inscription,
      };
    }

    console.log('[QR VALIDATION] All checks passed');

    if (markUsed) {
      await inscription.marquerCommeUtilise();
    }

    return {
      ok: true,
      statusCode: 200,
      code: markUsed ? "MARKED_USED" : "VALID",
      message: markUsed
        ? "Booking marked as used"
        : "Booking is valid for check-in",
      booking: inscription,
      tokenType: parsed.tokenType,
      activityDeadline,
    };
  } catch (error) {
    console.error('[INSPECT BOOKING] Error:', error);
    return {
      ok: false,
      statusCode: 500,
      code: "INTERNAL_ERROR",
      message: "Error inspecting booking",
      error: error.message,
    };
  }
}

// Auto-expire pending requests for activities whose start date has passed.
// Business rule: if organizer did not respond before activity start date,
// request is automatically cancelled for the tourist.
async function expirePendingInscriptionsForEndedActivities() {
  try {
    const now = new Date();
    const startedActivityIds = await Activite.find({
      date_debut: { $lt: now },
    }).distinct("_id");

    if (!startedActivityIds.length) return 0;

    const result = await Inscription.updateMany(
      {
        activite_id: { $in: startedActivityIds },
        statut: "en_attente",
      },
      {
        $set: {
          statut: "annulee",
          date_reponse: now,
          message_organisateur:
            "Automatically cancelled because the activity start date has passed without organizer response.",
        },
      },
    );

    return result.modifiedCount || 0;
  } catch (error) {
    console.error('[EXPIRE PENDING] Error:', error);
    return 0;
  }
}
exports.expirePendingInscriptionsForEndedActivities = expirePendingInscriptionsForEndedActivities;
exports.expirePaidPendingInscriptions = expirePendingInscriptionsForEndedActivities;

// Create a new registration (Tourist registers for an activity)
// Creates a pending request that organizer can approve or reject
exports.createInscription = async (req, res) => {
  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const touristeId = req.user.userId; // Logged-in tourist ID
    const { activite_id, nombre_participants, message_touriste } = req.body;
    const nombreParticipants = Number.parseInt(nombre_participants, 10);

    console.log('[INSCRIPTION] Creating inscription:', {
      touristeId,
      activite_id,
      nombre_participants,
      nombreParticipants
    });

    if (!Number.isInteger(nombreParticipants) || nombreParticipants < 1) {
      await session.abortTransaction();
      console.log('[INSCRIPTION] Invalid participants count');
      return res.status(400).json({
        message: "Participants count must be a positive integer",
      });
    }

    // Verify the user is a tourist
    const touriste = await Touriste.findById(touristeId).session(session);
    if (!touriste) {
      await session.abortTransaction();
      console.log('[INSCRIPTION] User is not a tourist');
      return res.status(403).json({
        message: "Only tourists can register for activities",
      });
    }

    // Verify the activity exists and is active
    const activite = await Activite.findById(activite_id).session(session);
    if (!activite) {
      await session.abortTransaction();
      console.log('[INSCRIPTION] Activity not found');
      return res.status(404).json({ message: "Activity not found" });
    }

    console.log('[INSCRIPTION] Activity status:', activite.statut);

    if (activite.statut !== "active") {
      await session.abortTransaction();
      console.log('[INSCRIPTION] Activity not active');
      return res.status(400).json({
        message: "This activity is no longer available",
      });
    }
    if (new Date(activite.date_fin) <= new Date()) {
      await session.abortTransaction();
      console.log('[INSCRIPTION] Activity already ended');
      return res.status(400).json({
        message: "This activity has already ended",
      });
    }

    // Check if the tourist is already registered for this activity
    const inscriptionExistante = await Inscription.findOne({
      touriste_id: touristeId,
      activite_id: activite_id,
      statut: { $in: ["approved", "verified", "pending"] },
    }).session(session);

    if (inscriptionExistante) {
      await session.abortTransaction();
      console.log('[INSCRIPTION] User already registered with active status');
      return res.status(400).json({
        message: "You are already registered for this activity",
      });
    }

    // Check for booking overlaps
    const newActivityStartDate = new Date(activite.date_debut);
    const newActivityEndDate = new Date(activite.date_fin);
    
    const overlapCheck = await Inscription.checkBookingOverlap(
      touristeId,
      newActivityStartDate,
      newActivityEndDate
    );
    
    if (overlapCheck.hasOverlap) {
      await session.abortTransaction();
      console.log('[INSCRIPTION] Booking overlap detected:', overlapCheck.conflictingBooking);
      return res.status(409).json({
        message: "You already have a booking during this time period",
        conflict: {
          activityTitle: overlapCheck.conflictingBooking.activityTitle,
          startDate: overlapCheck.conflictingBooking.startDate,
          endDate: overlapCheck.conflictingBooking.endDate,
          status: overlapCheck.conflictingBooking.status
        }
      });
    }

    // Calculate total price (for reference)
    const prixTotal = activite.prix * nombreParticipants;

    // Create the registration with pending status
    const inscription = new Inscription({
      touriste_id: touristeId,
      activite_id: activite_id,
      organisateur_id: activite.organisateur_id,
      nombre_participants: nombreParticipants,
      message_touriste,
      prix_total: prixTotal,
      statut: "pending",
    });

    await inscription.save({ session });

    await session.commitTransaction();

    // Emit event for new booking notification
    try {
      notificationEventBus.emitBookingCreated({
        organizerId: activite.organisateur_id,
        touristId: touriste._id,
        touristName: touriste.fullname || 'Un touriste',
        activityTitle: activite.titre,
        bookingId: inscription._id.toString(),
      });
    } catch (notifError) {
      console.warn('Failed to emit booking created event:', notifError.message);
    }

    try {
      await createActivityLog({
        actorId: touristeId,
        actorName: touriste.fullname,
        action: "book_activity",
        targetType: "booking",
        targetId: inscription._id,
        templateKey: "book_activity",
        metadata: {
          count: nombreParticipants,
          activityId: activite_id,
          title: activite.titre,
        },
      });
    } catch (logError) {
      console.warn(
        "Activity log failed for createInscription:",
        logError.message,
      );
    }

    // Return pending registration
    const inscriptionPopulated = await Inscription.findById(inscription._id)
      .populate("activite_id", "titre date_debut date_fin lieu prix")
      .populate("touriste_id", "fullname email avatar");

    res.status(201).json({
      message: "Registration request sent successfully. Waiting for organizer approval.",
      inscription: inscriptionPopulated,
    });
  } catch (error) {
    await session.abortTransaction();
    res.status(500).json({
      message: "Error creating registration",
      error: error.message,
    });
  } finally {
    session.endSession();
  }
};

// Get registrations for a tourist
exports.getInscriptionsByTouriste = async (req, res) => {
  try {
    const touristeId = req.user.userId;
    const { statut } = req.query;

    const filter = { touriste_id: touristeId };
    if (statut) {
      filter.statut = statut;
    }

    const inscriptions = await Inscription.find(filter)
      .populate("activite_id")
      .populate("organisateur_id", "fullname email avatar num_tel")
      .sort({ createdAt: -1 });

    res.status(200).json({
      count: inscriptions.length,
      inscriptions,
    });
  } catch (error) {
    res.status(500).json({
      message: "Error retrieving registrations",
      error: error.message,
    });
  }
};

// Get my bookings for Tourist (all requests, bucketed by status)
exports.getMyBookings = async (req, res) => {
  try {
    const touristeId = req.user.userId;
    const inscriptions = await Inscription.find({ touriste_id: touristeId })
      .populate("activite_id")
      .populate("organisateur_id", "fullname email avatar num_tel")
      .sort({ createdAt: -1 })
      .lean(); // Use lean() for better performance and cleaner data

    const pending = [];
    const confirmed = [];
    const cancelled = [];
    const used = [];

    inscriptions.forEach((ins) => {
      // Validate and clean the inscription object
      if (ins && typeof ins === "object" && ins.statut) {
        // Use the lean object directly - no need for JSON stringify/parse
        if (ins.statut === "pending") pending.push(ins);
        else if (ins.statut === "approved") confirmed.push(ins);
        else if (ins.statut === "verified") used.push(ins);
        else cancelled.push(ins); // cancelled
      } else {
        console.warn("Invalid inscription object:", ins);
      }
    });

    console.log(
      `Bookings for user ${touristeId}: ${pending.length} pending, ${confirmed.length} confirmed, ${cancelled.length} cancelled, ${used.length} used`,
    );

    res.status(200).json({
      success: true,
      data: { pending, confirmed, cancelled, used },
    });
  } catch (error) {
    console.error("Error in getMyBookings:", error);
    res.status(500).json({
      message: "Error retrieving bookings",
      error: error.message,
    });
  }
};

// Get tourist's participated activities count (public endpoint)
exports.getTouristeParticipatedCount = async (req, res) => {
  try {
    const { touristeId } = req.params;
    
    // Count all inscriptions for this tourist (confirmed + cancelled + completed)
    const count = await Inscription.countDocuments({ touriste_id: touristeId });
    
    res.json({
      success: true,
      count: count,
    });
  } catch (error) {
    console.error('Error fetching tourist participated count:', error);
    res.status(500).json({
      success: false,
      message: 'Error fetching participated count',
    });
  }
};

// Get registrations for an organizer (all requests)
exports.getInscriptionsByOrganisateur = async (req, res) => {
  try {
    const organisateurId = req.user.userId;
    const { statut, activite_id } = req.query;

    const filter = { organisateur_id: organisateurId };
    if (statut) {
      filter.statut = statut;
    }
    if (activite_id) {
      filter.activite_id = activite_id;
    }

    const inscriptions = await Inscription.find(filter)
      .populate("touriste_id", "fullname email avatar num_tel pays_origine age")
      .populate("activite_id", "titre date_debut date_fin lieu prix")
      .sort({ createdAt: -1 });

    res.status(200).json({
      count: inscriptions.length,
      inscriptions,
    });
  } catch (error) {
    res.status(500).json({
      message: "Error retrieving registrations",
      error: error.message,
    });
  }
};

// Get pending registrations for an organizer
exports.getInscriptionsEnAttente = async (req, res) => {
  try {
    const organisateurId = req.user.userId;

    const inscriptions = await Inscription.find({
      organisateur_id: organisateurId,
      statut: "pending",
    })
      .populate("touriste_id", "fullname email avatar num_tel")
      .populate("activite_id", "titre date_debut lieu")
      .sort({ createdAt: 1 }); // Oldest first

    res.status(200).json({
      count: inscriptions.length,
      inscriptions,
    });
  } catch (error) {
    res.status(500).json({
      message: "Error retrieving pending requests",
      error: error.message,
    });
  }
};

// Approve a registration (Organizer) - DEPRECATED: Auto-approval system
exports.approuverInscription = async (req, res) => {
  res.status(403).json({
    message: "Manual approval is disabled. All bookings are automatically approved.",
  });
};

// Reject a registration (Organizer) - DISABLED: Auto-approval system
exports.refuserInscription = async (req, res) => {
  res.status(403).json({
    message: "Rejection is disabled. All bookings are automatically approved.",
  });
};

// Cancel a registration (Tourist) - FIXED: MongoDB transaction + Cancellation Policy
exports.annulerInscription = async (req, res) => {
  try {
    const touristeId = req.user.userId;
    const { inscriptionId } = req.params;
    const { reason } = req.body || {};

    console.log('[INSCRIPTION CANCEL] Request:', { touristeId, inscriptionId, reason });

    const CancellationPolicy = require('../services/cancellationPolicy');
    
    const result = await CancellationPolicy.cancelBooking(inscriptionId, touristeId, reason);
    
    console.log('[INSCRIPTION CANCEL] Success:', result);

    res.status(200).json({
      success: true,
      message: "Registration canceled successfully",
      booking: result.booking,
      refund: result.refund
    });
  } catch (error) {
    console.error('[INSCRIPTION CANCEL] Error:', {
      message: error.message,
      stack: error.stack
    });
    
    const statusCode = error.message.includes('not found') ? 404 :
                      error.message.includes('Unauthorized') ? 403 :
                      error.message.includes('already') ? 400 : 500;
    
    res.status(statusCode).json({
      success: false,
      message: error.message || "Error canceling registration",
    });
  }
};

// Get a registration by ID
exports.getInscriptionById = async (req, res) => {
  try {
    const { inscriptionId } = req.params;

    const inscription = await Inscription.findById(inscriptionId)
      .populate("touriste_id", "fullname email avatar num_tel")
      .populate("activite_id")
      .populate("organisateur_id", "fullname email avatar num_tel");

    if (!inscription) {
      return res.status(404).json({ message: "Registration not found" });
    }

    res.status(200).json({ inscription });
  } catch (error) {
    res.status(500).json({
      message: "Error retrieving registration",
      error: error.message,
    });
  }
};

// Organizer statistics (activities, bookings, revenue)
exports.getOrganizerStats = async (req, res) => {
  try {
    const organisateurId = req.user.userId;

    const [totalBookings, approvedInscriptions, activitiesCount] =
      await Promise.all([
        Inscription.countDocuments({ organisateur_id: organisateurId }),
        Inscription.find({
          organisateur_id: organisateurId,
          statut: "approved",
        }).select("prix_total"),
        Activite.countDocuments({
          organisateur_id: organisateurId,
          statut: { $ne: "archive" },
        }),
      ]);

    const totalRevenue = approvedInscriptions.reduce(
      (sum, i) => sum + (i.prix_total || 0),
      0,
    );

    res.status(200).json({
      activitiesCount,
      totalBookings,
      totalRevenue,
    });
  } catch (error) {
    res.status(500).json({
      message: "Error retrieving statistics",
      error: error.message,
    });
  }
};

// Tourist statistics (bookings, reviews)
exports.getTouristStats = async (req, res) => {
  try {
    const touristeId = req.user.userId;

    const [totalBookings, totalReviews] = await Promise.all([
      Inscription.countDocuments({ touriste_id: touristeId }),
      Avis.countDocuments({ touriste_id: touristeId }),
    ]);

    res.status(200).json({ totalBookings, totalReviews });
  } catch (error) {
    res.status(500).json({
      message: "Error retrieving statistics",
      error: error.message,
    });
  }
};

// Get participants for an activity (Admin only)
exports.getInscriptionsByActivityAdmin = async (req, res) => {
  try {
    const { activite_id } = req.query;

    if (!activite_id) {
      return res.status(400).json({
        message: "activite_id is required",
      });
    }

    const inscriptions = await Inscription.find({ activite_id })
      .populate("touriste_id", "fullname email avatar num_tel pays_origine age")
      .populate("activite_id", "titre date_debut date_fin lieu prix")
      .sort({ createdAt: -1 });

    res.status(200).json({
      count: inscriptions.length,
      inscriptions,
    });
  } catch (error) {
    res.status(500).json({
      message: "Error retrieving inscriptions",
      error: error.message,
    });
  }
};

/**
 * Validate QR code without marking as used (Organizer only)
 * PRODUCTION READY avec format de réponse standardisé
 */
exports.validateQrBooking = async (req, res) => {
  const startTime = Date.now();
  const organiserId = req.user.userId;
  const { qrData } = req.body || {};
  const ipAddress = req.ip || req.connection.remoteAddress;
  const userAgent = req.get('user-agent');

  console.log('[QR VALIDATION CONTROLLER] Request received');
  console.log('[QR VALIDATION CONTROLLER] Organiser ID:', organiserId);
  console.log('[QR VALIDATION CONTROLLER] QR Data:', qrData);
  console.log('[QR VALIDATION CONTROLLER] Request body:', req.body);

  try {
    if (!qrData) {
      console.log('[QR VALIDATION CONTROLLER] QR data is missing');
      return res.status(400).json({
        success: false,
        message: "QR data is required",
        code: 'MISSING_QR_DATA',
      });
    }

    const result = await inspectBookingForQr({
      qrData,
      organiserId,
      markUsed: false,
    });

    if (!result.ok) {
      // Log de validation échouée - seulement si la réservation existe
      if (result.booking) {
        try {
          await CheckinLog.createLog({
            bookingId: result.booking._id,
            organiserId,
            touristId: result.booking.touriste_id?._id || result.booking.touriste_id,
            activityId: result.booking.activite_id?._id || result.booking.activite_id,
            status: result.code === 'ALREADY_USED' ? 'already_verified' : 'failed',
            failureReason: result.message,
            qrData,
            ipAddress,
            userAgent,
            duration: Date.now() - startTime,
          });
        } catch (logError) {
          console.warn("Failed to create validation log:", logError.message);
        }
      }

      return res.status(result.statusCode).json({
        success: false,
        code: result.code,
        message: result.message,
        data: {
          booking: result.booking || null,
        },
      });
    }

    // Log de validation réussie
    try {
      await CheckinLog.createLog({
        bookingId: result.booking._id,
        organiserId,
        touristId: result.booking.touriste_id?._id,
        activityId: result.booking.activite_id?._id,
        status: 'success',
        qrData,
        ipAddress,
        userAgent,
        duration: Date.now() - startTime,
      });
    } catch (logError) {
      console.warn("Failed to create validation log:", logError.message);
    }

    return res.status(200).json({
      success: true,
      code: result.code,
      message: result.message,
      data: {
        booking: result.booking,
        canMarkUsed: true,
        tokenType: result.tokenType,
        activityDeadline: result.activityDeadline,
      },
    });
  } catch (error) {
    console.error("Error validating booking QR:", error);

    return res.status(500).json({
      success: false,
      message: "Error validating booking QR",
      code: 'INTERNAL_ERROR',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined,
    });
  }
};

/**
 * Verify/confirm booking via QR code scan (Organizer only)
 * PRODUCTION READY avec race condition handling
 */
exports.verifyInscription = async (req, res) => {
  const startTime = Date.now();
  const { inscriptionId } = req.params;
  const organisateurId = req.user.userId;
  const ipAddress = req.ip || req.connection.remoteAddress;
  const userAgent = req.get('user-agent');

  try {
    // Récupérer d'abord le booking pour les validations préliminaires
    const booking = await Inscription.findById(inscriptionId)
      .populate("touriste_id", "fullname email avatar num_tel")
      .populate("activite_id")
      .populate("organisateur_id", "fullname email avatar num_tel");

    if (!booking) {
      await CheckinLog.createLog({
        bookingId: inscriptionId,
        organiserId: organisateurId,
        touristId: null,
        activityId: null,
        status: 'failed',
        failureReason: 'Booking not found',
        ipAddress,
        userAgent,
        duration: Date.now() - startTime,
      });

      return res.status(404).json({
        success: false,
        message: "Registration not found",
        code: 'BOOKING_NOT_FOUND',
      });
    }

    // Vérifier l'autorisation - organisateur_id is populated, so we need to compare _id
    const bookingOrganizerId = booking.organisateur_id._id
      ? booking.organisateur_id._id.toString()
      : booking.organisateur_id.toString();

    // Convert organisateurId to string for comparison
    const organisateurIdString = organisateurId.toString();

    console.log('[VERIFIER INSCRIPTION] Authorization check:');
    console.log('- Booking organizer_id:', booking.organisateur_id);
    console.log('- Booking organizer_id._id:', booking.organisateur_id._id);
    console.log('- Booking organizer_id type:', typeof booking.organisateur_id);
    console.log('- Extracted bookingOrganizerId:', bookingOrganizerId);
    console.log('- Request organisateurId:', organisateurId);
    console.log('- Request organisateurId type:', typeof organisateurId);
    console.log('- Converted organisateurIdString:', organisateurIdString);
    console.log('- Match:', bookingOrganizerId === organisateurIdString);

    if (bookingOrganizerId !== organisateurIdString) {
      await CheckinLog.createLog({
        bookingId: inscriptionId,
        organiserId: organisateurId,
        touristId: booking.touriste_id?._id,
        activityId: booking.activite_id?._id,
        status: 'unauthorized',
        failureReason: 'Organizer not authorized',
        ipAddress,
        userAgent,
        duration: Date.now() - startTime,
      });

      return res.status(403).json({
        success: false,
        message: "Unauthorized to verify this booking",
        code: 'UNAUTHORIZED',
      });
    }

    // Vérifier le statut du booking
    if (booking.statut !== "approved") {
      await CheckinLog.createLog({
        bookingId: inscriptionId,
        organiserId: organisateurId,
        touristId: booking.touriste_id?._id,
        activityId: booking.activite_id?._id,
        status: 'not_approved',
        failureReason: `Booking not approved. Current status: ${booking.statut}`,
        ipAddress,
        userAgent,
        duration: Date.now() - startTime,
      });

      return res.status(400).json({
        success: false,
        message: `Booking must be approved first. Current status: ${booking.statut}`,
        code: 'NOT_APPROVED',
      });
    }

    // Vérifier l'expiration de l'activité
    const activityDeadline = getActivityDeadline(booking.activite_id);
    const activityStartDate = normalizeDateValue(booking.activite_id?.date_debut);
    const now = new Date();
    const activityStartDateWithGrace = activityStartDate ? new Date(activityStartDate.getTime() + 15 * 60 * 1000) : null; // +15 minutes

    // Check if activity has already started (with 15 min grace period)
    if (activityStartDateWithGrace && now >= activityStartDateWithGrace) {
      await CheckinLog.createLog({
        bookingId: inscriptionId,
        organiserId: organisateurId,
        touristId: booking.touriste_id?._id,
        activityId: booking.activite_id?._id,
        status: 'already_started',
        failureReason: 'Activity has already started',
        ipAddress,
        userAgent,
        duration: Date.now() - startTime,
      });

      return res.status(400).json({
        success: false,
        message: "This activity has already started",
        code: 'ACTIVITY_ALREADY_STARTED',
      });
    }

    if (activityDeadline && now > activityDeadline) {
      await CheckinLog.createLog({
        bookingId: inscriptionId,
        organiserId: organisateurId,
        touristId: booking.touriste_id?._id,
        activityId: booking.activite_id?._id,
        status: 'expired',
        failureReason: 'Activity has expired',
        ipAddress,
        userAgent,
        duration: Date.now() - startTime,
      });

      return res.status(400).json({
        success: false,
        message: "This activity has already passed",
        code: 'ACTIVITY_EXPIRED',
      });
    }

    // MISE À JOUR ATOMIQUE pour éviter les race conditions
    // findOneAndUpdate avec condition statut != verified
    const updatedBooking = await Inscription.findOneAndUpdate(
      {
        _id: inscriptionId,
        statut: 'approved',
        qr_used_at: { $exists: false },
      },
      {
        $set: {
          statut: 'verified',
          qr_used_at: new Date(),
        },
      },
      {
        new: true,
      }
    ).populate("touriste_id", "fullname email avatar num_tel")
     .populate("activite_id")
     .populate("organisateur_id", "fullname email avatar num_tel");

    // Si updatedBooking est null, c'est que la condition n'est plus remplie (déjà vérifié)
    if (!updatedBooking) {
      // Vérifier si déjà vérifié
      const alreadyVerified = await Inscription.findById(inscriptionId);
      
      if (alreadyVerified?.statut === 'verified' || alreadyVerified?.qr_used_at) {
        await CheckinLog.createLog({
          bookingId: inscriptionId,
          organiserId: organisateurId,
          touristId: alreadyVerified.touriste_id?._id,
          activityId: alreadyVerified.activite_id?._id,
          status: 'already_verified',
          failureReason: 'Booking already verified',
          ipAddress,
          userAgent,
          duration: Date.now() - startTime,
        });

        return res.status(400).json({
          success: false,
          message: "This booking has already been verified",
          code: 'ALREADY_VERIFIED',
        });
      }

      // Autre raison
      await CheckinLog.createLog({
        bookingId: inscriptionId,
        organiserId: organisateurId,
        touristId: alreadyVerified?.touriste_id?._id,
        activityId: alreadyVerified?.activite_id?._id,
        status: 'failed',
        failureReason: 'Race condition or status changed',
        ipAddress,
        userAgent,
        duration: Date.now() - startTime,
      });

      return res.status(400).json({
        success: false,
        message: "Could not verify booking. Status may have changed.",
        code: 'STATUS_CHANGED',
      });
    }

    // Log de succès
    await CheckinLog.createLog({
      bookingId: inscriptionId,
      organiserId: organisateurId,
      touristId: updatedBooking.touriste_id?._id,
      activityId: updatedBooking.activite_id?._id,
      status: 'success',
      ipAddress,
      userAgent,
      duration: Date.now() - startTime,
    });

    // Log activity (ancien système)
    try {
      const { createActivityLog } = require("../services/activityLogService");
      await createActivityLog({
        actorId: organisateurId,
        action: "verify_booking",
        targetType: "inscription",
        targetId: inscriptionId,
        templateKey: "verify_booking",
        metadata: {
          targetName: updatedBooking.touriste_id?.fullname || "Touriste",
          activityTitle: updatedBooking.activite_id?.titre || "Activity",
        },
      });
    } catch (logError) {
      console.warn("Activity log failed for verifyInscription:", logError.message);
    }

    // Envoyer notification push au touriste
    try {
      const notificationEventBus = require("../services/notificationEventBus");
      notificationEventBus.emitBookingCheckIn({
        touristId: updatedBooking.touriste_id?._id,
        activityTitle: updatedBooking.activite_id?.titre || "Activity",
        bookingId: inscriptionId,
        activityId: updatedBooking.activite_id?._id,
      });
    } catch (notifError) {
      console.warn("Failed to send check-in notification:", notifError.message);
      // Ne pas échouer la requête si la notification échoue
    }

    return res.status(200).json({
      success: true,
      message: "Booking verified successfully",
      code: 'VERIFIED',
      data: {
        inscription: updatedBooking,
        checkedInAt: updatedBooking.qr_used_at,
      },
    });

  } catch (error) {
    console.error("Error verifying booking:", error);

    // Log d'erreur
    try {
      await CheckinLog.createLog({
        bookingId: inscriptionId,
        organiserId: organisateurId,
        touristId: null,
        activityId: null,
        status: 'failed',
        failureReason: error.message,
        ipAddress,
        userAgent,
        duration: Date.now() - startTime,
      });
    } catch (logError) {
      console.error("Failed to create error log:", logError);
    }

    return res.status(500).json({
      success: false,
      message: "Error verifying booking",
      code: 'INTERNAL_ERROR',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined,
    });
  }
};

// POST /inscriptions/:id/dismiss-review-reminder
// Dismiss review reminder and schedule next reminder
exports.dismissReviewReminder = async (req, res) => {
  try {
    const { id } = req.params;
    const { reminderAt } = req.body;
    
    const booking = await Inscription.findById(id);
    if (!booking) {
      return res.status(404).json({ message: "Booking not found" });
    }

    // Calculate next reminder time if not provided
    let nextReminderAt;
    if (reminderAt) {
      nextReminderAt = new Date(reminderAt);
    } else {
      const currentCount = booking.reviewReminder?.reminderCount || 0;
      const now = new Date();
      
      switch (currentCount) {
        case 0:
          nextReminderAt = new Date(now.getTime() + 2 * 24 * 60 * 60 * 1000); // 2 days
          break;
        case 1:
          nextReminderAt = new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000); // 3 days
          break;
        case 2:
          nextReminderAt = new Date(now.getTime() + 2 * 24 * 60 * 60 * 1000); // 2 days
          break;
        default:
          nextReminderAt = new Date(now.getTime() + 365 * 24 * 60 * 60 * 1000); // 1 year (effectively never)
          break;
      }
    }

    await booking.setReviewReminder(nextReminderAt);

    res.status(200).json({
      message: "Review reminder dismissed successfully",
      reminder: booking.reviewReminder,
    });
  } catch (error) {
    return res.status(500).json({
      message: "Error dismissing review reminder",
      error: error.message,
    });
  }
};

// PATCH /inscriptions/:id/reviewed
// Mark booking as reviewed (Tourist only)
exports.markAsReviewed = async (req, res) => {
  try {
    const { id } = req.params;
    
    const booking = await Inscription.findById(id);
    if (!booking) {
      return res.status(404).json({ message: "Booking not found" });
    }

    // Verify the booking belongs to the authenticated tourist
    if (booking.touriste_id.toString() !== req.user.userId) {
      return res.status(403).json({ message: "You can only mark your own bookings as reviewed" });
    }

    // Mark as reviewed using the model method
    await booking.marquerCommeReviewed();

    res.status(200).json({
      message: "Booking marked as reviewed successfully",
      hasReviewed: booking.hasReviewed,
      reviewDate: booking.reviewDate,
    });
  } catch (error) {
    return res.status(500).json({
      message: "Error marking booking as reviewed",
      error: error.message,
    });
  }
};

// GET /inscriptions/:id/review-reminder
// Get review reminder data for a booking
exports.getReviewReminderData = async (req, res) => {
  try {
    const { id } = req.params;
    
    const booking = await Inscription.findById(id);
    if (!booking) {
      return res.status(404).json({ message: "Booking not found" });
    }

    // Check if reminder should be shown
    const shouldShow = await booking.shouldShowReviewReminder();

    res.status(200).json({
      shouldShow,
      reminder: booking.reviewReminder,
      hasReviewed: booking.hasReviewed,
    });
  } catch (error) {
    return res.status(500).json({
      message: "Error getting review reminder data",
      error: error.message,
    });
  }
};

// GET /inscriptions/review-reminders
// Get all bookings that should show review reminder for authenticated user
exports.getPendingReviewReminders = async (req, res) => {
  try {
    const touristeId = req.user.userId;

    // Find all approved bookings for this tourist that are checked in but not reviewed
    const bookings = await Inscription.find({
      touriste_id: touristeId,
      statut: "approved",
      qr_used_at: { $exists: true },
      hasReviewed: false,
    })
    .populate("activite_id", "titre date_fin")
    .sort({ qr_used_at: -1 });

    // Filter bookings that should show reminders (async check)
    const eligibleBookings = [];
    for (const booking of bookings) {
      const shouldShow = await booking.shouldShowReviewReminder();
      if (shouldShow) {
        eligibleBookings.push(booking);
      }
    }

    res.status(200).json({
      bookings: eligibleBookings,
      count: eligibleBookings.length,
    });
  } catch (error) {
    res.status(500).json({
      message: "Error getting pending review reminders",
      error: error.message,
    });
  }
};

// GET /activite/:activiteId/participants
// Get activity participants (public access - any authenticated user can see)
exports.getActivityParticipants = async (req, res) => {
  try {
    const { activiteId } = req.params;
    
    if (!activiteId) {
      return res.status(400).json({ message: "Activity ID is required" });
    }

    console.log(`🔍 [PARTICIPANTS] Getting participants for activity: ${activiteId}`);
    console.log(`🔍 [PARTICIPANTS] Requested by user: ${req.user.userId} (${req.user.userType})`);
    
    // First, check if activity exists
    console.log(`🔍 [PARTICIPANTS] Checking if activity exists...`);
    const activity = await Activite.findById(activiteId);
    if (!activity) {
      console.log(`❌ [PARTICIPANTS] Activity not found: ${activiteId}`);
      return res.status(404).json({ message: "Activity not found" });
    }
    console.log(`✅ [PARTICIPANTS] Activity found: ${activity.titre}`);
    
    // Check all inscriptions for this activity (any status)
    console.log(`🔍 [PARTICIPANTS] Checking all inscriptions for activity...`);
    const allInscriptions = await Inscription.find({ activite_id: activiteId });
    console.log(`🔍 [PARTICIPANTS] Total inscriptions found: ${allInscriptions.length}`);
    
    // Check approved and verified inscriptions (both are valid participants)
    console.log(`🔍 [PARTICIPANTS] Checking approved and verified inscriptions...`);
    const inscriptions = await Inscription.find({
      activite_id: activiteId,
      statut: { $in: ['approved', 'verified'] }
    })
    .populate({
      path: 'touriste_id',
      select: 'fullname avatar _id profileVisibility',
      strictPopulate: false
    })
    .populate({
      path: 'activite_id',
      select: 'titre',
      strictPopulate: false
    });
    console.log(`🔍 [PARTICIPANTS] Approved and verified inscriptions found: ${inscriptions.length}`);
    
    // Log status breakdown
    const statusCounts = await Inscription.aggregate([
      { $match: { activite_id: new mongoose.Types.ObjectId(activiteId) } },
      { $group: { _id: '$statut', count: { $sum: 1 } } }
    ]);
    console.log(`🔍 [PARTICIPANTS] Status breakdown:`, statusCounts);

    if (!inscriptions || inscriptions.length === 0) {
      console.log(`🔍 [PARTICIPANTS] No participants found for activity: ${activiteId}`);
      return res.json({
        success: true,
        participants: [],
        message: "No participants found"
      });
    }

    console.log(`🔍 [PARTICIPANTS] Found ${inscriptions.length} participants for activity: ${activiteId}`);

    // Format participant data with privacy info
    const participants = inscriptions.map(inscription => {
      const participant = inscription.toObject();
      const touriste = participant.touriste_id || {};  // Fixed: use touriste_id
      const activite = participant.activite_id || {};  // Fixed: use activite_id
      
      // Convert ObjectId to string for frontend compatibility
      const touristeId = touriste._id ? touriste._id.toString() : '';
      const activiteId = activite._id ? activite._id.toString() : '';
      
      console.log(`🔍 [PARTICIPANT DEBUG] touriste_id:`, JSON.stringify(touriste));
      console.log(`🔍 [PARTICIPANT DEBUG] touriste._id:`, touriste._id);
      console.log(`🔍 [PARTICIPANT DEBUG] touristeId (string):`, touristeId);
      
      return {
        _id: participant._id.toString(),
        nombreParticipants: participant.nombre_participants,
        statut: participant.statut,
        dateDemande: participant.date_demande,
        prixTotal: participant.prix_total,
        touriste: {
          _id: touristeId,
          fullname: touriste.fullname || 'Unknown',
          avatar: touriste.avatar || '',
          profileVisibility: touriste.profileVisibility !== undefined ? touriste.profileVisibility : true
        },
        activite: {
          _id: activiteId,
          titre: activite.titre || 'Unknown Activity'
        },
        // Add helper methods for frontend
        isCurrentUser: touristeId === req.user.userId,
        canDisplay: (touriste.profileVisibility !== undefined ? touriste.profileVisibility : true) || touristeId === req.user.userId
      };
    });

    console.log(`🔍 [PARTICIPANTS] Formatted ${participants.length} participants with privacy data`);
    console.log(`🔍 [PARTICIPANTS] Response data:`, JSON.stringify({
      success: true,
      participants: participants,
      message: `Found ${participants.length} participants`
    }, null, 2));

    res.json({
      success: true,
      participants: participants,
      message: `Found ${participants.length} participants`
    });

  } catch (error) {
    console.error('❌ [PARTICIPANTS] Error getting activity participants:', error);
    res.status(500).json({
      success: false,
      message: "Error loading participants",
      error: error.message
    });
  }
};

// Approve a reservation request (Organizer only)
exports.approveReservation = async (req, res) => {
  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const { inscriptionId } = req.params;
    const { message_organisateur } = req.body;
    const organizerId = req.user.userId;

    console.log('[APPROVE RESERVATION] Approving reservation:', { inscriptionId, organizerId });

    // Find the inscription
    const inscription = await Inscription.findById(inscriptionId)
      .populate('activite_id')
      .populate('touriste_id')
      .session(session);

    if (!inscription) {
      await session.abortTransaction();
      return res.status(404).json({ message: "Reservation not found" });
    }

    // Verify organizer owns this activity
    if (inscription.organisateur_id.toString() !== organizerId.toString()) {
      await session.abortTransaction();
      return res.status(403).json({ message: "You can only approve reservations for your activities" });
    }

    // Check if reservation is pending
    if (inscription.statut !== "pending") {
      await session.abortTransaction();
      return res.status(400).json({ 
        message: `Cannot approve reservation with status: ${inscription.statut}` 
      });
    }

    // Check activity capacity
    const activite = inscription.activite_id;
    const available = activite.capacite_max - activite.nombre_reservations;
    
    if (available < inscription.nombre_participants) {
      await session.abortTransaction();
      return res.status(400).json({
        message: `Cannot approve: only ${Math.max(available, 0)} place${available > 1 ? "s" : ""} left`,
        available: Math.max(available, 0),
        requested: inscription.nombre_participants
      });
    }

    // Update activity capacity
    await Activite.findByIdAndUpdate(
      activite._id,
      { $inc: { nombre_reservations: inscription.nombre_participants } },
      { session }
    );

    // Approve the reservation
    await inscription.approve(message_organisateur);

    // Generate QR token
    const qrToken = createBookingQrToken(inscription, activite);
    const activityDeadline = getActivityDeadline(activite);
    
    inscription.qr_token = qrToken;
    inscription.qr_token_generated_at = new Date();
    inscription.qr_token_expires_at = activityDeadline;
    
    await inscription.save({ session });

    await session.commitTransaction();

    // Send email with QR code
    try {
      const touristEmail = inscription.touriste_id?.email;
      const touristName = inscription.touriste_id?.fullname || "Traveler";
      const activityTitle = activite.titre;
      const bookingDate = activite.date_debut
        ? new Date(activite.date_debut).toLocaleDateString("en-GB")
        : new Date().toLocaleDateString("en-GB");
      const bookingTime = activite.date_debut
        ? new Date(activite.date_debut).toLocaleTimeString([], {
            hour: "2-digit",
            minute: "2-digit",
          })
        : "--:--";

      let qrPublicUrl = null;
      try {
        const cloudinary = require("../config/cloudinary");
        const qrBuffer = await QRCode.toBuffer(qrToken, {
          errorCorrectionLevel: "M",
          margin: 1,
          width: 280,
        });
        
        const uploadResult = await new Promise((resolve, reject) => {
          cloudinary.uploader.upload_stream(
            {
              folder: "djtrip/booking-qr",
              public_id: `booking-qr-${inscription._id}`,
              resource_type: "image",
              format: "png",
            },
            (error, result) => {
              if (error) reject(error);
              else resolve(result);
            }
          ).end(qrBuffer);
        });
        
        qrPublicUrl = uploadResult.secure_url;
        console.log('QR code uploaded to Cloudinary:', qrPublicUrl);
      } catch (qrError) {
        console.error("Error generating or uploading booking QR code:", qrError);
      }

      await emailService.sendBookingConfirmationEmail({
        email: touristEmail,
        fullname: touristName,
        bookingCode: qrToken,
        activityTitle,
        bookingDate,
        bookingTime,
        participants: inscription.nombre_participants,
        totalPrice: `${inscription.prix_total.toFixed(2)} TND`,
        qrPublicUrl,
      });
    } catch (emailError) {
      console.error("Error sending booking confirmation email:", emailError);
    }

    // Emit notification
    try {
      notificationEventBus.emitBookingApproved({
        touristId: inscription.touriste_id._id,
        activityTitle: activite.titre,
        bookingId: inscription._id.toString(),
      });
    } catch (notifError) {
      console.warn('Failed to emit booking approved event:', notifError.message);
    }

    res.json({
      message: "Reservation approved successfully",
      inscription: await Inscription.findById(inscriptionId)
        .populate('activite_id', 'titre date_debut date_fin lieu prix')
        .populate('touriste_id', 'fullname email avatar')
    });

  } catch (error) {
    await session.abortTransaction();
    console.error('[APPROVE RESERVATION] Error:', error);
    res.status(500).json({
      message: "Error approving reservation",
      error: error.message
    });
  } finally {
    session.endSession();
  }
};

// Reject a reservation request (Organizer only)
exports.rejectReservation = async (req, res) => {
  try {
    const { inscriptionId } = req.params;
    const { message_organisateur } = req.body;
    const organizerId = req.user.userId;

    console.log('[REJECT RESERVATION] Rejecting reservation:', { inscriptionId, organizerId });

    // Find the inscription
    const inscription = await Inscription.findById(inscriptionId)
      .populate('activite_id')
      .populate('touriste_id');

    if (!inscription) {
      return res.status(404).json({ message: "Reservation not found" });
    }

    // Verify organizer owns this activity
    if (inscription.organisateur_id.toString() !== organizerId.toString()) {
      return res.status(403).json({ message: "You can only reject reservations for your activities" });
    }

    // Check if reservation is pending
    if (inscription.statut !== "pending") {
      return res.status(400).json({ 
        message: `Cannot reject reservation with status: ${inscription.statut}` 
      });
    }

    // Reject the reservation
    await inscription.reject(message_organisateur);

    // Send rejection email
    try {
      const touristEmail = inscription.touriste_id?.email;
      const touristName = inscription.touriste_id?.fullname || "Traveler";
      const activityTitle = inscription.activite_id.titre;

      await emailService.sendBookingRejectionEmail({
        email: touristEmail,
        fullname: touristName,
        activityTitle,
        rejectionReason: message_organisateur || "No reason provided",
      });
    } catch (emailError) {
      console.error("Error sending rejection email:", emailError);
    }

    // Emit notification
    try {
      notificationEventBus.emitBookingRejected({
        touristId: inscription.touriste_id._id,
        activityTitle: inscription.activite_id.titre,
        bookingId: inscription._id.toString(),
      });
    } catch (notifError) {
      console.warn('Failed to emit booking rejected event:', notifError.message);
    }

    res.json({
      message: "Reservation rejected successfully",
      inscription: await Inscription.findById(inscriptionId)
        .populate('activite_id', 'titre date_debut date_fin lieu prix')
        .populate('touriste_id', 'fullname email avatar')
    });

  } catch (error) {
    console.error('[REJECT RESERVATION] Error:', error);
    res.status(500).json({
      message: "Error rejecting reservation",
      error: error.message
    });
  }
};
