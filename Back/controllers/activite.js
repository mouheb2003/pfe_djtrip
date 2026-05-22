const Activite = require("../models/activite");
const Organisator = require("../models/organisator");
const Inscription = require("../models/inscription");
const ActiviteService = require("../services/activite");
const cloudinary = require("../config/cloudinary");
const notificationEventBus = require("../services/notificationEventBus");
const emailService = require("../services/email");

// Helper: extract Cloudinary public_id from a URL
const extractCloudinaryPublicId = (url) => {
  try {
    // URL pattern: https://res.cloudinary.com/<cloud>/image/upload/v<version>/<public_id>.<ext>
    const parts = url.split("/upload/");
    if (parts.length < 2) return null;
    const withVersion = parts[1]; // e.g. v1234567/folder/filename.jpg
    const withoutVersion = withVersion.replace(/^v\d+\//, ""); // remove v<number>/
    const withoutExtension = withoutVersion.replace(/\.[^/.]+$/, ""); // remove extension
    return withoutExtension;
  } catch {
    return null;
  }
};

// Create a new activity
exports.createActivite = async (req, res) => {
  try {
    const userId = req.user.userId; // Logged-in organizer ID

    console.log(
      "� DEBUG: Creating activity with data:",
      JSON.stringify(req.body, null, 2),
    );

    const {
      titre,
      description,
      type_activite,
      typeActivite,
      categorie,
      lieu,
      location_type,
      coordonnees,
      itineraire,
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
      ai_generated_image_url,
      aiGeneratedImageUrl,
    } = req.body;

    // Verify the user is an organizer
    const organisator = await Organisator.findById(userId);
    if (!organisator) {
      return res.status(403).json({
        message: "Only organizers can create activities",
      });
    }

    // Parse JSON fields if they come as strings
    const parsedLangues =
      typeof langues_disponibles === "string"
        ? JSON.parse(langues_disponibles)
        : langues_disponibles || ["English"];

    const parsedEquipements =
      typeof equipements_inclus === "string"
        ? JSON.parse(equipements_inclus)
        : equipements_inclus || [];

    const parsedApporter =
      typeof a_apporter === "string"
        ? JSON.parse(a_apporter)
        : a_apporter || [];

    const parsedDates =
      typeof dates_disponibles === "string"
        ? JSON.parse(dates_disponibles)
        : dates_disponibles || [];

    const parsedItineraire =
      typeof itineraire === "string"
        ? JSON.parse(itineraire)
        : itineraire || [];

    const parsedCoordonnees =
      typeof coordonnees === "string" ? JSON.parse(coordonnees) : coordonnees;

    const effectiveLocationType =
      location_type ||
      (parsedItineraire && parsedItineraire.length > 0
        ? "itinerary"
        : parsedCoordonnees
          ? "fixed"
          : "custom");

    // Validate: if explicitly setting itinerary type, must have itinerary data
    if (
      (location_type === "itinerary" ||
        effectiveLocationType === "itinerary") &&
      (!parsedItineraire || parsedItineraire.length === 0)
    ) {
      return res.status(400).json({
        success: false,
        message:
          "Itinerary type requires at least one itinerary item with address and coordinates",
      });
    }

    // Upload photos to Cloudinary if files are provided
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
          message: "Error uploading photos",
          error: uploadError.message,
        });
      }
    }

    // Add AI-generated image URL if provided
    const aiImageUrl = ai_generated_image_url || aiGeneratedImageUrl;
    console.log("🤖 AI-generated image URL received:", aiImageUrl);
    if (aiImageUrl && aiImageUrl.length > 0) {
      console.log("🤖 Adding AI-generated image URL:", aiImageUrl);
      photosUrls.push(aiImageUrl);
    }

    // Validate activity start date: must be at least 24 hours from now
    const startDate = date_debut || dateDebut;
    if (startDate) {
      const now = new Date();
      const activityStartDate = new Date(startDate);
      const twentyFourHoursLater = new Date(
        now.getTime() + 24 * 60 * 60 * 1000,
      ); // 24 hours from now

      if (activityStartDate < twentyFourHoursLater) {
        return res.status(400).json({
          message: "Activity start date must be at least 24 hours from now",
        });
      }
    }

    // Create activity object
    const activityData = {
      titre,
      description,
      type_activite: type_activite || typeActivite,
      categorie,
      organisateur_id: userId,
      lieu,
      location_type: effectiveLocationType,
      duree,
      prix,
      capacite_max: capacite_max || capaciteMax,
      langues_disponibles: parsedLangues,
      photos: photosUrls,
      niveau_difficulte,
      equipements_inclus: parsedEquipements,
      a_apporter: parsedApporter,
      dates_disponibles: parsedDates,
      date_debut: date_debut || dateDebut,
      date_fin: date_fin || dateFin,
      statut: statut || "active",
    };

    // Add location-specific data
    if (effectiveLocationType === "fixed" && parsedCoordonnees) {
      activityData.coordonnees = parsedCoordonnees;
    } else if (
      effectiveLocationType === "itinerary" &&
      parsedItineraire &&
      parsedItineraire.length > 0
    ) {
      activityData.itineraire = parsedItineraire;
    }

    console.log(
      "🔍 DEBUG: Final activity data before save:",
      JSON.stringify(activityData, null, 2),
    );

    // Create the new activity
    const activite = new Activite(activityData);

    console.log("📅 Activity dates being saved:");
    console.log("  - date_debut:", activite.date_debut);
    console.log("  - date_fin:", activite.date_fin);
    console.log("  - Server time now:", new Date().toISOString());

    await activite.save();

    // Add activity to organizer's list
    organisator.liste_activites.push(activite._id);
    await organisator.save();

    // Populate organisateur_id before returning
    let activitePopulated;
    try {
      activitePopulated = await Activite.findById(activite._id).populate(
        "organisateur_id",
        "fullname avatar email num_tel note_moyenne nombre_avis description",
      );

      console.log(
        "✅ Activity created and populated:",
        JSON.stringify(activitePopulated, null, 2),
      );
    } catch (populateError) {
      console.error("❌ Error populating activity:", populateError);
      // Continue with non-populated activity if populate fails
      activitePopulated = activite;
    }

    // Emit activity created event for notification to followers (if enabled)
    const notifyFollowers = req.body.notifyFollowers !== "false";
    if (notifyFollowers) {
      try {
        const Follow = require("../models/follow");
        const followers = await Follow.find({ following_id: userId }).select(
          "follower_id",
        );
        const followerIds = followers.map((f) => f.follower_id);

        if (followerIds.length > 0) {
          notificationEventBus.emitActivityCreated({
            organizerId: userId,
            organizerName: organisator.fullname,
            activityTitle: activite.titre,
            activityId: activite._id,
            followerIds: followerIds,
          });
        }
      } catch (notifError) {
        console.warn(
          "Failed to send activity created notification:",
          notifError.message,
        );
      }
    }

    try {
      res.status(201).json({
        success: true,
        message: "Activity created successfully",
        data: activitePopulated,
      });
    } catch (responseError) {
      console.error("❌ Error sending response:", responseError);
      throw responseError;
    }
  } catch (error) {
    console.error("❌ Create activity error:", error);

    if (error.name === "ValidationError") {
      const validationErrors = Object.values(error.errors).map(
        (err) => err.message,
      );
      return res.status(400).json({
        success: false,
        message: "Validation failed",
        errors: validationErrors,
      });
    }

    res.status(500).json({
      success: false,
      message: "Internal server error",
      error: error.message,
    });
  }
};

