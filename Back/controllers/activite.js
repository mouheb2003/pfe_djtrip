const Activite = require("../models/activite");
const Organisator = require("../models/organisator");
const ActiviteService = require("../services/activite");

// Créer une nouvelle activité
exports.createActivite = async (req, res) => {
  try {
    const userId = req.user.userId; // ID de l'organisateur connecté

    console.log("📝 Creating activite for user:", userId);
    console.log("📄 Received files:", req.files);
    console.log("📦 Received body:", req.body);

    // Vérifier que l'utilisateur est un organisateur
    const organisator = await Organisator.findById(userId);
    if (!organisator) {
      return res.status(403).json({
        message: "Seuls les organisateurs peuvent créer des activités",
      });
    }

    // Support both camelCase (from frontend) and snake_case
    const {
      titre,
      description,
      type_activite,
      typeActivite,
      lieu,
      coordonnees,
      duree,
      prix,
      capacite_max,
      capaciteMax,
      langues_disponibles,
      niveau_difficulte,
      equipements_inclus,
      a_apporter,
      dates_disponibles,
      date_debut,
      dateDebut,
      date_fin,
      dateFin,
      statut,
    } = req.body;

    // Parse JSON fields that may come as strings from multipart/form-data
    let parsedCoordonnees = coordonnees;
    if (typeof coordonnees === "string") {
      try {
        parsedCoordonnees = JSON.parse(coordonnees);
      } catch (e) {
        console.warn("⚠️ Failed to parse coordonnees:", e);
      }
    }

    // Upload des photos vers Cloudinary si des fichiers sont fournis
    let photosUrls = [];
    if (req.files && req.files.length > 0) {
      console.log(`☁️ Uploading ${req.files.length} photos to Cloudinary...`);
      try {
        const fileBuffers = req.files.map((file) => file.buffer);
        photosUrls = await ActiviteService.uploadMultipleImages(fileBuffers);
        console.log("✅ Photos uploaded successfully:", photosUrls);
      } catch (uploadError) {
        console.error("❌ Error uploading photos:", uploadError);
        return res.status(500).json({
          message: "Erreur lors de l'upload des photos",
          error: uploadError.message,
        });
      }
    }

    // Créer la nouvelle activité
    const activite = new Activite({
      titre,
      description,
      type_activite: type_activite || typeActivite,
      organisateur_id: userId,
      lieu,
      coordonnees: parsedCoordonnees,
      duree,
      prix,
      capacite_max: capacite_max || capaciteMax,
      langues_disponibles,
      photos: photosUrls,
      niveau_difficulte,
      equipements_inclus,
      a_apporter,
      dates_disponibles,
      date_debut: date_debut || dateDebut,
      date_fin: date_fin || dateFin,
      statut: statut || "active",
    });

    console.log("📅 Activity dates being saved:");
    console.log("  - date_debut:", activite.date_debut);
    console.log("  - date_fin:", activite.date_fin);
    console.log("  - Server time now:", new Date().toISOString());

    await activite.save();

    // Ajouter l'activité à la liste de l'organisateur
    organisator.liste_activites.push(activite._id);
    await organisator.save();

    // Populate organisateur_id avant de retourner
    const activitePopulated = await Activite.findById(activite._id).populate(
      "organisateur_id",
      "fullname avatar email num_tel note_moyenne nombre_avis description",
    );

    console.log(
      "✅ Activité créée et populated:",
      JSON.stringify(activitePopulated, null, 2),
    );

    res.status(201).json({
      message: "Activité créée avec succès",
      activite: activitePopulated,
    });
  } catch (error) {
    res.status(500).json({
      message: "Erreur lors de la création de l'activité",
      error: error.message,
    });
  }
};

