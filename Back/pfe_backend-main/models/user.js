const mongoose = require("mongoose");

// Schéma de base User (classe abstraite)
const userSchema = new mongoose.Schema(
  {
    fullname: String,
    age: Number,
    num_tel: String,
    email: { type: String, required: true, unique: true },
    mot_de_passe: { type: String, required: true },
    date_inscription: { type: Date, default: Date.now },
    avatar: String,
    bio: String,
    pays_origine: String,
    status: { type: String, enum: ["actif", "inactif"], default: "actif" },
    derniere_connexion: Date,
    notifications_email: { type: Boolean, default: true },
    notifications_sms: { type: Boolean, default: false },
    consentement_donnees: { type: Boolean, default: false },
  },
  {
    discriminatorKey: "userType",
    collection: "users",
  },
);

const User = mongoose.model("User", userSchema);

module.exports = User;