// Get all activities (with optional filters)
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
      temporalite, // 'en_cours', 'a_venir', 'passees', 'disponibles'
      search, // text search across titre, description, lieu
      sort, // 'prix_asc', 'prix_desc', 'note_desc', 'date_asc', 'recent' (default)
      page = 1,
      limit = 10,
    } = req.query;

    const filter = {};

    if (type_activite) filter.type_activite = type_activite;
    if (lieu) filter.lieu = { $regex: lieu, $options: "i" };
    if (statut) filter.statut = statut;
    if (niveau_difficulte) filter.niveau_difficulte = niveau_difficulte;
    if (organisateur_id) filter.organisateur_id = organisateur_id;

    // Unified text search across titre, description, lieu
    if (search && search.trim()) {
      filter.$or = [
        { titre: { $regex: search.trim(), $options: "i" } },
        { description: { $regex: search.trim(), $options: "i" } },
        { lieu: { $regex: search.trim(), $options: "i" } },
      ];
    }

    if (prix_min || prix_max) {
      filter.prix = {};
      if (prix_min) filter.prix.$gte = parseFloat(prix_min);
      if (prix_max) filter.prix.$lte = parseFloat(prix_max);
    }

    // Filter by temporality
    const maintenant = new Date();
    if (temporalite === "en_cours") {
      filter.date_debut = { $lte: maintenant };
      filter.date_fin = { $gte: maintenant };
    } else if (temporalite === "a_venir") {
      filter.date_debut = { $gt: maintenant };
    } else if (temporalite === "passees") {
      filter.date_fin = { $lt: maintenant };
    } else if (temporalite === "disponibles") {
      filter.date_fin = { $gte: maintenant };
    }

    // Determine sort order
    let sortOption = { createdAt: -1 }; // default: most recent first
    if (sort === "prix_asc") sortOption = { prix: 1 };
    else if (sort === "prix_desc") sortOption = { prix: -1 };
    else if (sort === "note_desc") sortOption = { note_moyenne: -1 };
    else if (sort === "date_asc") sortOption = { date_debut: 1 };

    // Pagination
    const pageNum = parseInt(page);
    const limitNum = parseInt(limit);
    const skip = (pageNum - 1) * limitNum;

    const [activites, total] = await Promise.all([
      Activite.find(filter)
        .populate(
          "organisateur_id",
          "fullname avatar note_moyenne nombre_avis date_inscription bio pays_origine specialites_activites langues_proposees types_activites",
        )
        .sort(sortOption)
        .skip(skip)
        .limit(limitNum),
      Activite.countDocuments(filter),
    ]);

    // Add isBookmarked field for authenticated users
    const currentUserId = req.user?.userId;
    if (currentUserId) {
      activites.forEach((activity) => {
        const bookmarkedBy = Array.isArray(activity.bookmarked_by)
          ? activity.bookmarked_by.map((id) => String(id))
          : [];
        activity.isBookmarked = bookmarkedBy.includes(String(currentUserId));
      });
    }

    res.status(200).json({
      success: true,
      count: activites.length,
      total,
      page: pageNum,
      pages: Math.ceil(total / limitNum),
      activities: activites,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error retrieving activities",
      error: error.message,
    });
  }
};