// Obtenir toutes les activités (avec filtres optionnels)
exports.getAllActivites = async (req, res) => {
  try {
    const {
      type_activite,
      lieu,
      statut,
      niveau_difficulte,
      prix_min,
      prix_max,
      organisateur_id,
      temporalite, // 'en_cours', 'a_venir', 'passees'
    } = req.query;

    const filter = {};

    if (type_activite) filter.type_activite = type_activite;
    if (lieu) filter.lieu = { $regex: lieu, $options: "i" }; // Recherche insensible à la casse
    if (statut) filter.statut = statut;
    if (niveau_difficulte) filter.niveau_difficulte = niveau_difficulte;
    if (organisateur_id) filter.organisateur_id = organisateur_id;

    if (prix_min || prix_max) {
      filter.prix = {};
      if (prix_min) filter.prix.$gte = parseFloat(prix_min);
      if (prix_max) filter.prix.$lte = parseFloat(prix_max);
    }

    // Filtrer par temporalité
    const maintenant = new Date();
    if (temporalite === "en_cours") {
      // Activités en cours maintenant
      filter.date_debut = { $lte: maintenant };
      filter.date_fin = { $gte: maintenant };
    } else if (temporalite === "a_venir") {
      // Activités à venir (pas encore commencées)
      filter.date_debut = { $gt: maintenant };
    } else if (temporalite === "passees") {
      // Activités terminées
      filter.date_fin = { $lt: maintenant };
    } else if (temporalite === "disponibles") {
      // Activités en cours ou à venir
      filter.date_fin = { $gte: maintenant };
    }

    const activites = await Activite.find(filter)
      .populate("organisateur_id", "fullname avatar note_moyenne nombre_avis")
      .sort({ createdAt: -1 });

    console.log(`📊 getAllActivites: Found ${activites.length} activities`);
    console.log("🕐 Server time:", new Date().toISOString());
    if (activites.length > 0) {
      console.log("  - Sample activity dates:");
      activites.slice(0, 3).forEach((act) => {
        console.log(
          `    * ${act.titre}: date_debut=${act.date_debut?.toISOString()}, date_fin=${act.date_fin?.toISOString()}`,
        );
      });
    }

    res.status(200).json({
      success: true,
      count: activites.length,
      activities: activites, // Changed from 'activites' to 'activities' for consistency
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Erreur lors de la récupération des activités",
      error: error.message,
    });
  }
};

// Obtenir une activité par ID
exports.getActiviteById = async (req, res) => {
  try {
    const activite = await Activite.findById(req.params.id).populate(
      "organisateur_id",
      "fullname avatar email num_tel note_moyenne nombre_avis description",
    );

    if (!activite) {
      return res.status(404).json({ message: "Activité non trouvée" });
    }

    res.status(200).json({ activite });
  } catch (error) {
    res.status(500).json({
      message: "Erreur lors de la récupération de l'activité",
      error: error.message,
    });
  }
};

// Obtenir les activités d'un organisateur
exports.getActivitesByOrganisateur = async (req, res) => {
  try {
    const { organisateurId } = req.params;

    const activites = await Activite.find({
      organisateur_id: organisateurId,
    }).sort({ createdAt: -1 });

    res.status(200).json({
      count: activites.length,
      activites,
    });
  } catch (error) {
    res.status(500).json({
      message: "Erreur lors de la récupération des activités de l'organisateur",
      error: error.message,
    });
  }
};

