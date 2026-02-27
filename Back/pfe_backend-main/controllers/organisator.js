const Organisator = require("../models/organisator");

// Compléter le profil organisator (après inscription via user/signup)
exports.completeProfileOrganisator = async (req, res) => {
  try {
    const userId = req.user.userId; // Récupéré depuis le token JWT
    const {
      age,
      num_tel,
      bio,
      pays_origine,
      avatar,
      nom_entreprise,
      numero_licence,
      adresse_entreprise,
      site_web,
      specialites,
      certifications,
      notifications_email,
      notifications_sms,
      consentement_donnees,
    } = req.body;

    // Trouver l'organisator par ID
    const organisator = await Organisator.findById(userId);
    if (!organisator) {
      return res.status(404).json({ message: "Organisator non trouvé" });
    }

    // Vérifier que c'est bien un organisator
    if (organisator.userType !== "Organisator") {
      return res
        .status(403)
        .json({ message: "Cet utilisateur n'est pas un organisateur" });
    }

    // Mettre à jour les attributs généraux (du User)
    if (age !== undefined) organisator.age = age;
    if (num_tel !== undefined) organisator.num_tel = num_tel;
    if (bio !== undefined) organisator.bio = bio;
    if (pays_origine !== undefined) organisator.pays_origine = pays_origine;
    if (avatar !== undefined) organisator.avatar = avatar;
    if (notifications_email !== undefined)
      organisator.notifications_email = notifications_email;
    if (notifications_sms !== undefined)
      organisator.notifications_sms = notifications_sms;
    if (consentement_donnees !== undefined)
      organisator.consentement_donnees = consentement_donnees;

    // Mettre à jour les attributs spécifiques à l'organisator
    if (nom_entreprise !== undefined)
      organisator.nom_entreprise = nom_entreprise;
    if (numero_licence !== undefined)
      organisator.numero_licence = numero_licence;
    if (adresse_entreprise !== undefined)
      organisator.adresse_entreprise = adresse_entreprise;
    if (site_web !== undefined) organisator.site_web = site_web;
    if (specialites !== undefined) organisator.specialites = specialites;
    if (certifications !== undefined)
      organisator.certifications = certifications;

    await organisator.save();

    // Retourner l'organisator sans le mot de passe
    const organisatorResponse = organisator.toObject();
    delete organisatorResponse.mot_de_passe;

    res
      .status(200)
      .json({
        message: "Profil organisateur complété avec succès",
        organisator: organisatorResponse,
      });
  } catch (error) {
    res
      .status(500)
      .json({
        message: "Erreur lors de la complétion du profil organisateur",
        error: error.message,
      });
  }
};

// Obtenir tous les organisators
exports.getAllOrganisators = async (req, res) => {
  try {
    const organisators = await Organisator.find().select("-mot_de_passe");
    res.status(200).json({ organisators });
  } catch (error) {
    res
      .status(500)
      .json({
        message: "Erreur lors de la récupération des organisateurs",
        error: error.message,
      });
  }
};

// Obtenir un organisator par ID
exports.getOrganisatorById = async (req, res) => {
  try {
    const organisator = await Organisator.findById(req.params.id).select(
      "-mot_de_passe",
    );
    if (!organisator) {
      return res.status(404).json({ message: "Organisator non trouvé" });
    }
    res.status(200).json({ organisator });
  } catch (error) {
    res
      .status(500)
      .json({
        message: "Erreur lors de la récupération de l'organisateur",
        error: error.message,
      });
  }
};

// Mettre à jour un organisator
exports.updateOrganisator = async (req, res) => {
  try {
    const {
      fullname,
      age,
      num_tel,
      email,
      nom_entreprise,
      numero_licence,
      adresse_entreprise,
      site_web,
      specialites,
      certifications,
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
    if (nom_entreprise) updateData.nom_entreprise = nom_entreprise;
    if (numero_licence) updateData.numero_licence = numero_licence;
    if (adresse_entreprise) updateData.adresse_entreprise = adresse_entreprise;
    if (site_web) updateData.site_web = site_web;
    if (specialites) updateData.specialites = specialites;
    if (certifications) updateData.certifications = certifications;
    if (avatar) updateData.avatar = avatar;
    if (bio) updateData.bio = bio;
    if (pays_origine) updateData.pays_origine = pays_origine;
    if (notifications_email !== undefined)
      updateData.notifications_email = notifications_email;
    if (notifications_sms !== undefined)
      updateData.notifications_sms = notifications_sms;

    const organisator = await Organisator.findByIdAndUpdate(
      req.params.id,
      updateData,
      { new: true },
    ).select("-mot_de_passe");

    if (!organisator) {
      return res.status(404).json({ message: "Organisator non trouvé" });
    }

    res
      .status(200)
      .json({ message: "Organisateur mis à jour avec succès", organisator });
  } catch (error) {
    res
      .status(500)
      .json({
        message: "Erreur lors de la mise à jour de l'organisateur",
        error: error.message,
      });
  }
};

// Supprimer un organisator
exports.deleteOrganisator = async (req, res) => {
  try {
    const organisator = await Organisator.findByIdAndDelete(req.params.id);
    if (!organisator) {
      return res.status(404).json({ message: "Organisator non trouvé" });
    }
    res.status(200).json({ message: "Organisateur supprimé avec succès" });
  } catch (error) {
    res
      .status(500)
      .json({
        message: "Erreur lors de la suppression de l'organisateur",
        error: error.message,
      });
  }
};
