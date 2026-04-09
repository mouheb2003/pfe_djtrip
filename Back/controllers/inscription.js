const Inscription = require("../models/inscription");
const Activite = require("../models/activite");
const Touriste = require("../models/touriste");
const QRCode = require("qrcode");
const jwt = require("jsonwebtoken");
const emailService = require("../services/email");
const { createActivityLog } = require("../services/activityLogService");

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
  if (!QR_BOOKING_SECRET) {
    return {
      ok: false,
      statusCode: 500,
      code: "QR_SECRET_MISSING",
      message: "QR booking secret is not configured",
    };
  }

  const parsed = parseQrPayload(qrData);
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

  if (inscription.organisateur_id.toString() !== organiserId) {
    return {
      ok: false,
      statusCode: 403,
      code: "UNAUTHORIZED",
      message: "Unauthorized to verify this booking",
    };
  }

  const activityDeadline = getActivityDeadline(inscription.activite_id);
  const now = new Date();
  if (activityDeadline && now > activityDeadline) {
    return {
      ok: false,
      statusCode: 400,
      code: "ACTIVITY_EXPIRED",
      message: "This activity has already passed",
      booking: inscription,
    };
  }

  if (inscription.statut === "verifie" || inscription.qr_used_at) {
    return {
      ok: false,
      statusCode: 400,
      code: "ALREADY_USED",
      message: "This booking has already been used",
      booking: inscription,
    };
  }

  if (inscription.statut !== "approuvee") {
    return {
      ok: false,
      statusCode: 400,
      code: "NOT_CONFIRMED",
      message: `Booking must be confirmed first. Current status: ${inscription.statut}`,
      booking: inscription,
    };
  }

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
}

// Auto-expire pending requests for activities whose start date has passed.
// Business rule: if organizer did not respond before activity start date,
// request is automatically cancelled for the tourist.
async function expirePendingInscriptionsForEndedActivities() {
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
}

// Create a new registration (Tourist registers for an activity)
exports.createInscription = async (req, res) => {
  try {
    const touristeId = req.user.userId; // Logged-in tourist ID
    const { activite_id, nombre_participants, message_touriste } = req.body;
    const nombreParticipants = Number.parseInt(nombre_participants, 10);

    if (!Number.isInteger(nombreParticipants) || nombreParticipants < 1) {
      return res.status(400).json({
        message: "Participants count must be a positive integer",
      });
    }

    // Verify the user is a tourist
    const touriste = await Touriste.findById(touristeId);
    if (!touriste) {
      return res.status(403).json({
        message: "Only tourists can register for activities",
      });
    }

    // Verify the activity exists and is active
    const activite = await Activite.findById(activite_id);
    if (!activite) {
      return res.status(404).json({ message: "Activity not found" });
    }

    if (activite.statut !== "active") {
      return res.status(400).json({
        message: "This activity is no longer available",
      });
    }
    if (new Date(activite.date_fin) <= new Date()) {
      return res.status(400).json({
        message: "This activity has already ended",
      });
    }

    // Check if spots are still available
    const placesDisponibles =
      activite.capacite_max - activite.nombre_reservations;

    if (placesDisponibles <= 0) {
      return res.status(400).json({
        message: "Sorry, this activity is fully booked",
      });
    }

    if (nombreParticipants > placesDisponibles) {
      return res.status(400).json({
        message: `Sorry, only ${placesDisponibles} place${placesDisponibles > 1 ? "s" : ""} left available`,
      });
    }

    // Check if the tourist is already registered for this activity
    const inscriptionExistante = await Inscription.findOne({
      touriste_id: touristeId,
      activite_id: activite_id,
      statut: { $in: ["en_attente", "approuvee"] },
    });

    if (inscriptionExistante) {
      return res.status(400).json({
        message: "You are already registered for this activity",
      });
    }

    // Calculate total price
    const prixTotal = activite.prix * nombreParticipants;

    // Create the registration
    const inscription = new Inscription({
      touriste_id: touristeId,
      activite_id: activite_id,
      organisateur_id: activite.organisateur_id,
      nombre_participants: nombreParticipants,
      message_touriste,
      prix_total: prixTotal,
    });

    await inscription.save();

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

    // Note: nombre_reservations will be incremented upon approval, not now

    // Populate information for the response
    const inscriptionPopulated = await Inscription.findById(inscription._id)
      .populate("activite_id", "titre date_debut date_fin lieu prix")
      .populate("touriste_id", "fullname email avatar");

    res.status(201).json({
      message: "Registration created successfully. Pending approval.",
      inscription: inscriptionPopulated,
    });
  } catch (error) {
    res.status(500).json({
      message: "Error creating registration",
      error: error.message,
    });
  }
};