// Mettre à jour une activité
exports.updateActivite = async (req, res) => {
  try {
    const userId = req.user.userId;
    const activiteId = req.params.id;

    console.log("📝 Updating activite:", activiteId);
    console.log("📄 Received files:", req.files);
    console.log("📦 Received body:", req.body);

    // Trouver l'activité
    const activite = await Activite.findById(activiteId);
    if (!activite) {
      return res.status(404).json({ message: "Activité non trouvée" });
    }

    // Vérifier que l'utilisateur est le propriétaire de l'activité
    if (activite.organisateur_id.toString() !== userId) {
      return res.status(403).json({
        message: "Vous n'êtes pas autorisé à modifier cette activité",
      });
    }

    // Empêcher la modification des activités terminées
    const maintenant = new Date();
    if (activite.date_fin < maintenant) {
      return res.status(400).json({
        message: "Impossible de modifier une activité terminée",
      });
    }

    // Support both camelCase (from frontend) and snake_case
    const {
      titre,
      description,
      type_activite,
      typeActivite,
      lieu,
      coordonnees,
      duree,
      prix,
      capacite_max,
      capaciteMax,
      langues_disponibles,
      niveau_difficulte,
      equipements_inclus,
      a_apporter,
      dates_disponibles,
      date_debut,
      dateDebut,
      date_fin,
      dateFin,
      statut,
      keepExistingPhotos, // "true" pour garder les photos existantes et ajouter les nouvelles
    } = req.body;

    // Parse JSON fields that may come as strings from multipart/form-data
    let parsedCoordonnees = coordonnees;
    if (coordonnees !== undefined && typeof coordonnees === "string") {
      try {
        parsedCoordonnees = JSON.parse(coordonnees);
      } catch (e) {
        console.warn("⚠️ Failed to parse coordonnees:", e);
      }
    }

    const updateData = {};
    if (titre !== undefined) updateData.titre = titre;
    if (description !== undefined) updateData.description = description;
    if (type_activite !== undefined || typeActivite !== undefined)
      updateData.type_activite = type_activite || typeActivite;
    if (lieu !== undefined) updateData.lieu = lieu;
    if (parsedCoordonnees !== undefined)
      updateData.coordonnees = parsedCoordonnees;
    if (duree !== undefined) updateData.duree = duree;
    if (prix !== undefined) updateData.prix = prix;
    if (capacite_max !== undefined || capaciteMax !== undefined)
      updateData.capacite_max = capacite_max || capaciteMax;
    if (langues_disponibles !== undefined)
      updateData.langues_disponibles = langues_disponibles;
    if (niveau_difficulte !== undefined)
      updateData.niveau_difficulte = niveau_difficulte;
    if (equipements_inclus !== undefined)
      updateData.equipements_inclus = equipements_inclus;
    if (a_apporter !== undefined) updateData.a_apporter = a_apporter;
    if (dates_disponibles !== undefined)
      updateData.dates_disponibles = dates_disponibles;
    if (date_debut !== undefined || dateDebut !== undefined)
      updateData.date_debut = date_debut || dateDebut;
    if (date_fin !== undefined || dateFin !== undefined)
      updateData.date_fin = date_fin || dateFin;
    if (statut !== undefined) updateData.statut = statut;

    // Gérer les photos uploadées
    if (req.files && req.files.length > 0) {
      console.log(
        `☁️ Uploading ${req.files.length} new photos to Cloudinary...`,
      );
      try {
        const fileBuffers = req.files.map((file) => file.buffer);
        const newPhotosUrls =
          await ActiviteService.uploadMultipleImages(fileBuffers);
        console.log("✅ New photos uploaded successfully:", newPhotosUrls);

        // Si keepExistingPhotos est true, ajouter les nouvelles photos aux anciennes
        if (keepExistingPhotos === "true" || keepExistingPhotos === true) {
          updateData.photos = [...(activite.photos || []), ...newPhotosUrls];
        } else {
          // Sinon, remplacer toutes les photos
          updateData.photos = newPhotosUrls;
        }
      } catch (uploadError) {
        console.error("❌ Error uploading photos:", uploadError);
        return res.status(500).json({
          message: "Erreur lors de l'upload des photos",
          error: uploadError.message,
        });
      }
    }

    const activiteUpdated = await Activite.findByIdAndUpdate(
      activiteId,
      updateData,
      { new: true, runValidators: true },
    ).populate("organisateur_id", "fullname avatar note_moyenne nombre_avis");

    res.status(200).json({
      message: "Activité mise à jour avec succès",
      activite: activiteUpdated,
    });
  } catch (error) {
    res.status(500).json({
      message: "Erreur lors de la mise à jour de l'activité",
      error: error.message,
    });
  }
};

