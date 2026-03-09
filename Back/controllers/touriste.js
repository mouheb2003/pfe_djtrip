const Touriste = require("../models/touriste");

// Compléter le profil touriste (après inscription via user/signup)
exports.completeProfileTouriste = async (req, res) => {
  try {
    const userId = req.user.userId; // Récupéré depuis le token JWT
    const {
      age,
      num_tel,
      bio,
      pays_origine,
      avatar,
      centres_interet,
      langue_preferee,
      notifications_email,
      notifications_sms,
      consentement_donnees,
    } = req.body;

    // Trouver le touriste par ID
    const touriste = await Touriste.findById(userId);
    if (!touriste) {
      return res.status(404).json({ message: "Touriste non trouvé" });
    }

    // Vérifier que c'est bien un touriste
    if (touriste.userType !== "Touriste") {
      return res
        .status(403)
        .json({ message: "Cet utilisateur n'est pas un touriste" });
    }

    // Mettre à jour les attributs généraux (du User)
    if (age !== undefined) touriste.age = age;
    if (num_tel !== undefined) touriste.num_tel = num_tel;
    if (bio !== undefined) touriste.bio = bio;
    if (pays_origine !== undefined) touriste.pays_origine = pays_origine;
    if (avatar !== undefined) touriste.avatar = avatar;
    if (notifications_email !== undefined)
      touriste.notifications_email = notifications_email;
    if (notifications_sms !== undefined)
      touriste.notifications_sms = notifications_sms;
    if (consentement_donnees !== undefined)
      touriste.consentement_donnees = consentement_donnees;

    // Mettre à jour les attributs spécifiques au touriste
    if (centres_interet !== undefined)
      touriste.centres_interet = centres_interet;
    if (langue_preferee !== undefined)
      touriste.langue_preferee = langue_preferee;

    await touriste.save();

    // Retourner le touriste sans le mot de passe
    const touristeResponse = touriste.toObject();
    delete touristeResponse.mot_de_passe;

    res
      .status(200)
      .json({
        message: "Profil touriste complété avec succès",
        touriste: touristeResponse,
      });
  } catch (error) {
    res
      .status(500)
      .json({
        message: "Erreur lors de la complétion du profil touriste",
        error: error.message,
      });
  }
};

// Obtenir tous les touristes
exports.getAllTouristes = async (req, res) => {
  try {
    const touristes = await Touriste.find().select("-mot_de_passe");
    res.status(200).json({ touristes });
  } catch (error) {
    res
      .status(500)
      .json({
        message: "Erreur lors de la récupération des touristes",
        error: error.message,
      });
  }
};

// Obtenir un touriste par ID
exports.getTouristeById = async (req, res) => {
  try {
    const touriste = await Touriste.findById(req.params.id).select(
      "-mot_de_passe",
    );
    if (!touriste) {
      return res.status(404).json({ message: "Touriste non trouvé" });
    }
    res.status(200).json({ touriste });
  } catch (error) {
    res
      .status(500)
      .json({
        message: "Erreur lors de la récupération du touriste",
        error: error.message,
      });
  }
};

// Mettre à jour un touriste
exports.updateTouriste = async (req, res) => {
  try {
    const {
      fullname,
      age,
      num_tel,
      email,
      centres_interet,
      langue_preferee,
      avatar,
      bio,
      pays_origine,
      notifications_email,
      notifications_sms,
    } = req.body;

    const updateData = {};
    if (fullname) updateData.fullname = fullname;
    if (age) updateData.age = age;
    if (num_tel) updateData.num_tel = num_tel;
    if (email) updateData.email = email;
    if (centres_interet) updateData.centres_interet = centres_interet;
    if (langue_preferee) updateData.langue_preferee = langue_preferee;
    if (avatar) updateData.avatar = avatar;
    if (bio) updateData.bio = bio;
    if (pays_origine) updateData.pays_origine = pays_origine;
    if (notifications_email !== undefined)
      updateData.notifications_email = notifications_email;
    if (notifications_sms !== undefined)
      updateData.notifications_sms = notifications_sms;

    const touriste = await Touriste.findByIdAndUpdate(
      req.params.id,
      updateData,
      { new: true },
    ).select("-mot_de_passe");

    if (!touriste) {
      return res.status(404).json({ message: "Touriste non trouvé" });
    }

    res
      .status(200)
      .json({ message: "Touriste mis à jour avec succès", touriste });
  } catch (error) {
    res
      .status(500)
      .json({
        message: "Erreur lors de la mise à jour du touriste",
        error: error.message,
      });
  }
};

// Supprimer un touriste
exports.deleteTouriste = async (req, res) => {
  try {
    const touriste = await Touriste.findByIdAndDelete(req.params.id);
    if (!touriste) {
      return res.status(404).json({ message: "Touriste non trouvé" });
    }
    res.status(200).json({ message: "Touriste supprimé avec succès" });
  } catch (error) {
    res
      .status(500)
      .json({
        message: "Erreur lors de la suppression du touriste",
        error: error.message,
      });
  }
};

// Mettre à jour les centres d'intérêt
exports.updateCentresInteret = async (req, res) => {
  try {
    const { centres_interet } = req.body;

    const touriste = await Touriste.findByIdAndUpdate(
      req.params.id,
      { centres_interet },
      { new: true },
    ).select("-mot_de_passe");

    if (!touriste) {
      return res.status(404).json({ message: "Touriste non trouvé" });
    }

    res
      .status(200)
      .json({ message: "Centres d'intérêt mis à jour avec succès", touriste });
  } catch (error) {
    res
      .status(500)
      .json({
        message: "Erreur lors de la mise à jour des centres d'intérêt",
        error: error.message,
      });
  }
};

// Mettre à jour la langue préférée
exports.updateLanguePreferee = async (req, res) => {
  try {
    const { langue_preferee } = req.body;

    const touriste = await Touriste.findByIdAndUpdate(
      req.params.id,
      { langue_preferee },
      { new: true },
    ).select("-mot_de_passe");

    if (!touriste) {
      return res.status(404).json({ message: "Touriste non trouvé" });
    }

    res
      .status(200)
      .json({ message: "Langue préférée mise à jour avec succès", touriste });
  } catch (error) {
    res
      .status(500)
      .json({
        message: "Erreur lors de la mise à jour de la langue préférée",
        error: error.message,
      });
  }
};