// Get an activity by ID
exports.getActiviteById = async (req, res) => {
  try {
    const activite = await Activite.findById(req.params.id).populate(
      "organisateur_id",
      "fullname avatar email num_tel note_moyenne nombre_avis description date_inscription bio pays_origine specialites_activites langues_proposees types_activites",
    );

    if (!activite) {
      return res.status(404).json({ message: "Activity not found" });
    }

    res.status(200).json({ activite });
  } catch (error) {
    res.status(500).json({
      message: "Error retrieving activity",
      error: error.message,
    });
  }
};

// Get activities for an organizer
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
      message: "Error retrieving organizer activities",
      error: error.message,
    });
  }
};

// Update an activity
exports.updateActivite = async (req, res) => {
  try {
    const userId = req.user.userId;
    const activiteId = req.params.id;

    console.log("📝 Updating activite:", activiteId);
    console.log("📄 Received files:", req.files);
    console.log("📦 Received body:", req.body);

    // Find the activity
    const activite = await Activite.findById(activiteId);
    if (!activite) {
      return res.status(404).json({ message: "Activity not found" });
    }

    // Verify the user owns the activity
    const activityOrganizerId = activite.organisateur_id.toString().trim();
    const userIdString = String(userId).trim();

    if (activityOrganizerId !== userIdString) {
      return res.status(403).json({
        message: "You are not authorized to modify this activity",
      });
    }

    console.log("📦 Full req.body keys:", Object.keys(req.body));
    console.log("📦 Full req.body:", req.body);

    // Support both camelCase (from frontend) and snake_case
    const {
      titre,
      description,
      type_activite,
      typeActivite,
      categorie,
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
      keepExistingPhotos, // "true" to keep existing photos and add the new ones
      ai_generated_image_url,
      aiGeneratedImageUrl,
      existing_photo_urls,
      existingPhotoUrls,
      location_type,
      locationType,
      itineraire,
      itineraire_coords,
      itineraireCoords,
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

    let parsedEquipementsInclus = equipements_inclus;
    if (
      equipements_inclus !== undefined &&
      typeof equipements_inclus === "string"
    ) {
      try {
        parsedEquipementsInclus = JSON.parse(equipements_inclus);
      } catch (e) {
        parsedEquipementsInclus = [equipements_inclus];
      }
    }

    let parsedExistingPhotoUrls = existing_photo_urls || existingPhotoUrls;
    const existingPhotoUrlsProvided =
      existing_photo_urls !== undefined || existingPhotoUrls !== undefined;
    if (
      parsedExistingPhotoUrls !== undefined &&
      typeof parsedExistingPhotoUrls === "string"
    ) {
      try {
        parsedExistingPhotoUrls = JSON.parse(parsedExistingPhotoUrls);
      } catch (e) {
        console.warn("⚠️ Failed to parse existing_photo_urls:", e);
        parsedExistingPhotoUrls = [];
      }
    }

    let parsedItineraireCoords = itineraire_coords || itineraireCoords;
    if (
      parsedItineraireCoords !== undefined &&
      typeof parsedItineraireCoords === "string"
    ) {
      try {
        parsedItineraireCoords = JSON.parse(parsedItineraireCoords);
      } catch (e) {
        console.warn("⚠️ Failed to parse itineraire_coords:", e);
        parsedItineraireCoords = [];
      }
    }

    const updateData = {};
    if (titre !== undefined) updateData.titre = titre;
    if (description !== undefined) updateData.description = description;
    if (type_activite !== undefined || typeActivite !== undefined)
      updateData.type_activite = type_activite || typeActivite;
    if (categorie !== undefined) updateData.categorie = categorie;
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
    if (parsedEquipementsInclus !== undefined)
      updateData.equipements_inclus = parsedEquipementsInclus;
    if (a_apporter !== undefined) updateData.a_apporter = a_apporter;
    if (dates_disponibles !== undefined)
      updateData.dates_disponibles = dates_disponibles;
    if (date_debut !== undefined || dateDebut !== undefined)
      updateData.date_debut = date_debut || dateDebut;
    if (date_fin !== undefined || dateFin !== undefined)
      updateData.date_fin = date_fin || dateFin;
    if (statut !== undefined) updateData.statut = statut;

    // Handle location type changes and clean up incompatible data
    const newLocationType = location_type || locationType;
    if (newLocationType !== undefined) {
      updateData.location_type = newLocationType;

      // Clean up data when changing location types
      if (newLocationType === "itinerary") {
        // Switching TO itinerary - keep existing itinerary or use provided one
        if (itineraire === undefined) {
          // No itinerary data provided - keep existing itinerary (allow temporary empty state for switching)
          console.log(
            "🔄 Switching TO itinerary, keeping existing itinerary data",
          );
        }
      } else {
        // Switching FROM itinerary to fixed/custom - explicitly clear itinerary data
        console.log(
          "🔄 Clearing itinerary data when switching to:",
          newLocationType,
        );
        updateData.itineraire = [];
        updateData.itineraire_coords = [];
      }
    }

    let parsedItineraire = itineraire;
    if (itineraire !== undefined && typeof itineraire === "string") {
      try {
        parsedItineraire = JSON.parse(itineraire);
      } catch (e) {
        console.warn("⚠️ Failed to parse itineraire:", e);
      }
    }
    if (parsedItineraire !== undefined) {
      if (parsedItineraire.length > 0) {
        updateData.itineraire = parsedItineraire;
        if (parsedItineraireCoords !== undefined) {
          updateData.itineraire_coords = parsedItineraireCoords;
        }
      } else if (
        parsedItineraire.length === 0 &&
        (location_type || locationType) === "itinerary"
      ) {
        // Allow empty itinerary during type switching, will be validated later
        console.log(
          "⚠️ Empty itinerary provided for itinerary type - allowing for now",
        );
        updateData.itineraire = [];
      }
    }

    // Handle uploaded photos
    if (req.files && req.files.length > 0) {
      console.log(
        `☁️ Uploading ${req.files.length} new photos to Cloudinary...`,
      );
      try {
        const fileBuffers = req.files.map((file) => file.buffer);
        const newPhotosUrls =
          await ActiviteService.uploadMultipleImages(fileBuffers);
        console.log("✅ New photos uploaded successfully:", newPhotosUrls);

        // Use parsed existing photo URLs if provided, otherwise use activity's current photos
        const basePhotos =
          parsedExistingPhotoUrls && parsedExistingPhotoUrls.length > 0
            ? parsedExistingPhotoUrls
            : activite.photos || [];

        // If keepExistingPhotos is true, append new photos to existing ones
        if (keepExistingPhotos === "true" || keepExistingPhotos === true) {
          updateData.photos = [...basePhotos, ...newPhotosUrls];
        } else {
          // Otherwise, replace all photos
          updateData.photos = newPhotosUrls;
        }
      } catch (uploadError) {
        console.error("❌ Error uploading photos:", uploadError);
        return res.status(500).json({
          message: "Error uploading photos",
          error: uploadError.message,
        });
      }
    } else {
      // If no new photos uploaded, check if existing_photo_urls was provided
      if (existingPhotoUrlsProvided) {
        // Field was provided - use it (even if empty to delete all photos)
        console.log(
          "📸 Using provided existing photo URLs (may be empty):",
          parsedExistingPhotoUrls || [],
        );
        updateData.photos = parsedExistingPhotoUrls || [];
      } else {
        // Field not provided - keep existing photos
        console.log("📸 No new photos uploaded, keeping existing photos");
        updateData.photos = activite.photos || [];
      }
    }

    // Add AI-generated image URL if provided (and not already in photos)
    const aiImageUrl = ai_generated_image_url || aiGeneratedImageUrl;
    if (
      aiImageUrl &&
      aiImageUrl.length > 0 &&
      !updateData.photos.includes(aiImageUrl)
    ) {
      console.log("🤖 Adding AI-generated image URL to update:", aiImageUrl);
      updateData.photos.push(aiImageUrl);
    }

    console.log(
      "📝 Update data being sent:",
      JSON.stringify(updateData, null, 2),
    );

    const activiteUpdated = await Activite.findByIdAndUpdate(
      activiteId,
      updateData,
      { new: true, runValidators: true },
    ).populate(
      "organisateur_id",
      "fullname avatar note_moyenne nombre_avis date_inscription bio pays_origine specialites_activites langues_proposees types_activites",
    );

    if (!activiteUpdated) {
      console.error(
        "❌ Failed to update activity - document not found or update failed",
      );
      return res.status(404).json({
        success: false,
        message: "Activity not found or could not be updated",
      });
    }

    console.log("✅ Activity updated successfully:", activiteUpdated._id);

    // Emit activity updated event for notification to booked users (if enabled)
    const notifyBookedUsers = req.body.notifyBookedUsers !== "false";
    if (notifyBookedUsers) {
      try {
        const bookings = await Inscription.find({
          activite_id: activiteId,
          statut: "confirmed",
        }).select("touriste_id");
        const bookedUserIds = bookings.map((b) => b.touriste_id);

        if (bookedUserIds.length > 0) {
          notificationEventBus.emitActivityUpdated({
            activityId: activiteId,
            activityTitle: activiteUpdated.titre,
            bookedUserIds: bookedUserIds,
          });
        }
      } catch (notifError) {
        console.warn(
          "Failed to send activity updated notification:",
          notifError.message,
        );
      }
    }

    // Emit activity updated event for notification to followers (if enabled)
    const notifyFollowers = req.body.notifyFollowers !== "false";
    if (notifyFollowers) {
      try {
        const Follow = require("../models/follow");
        const followers = await Follow.find({ following_id: userId }).select(
          "follower_id",
        );
        const followerIds = followers.map((f) => f.follower_id);

        if (followerIds.length > 0) {
          notificationEventBus.emitActivityCreated({
            organizerId: userId,
            organizerName: organisator.fullname,
            activityTitle: activiteUpdated.titre,
            activityId: activiteId,
            followerIds: followerIds,
          });
        }
      } catch (notifError) {
        console.warn(
          "Failed to send activity updated notification to followers:",
          notifError.message,
        );
      }
    }

    res.status(200).json({
      message: "Activity updated successfully",
      activite: activiteUpdated,
    });
  } catch (error) {
    console.error("❌ Update activity error:", error);
    console.error("Error name:", error.name);
    console.error("Error message:", error.message);
    console.error("Error details:", JSON.stringify(error, null, 2));

    if (error.name === "ValidationError") {
      const validationErrors = Object.values(error.errors).map(
        (err) => err.message,
      );
      return res.status(400).json({
        success: false,
        message: "Validation failed",
        errors: validationErrors,
      });
    }

    res.status(500).json({
      success: false,
      message: "Error updating activity",
      error: error.message,
    });
  }
};

// Delete an activity
exports.deleteActivite = async (req, res) => {
  try {
    const userId = req.user.userId;
    const activiteId = req.params.id;
    const cancellationMessage = String(req.query.cancel_message || "").trim();

    // Find the activity
    const activite = await Activite.findById(activiteId);
    if (!activite) {
      return res.status(404).json({ message: "Activity not found" });
    }

    // Verify the user owns the activity
    const activityOrganizerId = activite.organisateur_id.toString().trim();
    const userIdString = String(userId).trim();

    if (activityOrganizerId !== userIdString) {
      return res.status(403).json({
        message: "You are not authorized to delete this activity",
      });
    }

    // Check if it's a Cancel or a permanent Delete
    // Past or already cancelled activities can be permanently deleted
    const isPast = activite.date_fin < new Date();
    const isCancelled = activite.statut === 'cancelled';
    const canBePermanentlyDeleted = isPast || isCancelled;

    if (!canBePermanentlyDeleted) {
      // Logic for CANCELLATION (Soft Delete)
      
      // Check for approved or checked-in (used) bookings specifically as per user request
      const approvedOrUsedBookings = await Inscription.find({
        activite_id: activiteId,
        statut: { $in: ["approved", "verified"] },
      });

      // If there are approved or used bookings, cancellation message is mandatory
      if (approvedOrUsedBookings.length > 0 && !cancellationMessage) {
        return res.status(400).json({
          success: false,
          code: "REASON_REQUIRED",
          message: "A cancellation message is required because this activity has approved or used bookings.",
        });
      }

      // Mark activity as cancelled
      activite.statut = 'cancelled';
      await activite.save();

      // Cancel all related bookings (pending, approved, and verified/used)
      // We exclude already cancelled/rejected ones
      const activeInscriptions = await Inscription.find({
        activite_id: activiteId,
        statut: { $in: ["pending", "approved", "verified"] }
      }).populate("touriste_id", "email fullname");

      if (activeInscriptions.length > 0) {
        await Inscription.updateMany(
          { _id: { $in: activeInscriptions.map(i => i._id) } },
          {
            $set: {
              statut: "cancelled",
              message_organisateur: cancellationMessage || "Activity cancelled by organizer.",
              date_reponse: new Date(),
              cancellationPolicy: {
                canCancel: false,
                cancellationDeadline: activite.date_debut,
                cancellationFee: 0,
                refundAmount: 0,
                cancelledAt: new Date(),
                cancellationReason: cancellationMessage || "Activity cancelled by organizer.",
                refundProcessed: true
              }
            },
          },
        );

        // Send emails to all participants
        for (const ins of activeInscriptions) {
          const email = ins.isExternal ? ins.externalEmail : ins.touriste_id?.email;
          const fullname = ins.isExternal ? ins.externalName : ins.touriste_id?.fullname || "Traveler";

          if (email) {
            try {
              await emailService.sendActivityCancelledEmail({
                email,
                fullname,
                activityTitle: activite.titre,
                reason: cancellationMessage || "The organizer has cancelled this activity.",
              });
            } catch (emailErr) {
              console.warn(`Failed to send cancellation email to ${email}:`, emailErr.message);
            }
          }
        }

        // Emit notifications via bus
        try {
          notificationEventBus.emitActivityCancelled({
            activityId: activiteId,
            activityTitle: activite.titre,
            bookedUserIds: activeInscriptions.map(i => i.touriste_id._id),
            reason: cancellationMessage,
          });
        } catch (notifError) {
          console.warn("Failed to send activity cancelled notification:", notifError.message);
        }
      }

      return res.status(200).json({
        success: true,
        message: "Activity cancelled successfully and moved to archive",
      });
    }

    // Logic for PERMANENT DELETE (Hard Delete)
    // Only reachable if activity is already in archive (past or cancelled)

    // Delete Cloudinary photos (clean up orphaned assets)
    if (activite.photos && activite.photos.length > 0) {
      const deletePromises = activite.photos
        .map(extractCloudinaryPublicId)
        .filter(Boolean)
        .map((publicId) =>
          cloudinary.uploader.destroy(publicId).catch((err) => {
            console.warn(
              `⚠️ Could not delete Cloudinary asset ${publicId}:`,
              err.message,
            );
          }),
        );
      await Promise.all(deletePromises);
      console.log(
        `🗑️ Deleted ${deletePromises.length} Cloudinary photos for activity ${activiteId}`,
      );
    }

    // Remove activity from organizer's list
    await Organisator.findByIdAndUpdate(userId, {
      $pull: { liste_activites: activiteId },
    });

    // Delete the activity
    await Activite.findByIdAndDelete(activiteId);

    res.status(200).json({
      success: true,
      message: "Activity deleted permanently",
    });
  } catch (error) {
    res.status(500).json({
      message: "Error deleting activity",
      error: error.message,
    });
  }
};

exports.getAdminActivites = async (_req, res) => {
  try {
    const activites = await Activite.find({})
      .sort({ createdAt: -1 })
      .limit(500)
      .populate(
        "organisateur_id",
        "fullname email avatar date_inscription bio pays_origine specialites_activites langues_proposees types_activites",
      )
      .lean();

    return res.status(200).json({ activites });
  } catch (error) {
    return res.status(500).json({
      message: "Error retrieving activities for admin",
      error: error.message,
    });
  }
};

exports.createAdminActivite = async (req, res) => {
  try {
    const body = req.body || {};

    const activite = await Activite.create({
      titre: String(body.titre || "").trim(),
      description: String(body.description || "").trim(),
      type_activite: body.type_activite || "Other",
      categorie: String(body.categorie || "Other").trim(),
      organisateur_id: body.organisateur_id,
      lieu: String(body.lieu || "").trim(),
      coordonnees: {
        latitude: body?.coordonnees?.latitude,
        longitude: body?.coordonnees?.longitude,
      },
      duree: Number(body.duree),
      prix: Number(body.prix),
      capacite_max: Number(body.capacite_max),
      langues_disponibles: Array.isArray(body.langues_disponibles)
        ? body.langues_disponibles
        : ["English"],
      photos: Array.isArray(body.photos) ? body.photos : [],
      niveau_difficulte: body.niveau_difficulte || "Easy",
      equipements_inclus: Array.isArray(body.equipements_inclus)
        ? body.equipements_inclus
        : [],
      a_apporter: Array.isArray(body.a_apporter) ? body.a_apporter : [],
      dates_disponibles: Array.isArray(body.dates_disponibles)
        ? body.dates_disponibles
        : [],
      date_debut: body.date_debut,
      date_fin: body.date_fin,
      statut: body.statut || "active",
    });

    const populated = await Activite.findById(activite._id).populate(
      "organisateur_id",
      "fullname email avatar date_inscription bio pays_origine specialites_activites langues_proposees types_activites",
    );

    return res.status(201).json({
      message: "Activity created successfully",
      activite: populated,
    });
  } catch (error) {
    return res.status(500).json({
      message: "Error creating activity as admin",
      error: error.message,
    });
  }
};

exports.updateAdminActivite = async (req, res) => {
  try {
    const { id } = req.params;
    const body = req.body || {};

    const updateData = {};

    if (Object.prototype.hasOwnProperty.call(body, "titre"))
      updateData.titre = String(body.titre || "").trim();
    if (Object.prototype.hasOwnProperty.call(body, "description"))
      updateData.description = String(body.description || "").trim();
    if (Object.prototype.hasOwnProperty.call(body, "type_activite"))
      updateData.type_activite = body.type_activite;
    if (Object.prototype.hasOwnProperty.call(body, "categorie"))
      updateData.categorie = String(body.categorie || "").trim();
    if (Object.prototype.hasOwnProperty.call(body, "organisateur_id"))
      updateData.organisateur_id = body.organisateur_id;
    if (Object.prototype.hasOwnProperty.call(body, "lieu"))
      updateData.lieu = String(body.lieu || "").trim();
    if (Object.prototype.hasOwnProperty.call(body, "coordonnees"))
      updateData.coordonnees = body.coordonnees;
    if (Object.prototype.hasOwnProperty.call(body, "duree"))
      updateData.duree = Number(body.duree);
    if (Object.prototype.hasOwnProperty.call(body, "prix"))
      updateData.prix = Number(body.prix);
    if (Object.prototype.hasOwnProperty.call(body, "capacite_max"))
      updateData.capacite_max = Number(body.capacite_max);
    if (Object.prototype.hasOwnProperty.call(body, "langues_disponibles"))
      updateData.langues_disponibles = Array.isArray(body.langues_disponibles)
        ? body.langues_disponibles
        : [];
    if (Object.prototype.hasOwnProperty.call(body, "photos"))
      updateData.photos = Array.isArray(body.photos) ? body.photos : [];
    if (Object.prototype.hasOwnProperty.call(body, "niveau_difficulte"))
      updateData.niveau_difficulte = body.niveau_difficulte;
    if (Object.prototype.hasOwnProperty.call(body, "equipements_inclus"))
      updateData.equipements_inclus = Array.isArray(body.equipements_inclus)
        ? body.equipements_inclus
        : [];
    if (Object.prototype.hasOwnProperty.call(body, "a_apporter"))
      updateData.a_apporter = Array.isArray(body.a_apporter)
        ? body.a_apporter
        : [];
    if (Object.prototype.hasOwnProperty.call(body, "dates_disponibles"))
      updateData.dates_disponibles = Array.isArray(body.dates_disponibles)
        ? body.dates_disponibles
        : [];
    if (Object.prototype.hasOwnProperty.call(body, "date_debut"))
      updateData.date_debut = body.date_debut;
    if (Object.prototype.hasOwnProperty.call(body, "date_fin"))
      updateData.date_fin = body.date_fin;
    if (Object.prototype.hasOwnProperty.call(body, "statut"))
      updateData.statut = body.statut;

    const activite = await Activite.findByIdAndUpdate(id, updateData, {
      new: true,
      runValidators: true,
    }).populate(
      "organisateur_id",
      "fullname email avatar date_inscription bio pays_origine specialites_activites langues_proposees types_activites",
    );

    if (!activite) {
      return res.status(404).json({ message: "Activity not found" });
    }

    return res.status(200).json({
      message: "Activity updated successfully",
      activite,
    });
  } catch (error) {
    return res.status(500).json({
      message: "Error updating activity as admin",
      error: error.message,
    });
  }
};

exports.deleteAdminActivite = async (req, res) => {
  try {
    const { id } = req.params;

    const activite = await Activite.findByIdAndDelete(id);
    if (!activite) {
      return res.status(404).json({ message: "Activity not found" });
    }

    return res.status(200).json({
      message: "Activity deleted successfully",
    });
  } catch (error) {
    return res.status(500).json({
      message: "Error deleting activity as admin",
      error: error.message,
    });
  }
};

// Search for activities (text search)
exports.searchActivites = async (req, res) => {
  try {
    const { query } = req.query;

    if (!query) {
      return res.status(400).json({
        message: "The 'query' search parameter is required",
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
      .populate(
        "organisateur_id",
        "fullname avatar note_moyenne nombre_avis date_inscription bio pays_origine specialites_activites langues_proposees types_activites",
      )
      .limit(20);

    res.status(200).json({
      count: activites.length,
      activites,
    });
  } catch (error) {
    res.status(500).json({
      message: "Error searching for activities",
      error: error.message,
    });
  }
};

// Get logged-in organizer's activities (ongoing and upcoming)
exports.getMyActivities = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { include_archived } = req.query;

    const maintenant = new Date();
    console.log("🕐 Backend timezone check:");
    console.log("  - Server time (local):", maintenant.toString());
    console.log("  - Server time (UTC):", maintenant.toISOString());
    console.log("  - Server time (timestamp):", maintenant.getTime());
    console.log("  - include_archived:", include_archived);

    // Build query filter
    const filter = { organisateur_id: userId };

    // If include_archived is NOT true, only return activities whose end date has not yet passed
    if (include_archived !== "true" && include_archived !== true) {
      filter.date_fin = { $gte: maintenant }; // date_fin >= now
    }

    const activities = await Activite.find(filter)
      .populate(
        "organisateur_id",
        "fullname avatar note_moyenne nombre_avis date_inscription bio pays_origine specialites_activites langues_proposees types_activites",
      )
      .sort({ date_debut: 1 }); // Sort by start date

    console.log(`📋 Found ${activities.length} activities (include_archived=${include_archived})`);
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
      message: "Error retrieving activities",
      error: error.message,
    });
  }
};