// Supprimer une activité
exports.deleteActivite = async (req, res) => {
  try {
    const userId = req.user.userId;
    const activiteId = req.params.id;

    // Trouver l'activité
    const activite = await Activite.findById(activiteId);
    if (!activite) {
      return res.status(404).json({ message: "Activité non trouvée" });
    }

    // Vérifier que l'utilisateur est le propriétaire de l'activité
    if (activite.organisateur_id.toString() !== userId) {
      return res.status(403).json({
        message: "Vous n'êtes pas autorisé à supprimer cette activité",
      });
    }

    // Supprimer l'activité de la liste de l'organisateur
    await Organisator.findByIdAndUpdate(userId, {
      $pull: { liste_activites: activiteId },
    });

    // Supprimer l'activité
    await Activite.findByIdAndDelete(activiteId);

    res.status(200).json({
      message: "Activité supprimée avec succès",
    });
  } catch (error) {
    res.status(500).json({
      message: "Erreur lors de la suppression de l'activité",
      error: error.message,
    });
  }
};

// Rechercher des activités (recherche textuelle)
exports.searchActivites = async (req, res) => {
  try {
    const { query } = req.query;

    if (!query) {
      return res.status(400).json({
        message: "Le paramètre de recherche 'query' est requis",
      });
    }

    const activites = await Activite.find({
      $or: [
        { titre: { $regex: query, $options: "i" } },
        { description: { $regex: query, $options: "i" } },
        { lieu: { $regex: query, $options: "i" } },
      ],
      statut: "active",
    })
      .populate("organisateur_id", "fullname avatar note_moyenne nombre_avis")
      .limit(20);

    res.status(200).json({
      count: activites.length,
      activites,
    });
  } catch (error) {
    res.status(500).json({
      message: "Erreur lors de la recherche d'activités",
      error: error.message,
    });
  }
};

// Obtenir les activités de l'organisateur connecté (en cours et à venir)
exports.getMyActivities = async (req, res) => {
  try {
    const userId = req.user.userId;

    const maintenant = new Date();
    console.log("🕐 Backend timezone check:");
    console.log("  - Server time (local):", maintenant.toString());
    console.log("  - Server time (UTC):", maintenant.toISOString());
    console.log("  - Server time (timestamp):", maintenant.getTime());

    // Activités dont la date de fin n'est pas encore passée
    const activities = await Activite.find({
      organisateur_id: userId,
      date_fin: { $gte: maintenant }, // date_fin >= maintenant
    })
      .populate("organisateur_id", "fullname avatar note_moyenne nombre_avis")
      .sort({ date_debut: 1 }); // Trier par date de début

    console.log(`📋 Found ${activities.length} active activities`);
    if (activities.length > 0) {
      console.log("  - First activity date_fin:", activities[0].date_fin);
    }

    res.status(200).json({
      success: true,
      count: activities.length,
      activities,
    });
  } catch (error) {
    console.error("❌ Error fetching my activities:", error);
    res.status(500).json({
      success: false,
      message: "Erreur lors de la récupération des activités",
      error: error.message,
    });
  }
};

// Obtenir les activités archivées de l'organisateur connecté (passées)
exports.getArchivedActivities = async (req, res) => {
  try {
    const userId = req.user.userId;

    const maintenant = new Date();

    // Activités dont la date de fin est passée
    const activities = await Activite.find({
      organisateur_id: userId,
      date_fin: { $lt: maintenant }, // date_fin < maintenant
    })
      .populate("organisateur_id", "fullname avatar note_moyenne nombre_avis")
      .sort({ date_fin: -1 }); // Trier par date de fin (plus récentes d'abord)

    res.status(200).json({
      success: true,
      count: activities.length,
      activities,
    });
  } catch (error) {
    console.error("❌ Error fetching archived activities:", error);
    res.status(500).json({
      success: false,
      message: "Erreur lors de la récupération des activités archivées",
      error: error.message,
    });
  }
};
