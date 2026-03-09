const Inscription = require("../models/inscription");
const Activite = require("../models/activite");
const Touriste = require("../models/touriste");

// Créer une nouvelle inscription (Touriste s'inscrit à une activité)
exports.createInscription = async (req, res) => {
  try {
    const touristeId = req.user.userId; // ID du touriste connecté
    const { activite_id, nombre_participants, message_touriste } = req.body;

    // Vérifier que l'utilisateur est un touriste
    const touriste = await Touriste.findById(touristeId);
    if (!touriste) {
      return res.status(403).json({
        message: "Seuls les touristes peuvent s'inscrire aux activités",
      });
    }

    // Vérifier que l'activité existe et est active
    const activite = await Activite.findById(activite_id);
    if (!activite) {
      return res.status(404).json({ message: "Activité non trouvée" });
    }

    if (activite.statut !== "active") {
      return res.status(400).json({
        message: "Cette activité n'est plus disponible",
      });
    }

    // Vérifier s'il reste des places disponibles
    const placesDisponibles =
      activite.capacite_max - activite.nombre_reservations;
    const nombreParticipants = nombre_participants || 1;

    if (placesDisponibles <= 0) {
      return res.status(400).json({
        message: "Désolé, cette activité est complète",
      });
    }

    if (nombreParticipants > placesDisponibles) {
      return res.status(400).json({
        message: `Désolé, il ne reste que ${placesDisponibles} place${placesDisponibles > 1 ? "s" : ""} disponible${placesDisponibles > 1 ? "s" : ""}`,
      });
    }

    // Vérifier si le touriste est déjà inscrit à cette activité
    const inscriptionExistante = await Inscription.findOne({
      touriste_id: touristeId,
      activite_id: activite_id,
      statut: { $in: ["en_attente", "approuvee"] },
    });

    if (inscriptionExistante) {
      return res.status(400).json({
        message: "Vous êtes déjà inscrit à cette activité",
      });
    }

    // Calculer le prix total
    const prixTotal = activite.prix * (nombre_participants || 1);

    // Créer l'inscription
    const inscription = new Inscription({
      touriste_id: touristeId,
      activite_id: activite_id,
      organisateur_id: activite.organisateur_id,
      nombre_participants: nombre_participants || 1,
      message_touriste,
      prix_total: prixTotal,
    });

    await inscription.save();

    // Note: nombre_reservations sera incrémenté lors de l'approbation, pas maintenant

    // Populate les informations pour la réponse
    const inscriptionPopulated = await Inscription.findById(inscription._id)
      .populate("activite_id", "titre date_debut date_fin lieu prix")
      .populate("touriste_id", "fullname email avatar");

    res.status(201).json({
      message: "Inscription créée avec succès. En attente d'approbation.",
      inscription: inscriptionPopulated,
    });
  } catch (error) {
    res.status(500).json({
      message: "Erreur lors de la création de l'inscription",
      error: error.message,
    });
  }
};

// Obtenir les inscriptions d'un touriste
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
      message: "Erreur lors de la récupération des inscriptions",
      error: error.message,
    });
  }
};

// Obtenir les inscriptions pour un organisateur (toutes les demandes)
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
      message: "Erreur lors de la récupération des inscriptions",
      error: error.message,
    });
  }
};

// Obtenir les inscriptions en attente pour un organisateur
exports.getInscriptionsEnAttente = async (req, res) => {
  try {
    const organisateurId = req.user.userId;

    const inscriptions = await Inscription.find({
      organisateur_id: organisateurId,
      statut: "en_attente",
    })
      .populate("touriste_id", "fullname email avatar num_tel")
      .populate("activite_id", "titre date_debut lieu")
      .sort({ createdAt: 1 }); // Plus anciennes en premier

    res.status(200).json({
      count: inscriptions.length,
      inscriptions,
    });
  } catch (error) {
    res.status(500).json({
      message: "Erreur lors de la récupération des demandes en attente",
      error: error.message,
    });
  }
};

