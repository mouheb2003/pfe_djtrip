const mongoose = require("mongoose");

// Base User schema (abstract class)
const userSchema = new mongoose.Schema(
  {
    fullname: String,
    age: Number,
    num_tel: String,
    email: { type: String, required: true, unique: true },
    mot_de_passe: {
      type: String,
      required: function () {
        // Password is required only for classic email/password accounts.
        return !this.googleId && !this.facebookId;
      },
    },
    date_inscription: { type: Date, default: Date.now },
    avatar: String,
    bio: String,
    pays_origine: String,
    // 🚀 NEW: Language and interests fields
    langue_preferee: { type: String, default: "English" }, // Default to English
    centres_interet: [{ type: String }], // Array of interests
    // 🚀 NEW: Phone country field for validation
    pays_telephone: { type: String, default: "France" }, // Country for phone validation
    // 🚀 NEW: Privacy settings fields
    profileVisibility: { type: Boolean, default: true },
    showOnlineStatus: { type: Boolean, default: true },
    showLastSeen: { type: Boolean, default: false },
    allowDirectMessages: { type: Boolean, default: true },
    showPhone: { type: Boolean, default: false },
    showEmail: { type: Boolean, default: false },
    allowLocationSharing: { type: Boolean, default: false },
    allowDataAnalytics: { type: Boolean, default: false },
    // 🚀 NEW: Advanced privacy settings
    discoverability: { type: Boolean, default: true },
    searchIndexing: { type: Boolean, default: true },
    activityTracking: { type: Boolean, default: false },
    personalizedAds: { type: Boolean, default: false },
    thirdPartySharing: { type: Boolean, default: false },
    cookiesEnabled: { type: Boolean, default: true },
    biometricAuth: { type: Boolean, default: false },
    twoFactorAuth: { type: Boolean, default: false },
    // 🚀 NEW: Additional privacy data
    profileViews: { type: Number, default: 0 },
    lastActive: { type: Date },
    dataShared: { type: Boolean, default: false },
    locationHistory: [{ type: String }], // Array of location data
    blockedUsers: [{ type: mongoose.Schema.Types.ObjectId, ref: "User" }],
    isOnline: { type: Boolean, default: false },
    accountStatus: {
      type: String,
      enum: ["active", "suspended", "banned", "inactive"],
      default: "active",
    },
    suspendedUntil: Date,
    derniere_connexion: Date,
    notifications_email: { type: Boolean, default: true },
    notifications_sms: { type: Boolean, default: false },
    consentement_donnees: { type: Boolean, default: false },
    // Email verification fields
    emailVerified: { type: Boolean, default: false },
    verificationCode: String,
    verificationCodeExpiry: Date,
    // Social authentication IDs
    googleId: {
      type: String,
      unique: true,
      sparse: true,
    },
    facebookId: {
      type: String,
      unique: true,
      sparse: true,
    },
    // Password reset fields
    passwordResetCode: String,
    passwordResetCodeExpiry: Date,
    // Brute force protection
    loginAttempts: { type: Number, default: 0 },
    lockUntil: Date,
    // Token versioning (used to invalidate refresh tokens on logout)
    tokenVersion: { type: Number, default: 0 },
    // Favorites (activities)
    favorites: [{ type: mongoose.Schema.Types.ObjectId, ref: "Activite" }],
    // 🚀 NEW: Activity specialties for organizers
    specialites_activites: [{ type: String }],
  },
  {
    discriminatorKey: "userType",
    collection: "users",
  },
);

const User = mongoose.model("User", userSchema);

// ─── Indexes for Performance ───────────────────────────────────────
userSchema.index({ accountStatus: 1 });
userSchema.index({ userType: 1 });
userSchema.index({ createdAt: -1 });
userSchema.index({ favorites: 1 });
userSchema.index({ accountStatus: 1, userType: 1 });
userSchema.index({ googleId: 1 }, { sparse: true });
userSchema.index({ facebookId: 1 }, { sparse: true });

module.exports = User;
