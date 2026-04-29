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
    suspendReason: String,
    suspendedAt: Date,
    banReason: String,
    bannedAt: Date,
    derniere_connexion: Date,
    notifications_email: { type: Boolean, default: true },
    notifications_sms: { type: Boolean, default: false },
    consentement_donnees: { type: Boolean, default: false },
    // Booking reminder preferences
    reminderPreferences: {
      bookingReminder: {
        type: Boolean,
        default: true,
      },
      reminderTiming: {
        type: String,
        enum: ['1h', '24h', 'both'],
        default: '1h',
      },
    },
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
    // Wallet balance for refunds (in TND)
    wallet_balance: {
      type: Number,
      default: 0,
      min: 0,
    },
    // Favorites (activities)
    favorites: [{ type: mongoose.Schema.Types.ObjectId, ref: "Activite" }],
    // Archived chat partners for the current user
    archivedConversationPartners: [
      { type: mongoose.Schema.Types.ObjectId, ref: "User" },
    ],
    // Deleted chat partners hidden only for the current user
    deletedConversationPartners: [
      { type: mongoose.Schema.Types.ObjectId, ref: "User" },
    ],
    // Muted conversation partners for the current user
    mutedConversationPartners: [
      { type: mongoose.Schema.Types.ObjectId, ref: "User" },
    ],
    // FCM tokens for push notifications (multi-device support)
    fcmTokens: [
      {
        token: String,
        deviceId: String,
        isActive: { type: Boolean, default: true },
        createdAt: { type: Date, default: Date.now },
        lastUsed: { type: Date, default: Date.now },
      },
    ],
    // 🚀 NEW: Activity specialties for organizers
    specialites_activites: [{ type: String }],
    // 🚀 NEW: Languages offered by organizers (also available for all users)
    langues_proposees: [{ type: String }],
    // 🚀 NEW: Onboarding and approval fields
    is_onboarded: { type: Boolean, default: false },
    is_approved: { type: Boolean, default: true }, // Only for organizers
    signup_method: { 
      type: String, 
      enum: ["google", "email", "facebook"], 
      default: "email" 
    },
    profile_completed: { type: Boolean, default: false },
    onboarding_step: { type: Number, default: 0 },
    onboarding_data: { type: mongoose.Schema.Types.Mixed, default: {} },
    // Approval tracking
    submitted_for_approval: { type: Date },
    approved_at: { type: Date },
    approved_by: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
    rejection_reason: { type: String },
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
// 🚀 NEW: Onboarding and approval indexes
userSchema.index({ is_onboarded: 1 });
userSchema.index({ is_approved: 1, userType: 1 });
userSchema.index({ signup_method: 1 });
userSchema.index({ submitted_for_approval: 1 });

module.exports = User;
