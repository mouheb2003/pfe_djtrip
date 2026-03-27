const Lieu = require("../models/lieu");

// Create a new place
exports.createLieu = async (req, res) => {
  try {
    const lieu = new Lieu(req.body);
    await lieu.save();
    res.status(201).json({
      success: true,
      message: "Place created successfully",
      lieu,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error creating place",
      error: error.message,
    });
  }
};

// Get all places
exports.getAllLieux = async (req, res) => {
  try {
    const { categorie, search, topDestination } = req.query;
    const filter = {};

    if (categorie) filter.categorie = categorie;
    if (topDestination === "true") filter.topDestination = true;
    if (search) {
      filter.$or = [
        { titre: { $regex: search, $options: "i" } },
        { sousTitre: { $regex: search, $options: "i" } },
        { description: { $regex: search, $options: "i" } },
      ];
    }

    const lieux = await Lieu.find(filter).populate("activiteLiee");
    res.status(200).json({
      success: true,
      count: lieux.length,
      lieux,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error retrieving places",
      error: error.message,
    });
  }
};

// Get a place by ID
exports.getLieuById = async (req, res) => {
  try {
    const lieu = await Lieu.findById(req.params.id).populate("activiteLiee");
    if (!lieu) {
      return res
        .status(404)
        .json({ success: false, message: "Place not found" });
    }
    res.status(200).json({ success: true, lieu });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error retrieving place",
      error: error.message,
    });
  }
};

// Update a place
exports.updateLieu = async (req, res) => {
  try {
    const lieu = await Lieu.findByIdAndUpdate(req.params.id, req.body, {
      new: true,
      runValidators: true,
    });
    if (!lieu) {
      return res
        .status(404)
        .json({ success: false, message: "Place not found" });
    }
    res.status(200).json({
      success: true,
      message: "Place updated successfully",
      lieu,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error updating place",
      error: error.message,
    });
  }
};

// Delete a place
exports.deleteLieu = async (req, res) => {
  try {
    const lieu = await Lieu.findByIdAndDelete(req.params.id);
    if (!lieu) {
      return res
        .status(404)
        .json({ success: false, message: "Place not found" });
    }
    res.status(200).json({
      success: true,
      message: "Place deleted successfully",
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error deleting place",
      error: error.message,
    });
  }
};