// Get registrations for a tourist
exports.getInscriptionsByTouriste = async (req, res) => {
  try {
    await expirePendingInscriptionsForEndedActivities();

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
    await expirePendingInscriptionsForEndedActivities();

    const touristeId = req.user.userId;
    const inscriptions = await Inscription.find({ touriste_id: touristeId })
      .populate("activite_id")
      .populate("organisateur_id", "fullname email avatar num_tel")
      .sort({ createdAt: -1 })
      .lean(); // Use lean() for better performance and cleaner data

    const pending = [];
    const confirmed = [];
    const cancelled = [];

    inscriptions.forEach((ins) => {
      // Validate and clean the inscription object
      if (ins && typeof ins === "object" && ins.statut) {
        // Use the lean object directly - no need for JSON stringify/parse
        if (ins.statut === "en_attente") pending.push(ins);
        else if (ins.statut === "approuvee") confirmed.push(ins);
        else cancelled.push(ins); // annulee, refusee
      } else {
        console.warn("Invalid inscription object:", ins);
      }
    });

    console.log(
      `Bookings for user ${touristeId}: ${pending.length} pending, ${confirmed.length} confirmed, ${cancelled.length} cancelled`,
    );

    res.status(200).json({
      success: true,
      data: { pending, confirmed, cancelled },
    });
  } catch (error) {
    console.error("Error in getMyBookings:", error);
    res.status(500).json({
      message: "Error retrieving bookings",
      error: error.message,
    });
  }
};

