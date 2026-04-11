const mongoose = require("mongoose");
const User = require("./user");

// Specific schema for Organisator (Simple activity organizer)
const organisatorSchema = new mongoose.Schema({
  // Link to the base user (inheritance)
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "User",
  },
  // Offered activity types (e.g. "Water Sports", "Hiking", "Cultural Visits", etc.)
  types_activites: {
    type: [String],
    default: [],
    enum: [
      "Water Sports",
      "Hiking",
      "Climbing",
      "Cycling",
      "Cultural Visits",
      "Gastronomy",
      "Adventure",
      "Extreme Sports",
      "Courses and Workshops",
      "Relaxation and Wellness",
      "Photography",
      "Nature Observation",
      "Winter Sports",
      "Water Activities",
      "Excursions",
      "Other",
    ],
  },
  // List of activities created by this organizer (references to activity IDs)
  liste_activites: {
    type: [mongoose.Schema.Types.ObjectId],
    ref: "Activite",
    default: [],
  },
  note_moyenne: {
    type: Number,
    default: 0,
    min: 0,
    max: 5,
  },
  nombre_avis: {
    type: Number,
    default: 0,
  },
  // Languages spoken for activities
  langues_proposees: {
    type: [String],
    default: [],
  },
  // Description of the organizer and their services
  description: {
    type: String,
    maxlength: 1000,
  },
});

// Using the discriminator to inherit from User
const Organisator = User.discriminator("Organisator", organisatorSchema);

module.exports = Organisator;
