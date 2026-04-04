const Inscription = require("../models/inscription");
const Activite = require("../models/activite");
const Touriste = require("../models/touriste");

// Auto-expire pending requests for activities already ended.
// Business rule: if organizer did not respond before activity end date,
// request is automatically cancelled for the tourist.
async function expirePendingInscriptionsForEndedActivities() {
  const now = new Date();
  const endedActivityIds = await Activite.find({
    date_fin: { $lt: now },
  }).distinct("_id");

  if (!endedActivityIds.length) return 0;

  const result = await Inscription.updateMany(
    {
      activite_id: { $in: endedActivityIds },
      statut: "en_attente",
    },
    {
      $set: {
        statut: "annulee",
        date_reponse: now,
        message_organisateur:
          "Automatically cancelled because the activity has ended without organizer response.",
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
    const nombreParticipants = nombre_participants || 1;

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
    const prixTotal = activite.prix * (nombre_participants || 1);

    // Create the registration
    const inscription = new Inscription({
      touriste_id: touristeId,
      activite_id: activite_id,
      organisateur_id: activite.organisateur_id,
      nombre_participants: nombre_participants || 1,
      message_touriste,
      prix_total: prixTotal,
    });

    await inscription.save();

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

// Get my activities for Tourist (only approved, bucketed by date)
exports.getMyActivities = async (req, res) => {
  try {
    await expirePendingInscriptionsForEndedActivities();

    const touristeId = req.user.userId;
    // Only approved activities
    const inscriptions = await Inscription.find({
      touriste_id: touristeId,
      statut: "approuvee",
    })
      .populate("activite_id")
      .populate("organisateur_id", "fullname email avatar num_tel")
      .sort({ createdAt: -1 });

    const now = new Date();
    const upcoming = [];
    const ongoing = [];
    const past = [];

    inscriptions.forEach((ins) => {
      const act = ins.activite_id;
      if (!act) {
        upcoming.push(ins);
        return;
      }
      
      const start = act.date_debut || act.dateDebut;
      const end = act.date_fin || act.dateFin;
      let dStart = start ? new Date(start) : null;
      let dEnd = end ? new Date(end) : null;

      if (!dStart && !dEnd) {
        upcoming.push(ins);
      } else if (dStart && now < dStart) {
        upcoming.push(ins);
      } else if (dStart && dEnd && now >= dStart && now < dEnd) {
        ongoing.push(ins);
      } else if (dEnd && now >= dEnd) {
        past.push(ins);
      } else {
        // fallback (e.g. only start exists, and we're past it)
        past.push(ins);
      }
    });

    res.status(200).json({
      success: true,
      data: { upcoming, ongoing, past },
    });
  } catch (error) {
    res.status(500).json({
      message: "Error retrieving activities",
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
      .sort({ createdAt: -1 });

    const pending = [];
    const confirmed = [];
    const cancelled = [];

    inscriptions.forEach((ins) => {
      if (ins.statut === "en_attente") pending.push(ins);
      else if (ins.statut === "approuvee") confirmed.push(ins);
      else cancelled.push(ins); // annulee, refusee
    });

    res.status(200).json({
      success: true,
      data: { pending, confirmed, cancelled },
    });
  } catch (error) {
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

    await inscription.approuver(message_organisateur);

    // Increment the number of reserved spots (number of participants)
    await Activite.findByIdAndUpdate(inscription.activite_id, {
      $inc: { nombre_reservations: inscription.nombre_participants },
    });

    const inscriptionPopulated = await Inscription.findById(inscriptionId)
      .populate("touriste_id", "fullname email")
      .populate("activite_id", "titre date_debut");

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