// Get registrations for an organizer (all requests)
exports.getInscriptionsByOrganisateur = async (req, res) => {
  try {
    await expirePendingInscriptionsForEndedActivities();

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
    await expirePendingInscriptionsForEndedActivities();

    const organisateurId = req.user.userId;

    const inscriptions = await Inscription.find({
      organisateur_id: organisateurId,
      statut: "en_attente",
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

// Approve a registration (Organizer)
exports.approuverInscription = async (req, res) => {
  try {
    await expirePendingInscriptionsForEndedActivities();

    const organisateurId = req.user.userId;
    const { inscriptionId } = req.params;
    const { message_organisateur } = req.body;

    const inscription = await Inscription.findById(inscriptionId);
    if (!inscription) {
      return res.status(404).json({ message: "Registration not found" });
    }

    // Verify the organizer is the owner
    if (inscription.organisateur_id.toString() !== organisateurId) {
      return res.status(403).json({
        message: "You are not authorized to approve this registration",
      });
    }

    if (inscription.statut !== "en_attente") {
      return res.status(400).json({
        message: "This registration has already been processed",
      });
    }

    const activite = await Activite.findById(inscription.activite_id);
    if (!activite) {
      return res.status(404).json({ message: "Activity not found" });
    }
    if (new Date(activite.date_fin) <= new Date()) {
      return res.status(400).json({
        message: "Cannot approve: activity has already ended",
      });
    }

    const placesDisponibles =
      activite.capacite_max - activite.nombre_reservations;
    if (inscription.nombre_participants > placesDisponibles) {
      return res.status(400).json({
        message: `Cannot approve: only ${Math.max(placesDisponibles, 0)} place${placesDisponibles > 1 ? "s" : ""} left`,
      });
    }

    await inscription.approuver(message_organisateur);

    const qrToken = createBookingQrToken(inscription, activite);
    const activityDeadline = getActivityDeadline(activite);
    inscription.qr_token = qrToken;
    inscription.qr_token_generated_at = new Date();
    inscription.qr_token_expires_at = activityDeadline;
    await inscription.save();

    // Increment the number of reserved spots (number of participants)
    await Activite.findByIdAndUpdate(inscription.activite_id, {
      $inc: { nombre_reservations: inscription.nombre_participants },
    });

    const inscriptionPopulated = await Inscription.findById(inscriptionId)
      .populate("touriste_id", "fullname email")
      .populate("activite_id", "titre date_debut");

    try {
      await createActivityLog({
        actorId: organisateurId,
        action: "approve_request",
        targetType: "booking",
        targetId: inscription._id,
        templateKey: "approve_request",
        metadata: {
          title: inscriptionPopulated?.activite_id?.titre || "Demande",
        },
      });
    } catch (logError) {
      console.warn(
        "Activity log failed for approuverInscription:",
        logError.message,
      );
    }

    const touristEmail = inscriptionPopulated?.touriste_id?.email;
    const touristName =
      inscriptionPopulated?.touriste_id?.fullname || "Traveler";
    const activityTitle =
      inscriptionPopulated?.activite_id?.titre || "Activity";
    const bookingCode =
      inscription.qr_token || `DJTRIP_BOOKING:${inscriptionId}`;

    if (touristEmail) {
      const bookingDate = inscriptionPopulated?.activite_id?.date_debut
        ? new Date(
            inscriptionPopulated.activite_id.date_debut,
          ).toLocaleDateString("en-GB")
        : new Date().toLocaleDateString("en-GB");
      const bookingTime = inscriptionPopulated?.activite_id?.date_debut
        ? new Date(
            inscriptionPopulated.activite_id.date_debut,
          ).toLocaleTimeString([], {
            hour: "2-digit",
            minute: "2-digit",
          })
        : "--:--";

      let qrDataUrl = null;
      try {
        qrDataUrl = await QRCode.toDataURL(bookingCode, {
          errorCorrectionLevel: "M",
          margin: 1,
          width: 280,
        });
      } catch (qrError) {
        console.error("Error generating booking QR code:", qrError);
      }

      try {
        await emailService.sendBookingConfirmationEmail({
          email: touristEmail,
          fullname: touristName,
          bookingCode,
          activityTitle,
          bookingDate,
          bookingTime,
          participants: inscription.nombre_participants,
          totalPrice: `${inscription.prix_total.toFixed(2)} TND`,
          qrDataUrl,
        });
      } catch (emailError) {
        console.error("Error sending booking confirmation email:", emailError);
      }
    }

    res.status(200).json({
      message: "Registration approved successfully",
      inscription: inscriptionPopulated,
    });
  } catch (error) {
    res.status(500).json({
      message: "Error approving registration",
      error: error.message,
    });
  }
};

// Reject a registration (Organizer)
exports.refuserInscription = async (req, res) => {
  try {
    await expirePendingInscriptionsForEndedActivities();

    const organisateurId = req.user.userId;
    const { inscriptionId } = req.params;
    const { message_organisateur } = req.body;

    const inscription = await Inscription.findById(inscriptionId);
    if (!inscription) {
      return res.status(404).json({ message: "Registration not found" });
    }

    // Verify the organizer is the owner
    if (inscription.organisateur_id.toString() !== organisateurId) {
      return res.status(403).json({
        message: "You are not authorized to reject this registration",
      });
    }

    if (inscription.statut !== "en_attente") {
      return res.status(400).json({
        message: "This registration has already been processed",
      });
    }

    await inscription.refuser(message_organisateur);

    // Note: no need to decrement nombre_reservations as it was not yet incremented
    // (only approved registrations are counted)

    const inscriptionPopulated = await Inscription.findById(inscriptionId)
      .populate("touriste_id", "fullname email")
      .populate("activite_id", "titre date_debut");

    res.status(200).json({
      message: "Registration rejected",
      inscription: inscriptionPopulated,
    });
  } catch (error) {
    res.status(500).json({
      message: "Error rejecting registration",
      error: error.message,
    });
  }
};

// Cancel a registration (Tourist)
exports.annulerInscription = async (req, res) => {
  try {
    const touristeId = req.user.userId;
    const { inscriptionId } = req.params;

    const inscription = await Inscription.findById(inscriptionId);
    if (!inscription) {
      return res.status(404).json({ message: "Registration not found" });
    }

    // Verify the tourist is the owner
    if (inscription.touriste_id.toString() !== touristeId) {
      return res.status(403).json({
        message: "You are not authorized to cancel this registration",
      });
    }

    if (inscription.statut === "annulee") {
      return res.status(400).json({
        message: "This registration is already canceled",
      });
    }

    // Decrement the number of reserved spots if registration was approved
    // (must be done BEFORE cancelling to check the status)
    const wasApproved = inscription.statut === "approuvee";
    const nombreParticipants = inscription.nombre_participants;

    await inscription.annuler();

    if (wasApproved) {
      await Activite.findByIdAndUpdate(inscription.activite_id, {
        $inc: { nombre_reservations: -nombreParticipants },
      });
    }

    res.status(200).json({
      message: "Registration canceled successfully",
    });
  } catch (error) {
    res.status(500).json({
      message: "Error canceling registration",
      error: error.message,
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
          statut: "approuvee",
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

    const [totalBookings] = await Promise.all([
      Inscription.countDocuments({ touriste_id: touristeId }),
    ]);

    res.status(200).json({ totalBookings });
  } catch (error) {
    res.status(500).json({
      message: "Error retrieving statistics",
      error: error.message,
    });
  }
};

// Verify/confirm booking via QR code scan (Organizer only)
exports.validateQrBooking = async (req, res) => {
  try {
    const organiserId = req.user.userId;
    const { qrData } = req.body || {};

    const result = await inspectBookingForQr({
      qrData,
      organiserId,
      markUsed: false,
    });

    if (!result.ok) {
      return res.status(result.statusCode).json({
        success: false,
        code: result.code,
        message: result.message,
        booking: result.booking || null,
      });
    }

    return res.status(200).json({
      success: true,
      code: result.code,
      message: result.message,
      booking: result.booking,
      canMarkUsed: true,
      tokenType: result.tokenType,
      activityDeadline: result.activityDeadline,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Error validating booking QR",
      error: error.message,
    });
  }
};

exports.verifyInscription = async (req, res) => {
  try {
    const { inscriptionId } = req.params;
    const organisateurId = req.user.userId;

    const booking = await Inscription.findById(inscriptionId)
      .populate("touriste_id", "fullname email avatar num_tel")
      .populate("activite_id")
      .populate("organisateur_id", "fullname email avatar num_tel");

    if (!booking) {
      return res.status(404).json({ message: "Registration not found" });
    }

    if (booking.organisateur_id.toString() !== organisateurId) {
      return res.status(403).json({
        message: "Unauthorized to verify this booking",
      });
    }

    if (booking.statut === "verifie" || booking.qr_used_at) {
      return res.status(400).json({
        message: "This booking has already been verified",
      });
    }

    if (booking.statut !== "approuvee") {
      return res.status(400).json({
        message: `Booking must be approved. Current status: ${booking.statut}`,
      });
    }

    const activityDeadline = getActivityDeadline(booking.activite_id);
    if (activityDeadline && new Date() > activityDeadline) {
      return res.status(400).json({
        message: "This activity has already passed",
      });
    }

    await booking.marquerCommeUtilise();

    // Log activity
    try {
      const { createActivityLog } = require("../services/activityLogService");
      await createActivityLog({
        actorId: organisateurId,
        action: "verify_booking",
        targetType: "inscription",
        targetId: inscriptionId,
        templateKey: "verify_booking",
        metadata: {
          targetName: booking.touriste_id?.fullname || "Touriste",
          activityTitle: booking.activite_id?.titre || "Activity",
        },
      });
    } catch (logError) {
      console.warn(
        "Activity log failed for verifyInscription:",
        logError.message,
      );
    }

    res.status(200).json({
      message: "Booking verified successfully",
      inscription: booking,
    });
  } catch (error) {
    res.status(500).json({
      message: "Error verifying booking",
      error: error.message,
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
    res.status(500).json({
      message: "Error dismissing review reminder",
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
    const shouldShow = booking.shouldShowReviewReminder();

    res.status(200).json({
      shouldShow,
      reminder: booking.reviewReminder,
      hasReviewed: booking.hasReviewed,
    });
  } catch (error) {
    res.status(500).json({
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
      statut: "approuvee",
      qr_used_at: { $exists: true },
      hasReviewed: false,
    })
    .populate("activite_id", "titre date_fin")
    .sort({ qr_used_at: -1 });

    // Filter bookings that should show reminders
    const eligibleBookings = bookings.filter(booking => 
      booking.shouldShowReviewReminder()
    );

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
