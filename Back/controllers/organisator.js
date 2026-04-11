const Organisator = require("../models/organisator");

// Complete the organizer profile (after registration via user/signup)
exports.completeProfileOrganisator = async (req, res) => {
  try {
    const userId = req.user.userId; // Retrieved from the JWT token
    const {
      age,
      num_tel,
      bio,
      pays_origine,
      avatar,
      types_activites,
      langues_proposees,
      description,
      notifications_email,
      notifications_sms,
      consentement_donnees,
    } = req.body;

    // Find the organizer by ID
    const organisator = await Organisator.findById(userId);
    if (!organisator) {
      return res.status(404).json({ message: "Organizer not found" });
    }

    // Verify this is indeed an organizer
    if (organisator.userType !== "Organisator") {
      return res.status(403).json({ message: "This user is not an organizer" });
    }

    // Update general user attributes
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

    // Update organizer-specific attributes
    if (types_activites !== undefined)
      organisator.types_activites = types_activites;
    if (langues_proposees !== undefined)
      organisator.langues_proposees = langues_proposees;
    if (description !== undefined) organisator.description = description;

    await organisator.save();

    // Return the organizer without the password
    const organisatorResponse = organisator.toObject();
    delete organisatorResponse.mot_de_passe;

    res.status(200).json({
      message: "Organizer profile completed successfully",
      organisator: organisatorResponse,
    });
  } catch (error) {
    res.status(500).json({
      message: "Error completing organizer profile",
      error: error.message,
    });
  }
};

// Get all organizers
exports.getAllOrganisators = async (req, res) => {
  try {
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit) || 20));
    const skip = (page - 1) * limit;

    const [organisators, total] = await Promise.all([
      Organisator.find().select("-mot_de_passe").skip(skip).limit(limit).lean(),
      Organisator.countDocuments(),
    ]);

    res.status(200).json({
      organisators,
      count: organisators.length,
      total,
      page,
      pages: Math.ceil(total / limit),
    });
  } catch (error) {
    res
      .status(500)
      .json({ message: "Error retrieving organizers", error: error.message });
  }
};

// Get an organizer by ID
exports.getOrganisatorById = async (req, res) => {
  try {
    const organisator = await Organisator.findById(req.params.id).select(
      "-mot_de_passe",
    );
    if (!organisator) {
      return res.status(404).json({ message: "Organizer not found" });
    }
    res.status(200).json({ organisator });
  } catch (error) {
    res.status(500).json({
      message: "Error retrieving organizer",
      error: error.message,
    });
  }
};

// Update an organizer
exports.updateOrganisator = async (req, res) => {
  try {
    const {
      fullname,
      age,
      num_tel,
      email,
      types_activites,
      langues_proposees,
      description,
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
    if (types_activites) updateData.types_activites = types_activites;
    if (langues_proposees) updateData.langues_proposees = langues_proposees;
    if (description) updateData.description = description;
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
    )
      .select("-mot_de_passe")
      .populate(
        "liste_activites",
        "titre type_activite lieu prix note_moyenne",
      );

    if (!organisator) {
      return res.status(404).json({ message: "Organizer not found" });
    }

    res
      .status(200)
      .json({ message: "Organizer updated successfully", organisator });
  } catch (error) {
    res.status(500).json({
      message: "Error updating organizer",
      error: error.message,
    });
  }
};

// Delete an organizer
exports.deleteOrganisator = async (req, res) => {
  try {
    const organisator = await Organisator.findByIdAndDelete(req.params.id);
    if (!organisator) {
      return res.status(404).json({ message: "Organizer not found" });
    }
    res.status(200).json({ message: "Organizer deleted successfully" });
  } catch (error) {
    res.status(500).json({
      message: "Error deleting the organizer",
      error: error.message,
    });
  }
};
