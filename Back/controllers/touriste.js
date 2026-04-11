const Touriste = require("../models/touriste");

// Complete the tourist profile (after registration via user/signup)
exports.completeProfileTouriste = async (req, res) => {
  try {
    const userId = req.user.userId; // Retrieved from the JWT token
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

    // Find the tourist by ID
    const touriste = await Touriste.findById(userId);
    if (!touriste) {
      return res.status(404).json({ message: "Tourist not found" });
    }

    // Verify this is indeed a tourist
    if (touriste.userType !== "Touriste") {
      return res.status(403).json({ message: "This user is not a tourist" });
    }

    // Update general user attributes
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

    // Update tourist-specific attributes
    if (centres_interet !== undefined)
      touriste.centres_interet = centres_interet;
    if (langue_preferee !== undefined)
      touriste.langue_preferee = langue_preferee;

    await touriste.save();

    // Return the tourist without the password
    const touristeResponse = touriste.toObject();
    delete touristeResponse.mot_de_passe;

    res.status(200).json({
      message: "Tourist profile completed successfully",
      touriste: touristeResponse,
    });
  } catch (error) {
    res.status(500).json({
      message: "Error completing tourist profile",
      error: error.message,
    });
  }
};

// Get all tourists
exports.getAllTouristes = async (req, res) => {
  try {
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit) || 20));
    const skip = (page - 1) * limit;

    const [touristes, total] = await Promise.all([
      Touriste.find().select("-mot_de_passe").skip(skip).limit(limit).lean(),
      Touriste.countDocuments(),
    ]);

    res.status(200).json({
      touristes,
      count: touristes.length,
      total,
      page,
      pages: Math.ceil(total / limit),
    });
  } catch (error) {
    res
      .status(500)
      .json({ message: "Error retrieving tourists", error: error.message });
  }
};

// Get a tourist by ID
exports.getTouristeById = async (req, res) => {
  try {
    const touriste = await Touriste.findById(req.params.id).select(
      "-mot_de_passe",
    );
    if (!touriste) {
      return res.status(404).json({ message: "Tourist not found" });
    }
    res.status(200).json({ touriste });
  } catch (error) {
    res.status(500).json({
      message: "Error retrieving tourist",
      error: error.message,
    });
  }
};

// Update a tourist
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
      return res.status(404).json({ message: "Tourist not found" });
    }

    res.status(200).json({ message: "Tourist updated successfully", touriste });
  } catch (error) {
    res.status(500).json({
      message: "Error updating tourist",
      error: error.message,
    });
  }
};

// Delete a tourist
exports.deleteTouriste = async (req, res) => {
  try {
    const touriste = await Touriste.findByIdAndDelete(req.params.id);
    if (!touriste) {
      return res.status(404).json({ message: "Tourist not found" });
    }
    res.status(200).json({ message: "Tourist deleted successfully" });
  } catch (error) {
    res.status(500).json({
      message: "Error deleting the tourist",
      error: error.message,
    });
  }
};

// Update interests
exports.updateCentresInteret = async (req, res) => {
  try {
    const { centres_interet } = req.body;

    const touriste = await Touriste.findByIdAndUpdate(
      req.params.id,
      { centres_interet },
      { new: true },
    ).select("-mot_de_passe");

    if (!touriste) {
      return res.status(404).json({ message: "Tourist not found" });
    }

    res
      .status(200)
      .json({ message: "Interests updated successfully", touriste });
  } catch (error) {
    res.status(500).json({
      message: "Error updating interests",
      error: error.message,
    });
  }
};

// Update preferred language
exports.updateLanguePreferee = async (req, res) => {
  try {
    const { langue_preferee } = req.body;

    const touriste = await Touriste.findByIdAndUpdate(
      req.params.id,
      { langue_preferee },
      { new: true },
    ).select("-mot_de_passe");

    if (!touriste) {
      return res.status(404).json({ message: "Tourist not found" });
    }

    res
      .status(200)
      .json({ message: "Preferred language updated successfully", touriste });
  } catch (error) {
    res.status(500).json({
      message: "Error updating preferred language",
      error: error.message,
    });
  }
};