// Get logged-in organizer's archived activities (past)
exports.getArchivedActivities = async (req, res) => {
  try {
    const userId = req.user.userId;

    const maintenant = new Date();

    // Activities whose end date has passed
    const activities = await Activite.find({
      organisateur_id: userId,
      date_fin: { $lt: maintenant }, // date_fin < now
    })
      .populate(
        "organisateur_id",
        "fullname avatar note_moyenne nombre_avis date_inscription bio pays_origine specialites_activites langues_proposees types_activites",
      )
      .sort({ date_fin: -1 }); // Sort by end date (most recent first)

    res.status(200).json({
      success: true,
      count: activities.length,
      activities,
    });
  } catch (error) {
    console.error("❌ Error fetching archived activities:", error);
    res.status(500).json({
      success: false,
      message: "Error retrieving archived activities",
      error: error.message,
    });
  }
};

// Get ALL global activities grouped by timeline (Upcoming, Ongoing, Past)
exports.getGlobalActivitiesByTimeline = async (req, res) => {
  try {
    const activites = await Activite.find({})
      .populate(
        "organisateur_id",
        "fullname email avatar num_tel note_moyenne nombre_avis date_inscription bio pays_origine specialites_activites langues_proposees types_activites",
      )
      .sort({ date_debut: 1 });

    const now = new Date();
    const upcoming = [];
    const ongoing = [];
    const past = [];

    activites.forEach((act) => {
      const start = act.date_debut || act.dateDebut;
      const end = act.date_fin || act.dateFin;
      let dStart = start ? new Date(start) : null;
      let dEnd = end ? new Date(end) : null;

      if (!dStart && !dEnd) {
        upcoming.push(act);
      } else if (dStart && now < dStart) {
        upcoming.push(act);
      } else if (dStart && dEnd && now >= dStart && now < dEnd) {
        ongoing.push(act);
      } else if (dEnd && now >= dEnd) {
        past.push(act);
      } else {
        // fallback
        past.push(act);
      }
    });

    res.status(200).json({
      success: true,
      data: { upcoming, ongoing, past },
    });
  } catch (error) {
    res.status(500).json({
      message: "Error retrieving global timeline activities",
      error: error.message,
    });
  }
};