// Approuver une inscription (Organisateur)
exports.approuverInscription = async (req, res) => {
  try {
    const organisateurId = req.user.userId;
    const { inscriptionId } = req.params;
    const { message_organisateur } = req.body;

    const inscription = await Inscription.findById(inscriptionId);
    if (!inscription) {
      return res.status(404).json({ message: "Inscription non trouvée" });
    }

    // Vérifier que l'organisateur est bien le propriétaire
    if (inscription.organisateur_id.toString() !== organisateurId) {
      return res.status(403).json({
        message: "Vous n'êtes pas autorisé à approuver cette inscription",
      });
    }

    if (inscription.statut !== "en_attente") {
      return res.status(400).json({
        message: "Cette inscription a déjà été traitée",
      });
    }

    await inscription.approuver(message_organisateur);

    // Incrémenter le nombre de places réservées (nombre de participants)
    await Activite.findByIdAndUpdate(inscription.activite_id, {
      $inc: { nombre_reservations: inscription.nombre_participants },
    });

    const inscriptionPopulated = await Inscription.findById(inscriptionId)
      .populate("touriste_id", "fullname email")
      .populate("activite_id", "titre date_debut");

    res.status(200).json({
      message: "Inscription approuvée avec succès",
      inscription: inscriptionPopulated,
    });
  } catch (error) {
    res.status(500).json({
      message: "Erreur lors de l'approbation de l'inscription",
      error: error.message,
    });
  }
};

// Refuser une inscription (Organisateur)
exports.refuserInscription = async (req, res) => {
  try {
    const organisateurId = req.user.userId;
    const { inscriptionId } = req.params;
    const { message_organisateur } = req.body;

    const inscription = await Inscription.findById(inscriptionId);
    if (!inscription) {
      return res.status(404).json({ message: "Inscription non trouvée" });
    }

    // Vérifier que l'organisateur est bien le propriétaire
    if (inscription.organisateur_id.toString() !== organisateurId) {
      return res.status(403).json({
        message: "Vous n'êtes pas autorisé à refuser cette inscription",
      });
    }

    if (inscription.statut !== "en_attente") {
      return res.status(400).json({
        message: "Cette inscription a déjà été traitée",
      });
    }

    await inscription.refuser(message_organisateur);

    // Note: pas besoin de décrémenter nombre_reservations car il n'était pas encore incrémenté
    // (seulement les inscriptions approuvées sont comptées)

    const inscriptionPopulated = await Inscription.findById(inscriptionId)
      .populate("touriste_id", "fullname email")
      .populate("activite_id", "titre date_debut");

    res.status(200).json({
      message: "Inscription refusée",
      inscription: inscriptionPopulated,
    });
  } catch (error) {
    res.status(500).json({
      message: "Erreur lors du refus de l'inscription",
      error: error.message,
    });
  }
};

// Annuler une inscription (Touriste)
exports.annulerInscription = async (req, res) => {
  try {
    const touristeId = req.user.userId;
    const { inscriptionId } = req.params;

    const inscription = await Inscription.findById(inscriptionId);
    if (!inscription) {
      return res.status(404).json({ message: "Inscription non trouvée" });
    }

    // Vérifier que le touriste est bien le propriétaire
    if (inscription.touriste_id.toString() !== touristeId) {
      return res.status(403).json({
        message: "Vous n'êtes pas autorisé à annuler cette inscription",
      });
    }

    if (inscription.statut === "annulee") {
      return res.status(400).json({
        message: "Cette inscription est déjà annulée",
      });
    }

    // Décrémenter le nombre de places réservées si elle était approuvée
    // (doit être fait AVANT d'annuler pour vérifier le statut)
    const wasApproved = inscription.statut === "approuvee";
    const nombreParticipants = inscription.nombre_participants;

    await inscription.annuler();

    if (wasApproved) {
      await Activite.findByIdAndUpdate(inscription.activite_id, {
        $inc: { nombre_reservations: -nombreParticipants },
      });
    }

    res.status(200).json({
      message: "Inscription annulée avec succès",
    });
  } catch (error) {
    res.status(500).json({
      message: "Erreur lors de l'annulation de l'inscription",
      error: error.message,
    });
  }
};

// Obtenir une inscription par ID
exports.getInscriptionById = async (req, res) => {
  try {
    const { inscriptionId } = req.params;

    const inscription = await Inscription.findById(inscriptionId)
      .populate("touriste_id", "fullname email avatar num_tel")
      .populate("activite_id")
      .populate("organisateur_id", "fullname email avatar num_tel");

    if (!inscription) {
      return res.status(404).json({ message: "Inscription non trouvée" });
    }

    res.status(200).json({ inscription });
  } catch (error) {
    res.status(500).json({
      message: "Erreur lors de la récupération de l'inscription",
      error: error.message,
    });
  }
};