// Toggle bookmark on an activity
exports.toggleActivityBookmark = async (req, res) => {
  try {
    const userId = String(req.user.userId || "");
    const { activityId } = req.params;

    if (!userId) {
      return res.status(401).json({ message: "Authentication required" });
    }

    const activity = await Activite.findById(activityId);
    if (!activity) {
      return res.status(404).json({ message: "Activity not found" });
    }

    const bookmarkedBy = Array.isArray(activity.bookmarked_by)
      ? activity.bookmarked_by.map((id) => String(id))
      : [];
    const alreadyBookmarked = bookmarkedBy.includes(userId);

    if (alreadyBookmarked) {
      // Remove bookmark
      activity.bookmarked_by = activity.bookmarked_by.filter(
        (id) => String(id) !== userId,
      );
      activity.bookmarks_count = Math.max(0, activity.bookmarks_count - 1);
    } else {
      // Add bookmark
      activity.bookmarked_by = [...(activity.bookmarked_by || []), userId];
      activity.bookmarks_count = activity.bookmarked_by.length;
    }

    await activity.save();

    return res.status(200).json({
      message: alreadyBookmarked ? "Bookmark removed" : "Bookmark added",
      bookmarked: !alreadyBookmarked,
      bookmarksCount: activity.bookmarks_count,
      activityId: String(activity._id),
    });
  } catch (error) {
    return res.status(500).json({
      message: "Error updating bookmark",
      error: error.message,
    });
  }
};

// Get bookmarked activities for current user
exports.getBookmarkedActivities = async (req, res) => {
  try {
    const userId = req.user.userId;

    const activities = await Activite.find({
      bookmarked_by: userId,
      statut: { $ne: "archived" },
    })
      .sort({ createdAt: -1 })
      .limit(100)
      .populate(
        "organisateur_id",
        "fullname email avatar num_tel note_moyenne nombre_avis date_inscription bio pays_origine specialites_activites langues_proposees types_activites",
      )
      .lean();

    // Add isBookmarked field (always true for bookmarked activities)
    const activitiesWithBookmarkStatus = activities.map((activity) => ({
      ...activity,
      isBookmarked: true,
    }));

    return res.status(200).json({ activities: activitiesWithBookmarkStatus });
  } catch (error) {
    return res.status(500).json({
      message: "Error loading bookmarked activities",
      error: error.message,
    });
  }
};
