const User = require("../models/user");
const Touriste = require("../models/touriste");
const Organisator = require("../models/organisator");
const Admin = require("../models/admin");
const bcrypt = require("bcryptjs");
const emailService = require("./email");

/**
 * Service for managing user operations
 */
class UserService {
  /**
   * Retrieves a user by their ID
   * @param {String} userId - User ID
   * @param {Boolean} includePassword - Include password (default: false)
   * @returns {Promise<Object>} User
   */
  static async getUserById(userId, includePassword = false) {
    const query = User.findById(userId);

    if (!includePassword) {
      query.select("-mot_de_passe");
    }

    const user = await query;

    if (!user) {
      throw new Error("User not found");
    }

    return user;
  }

  /**
   * Retrieves all users
   * @returns {Promise<Array>} List of users
   */
  static async getAllUsers() {
    const users = await User.find().select("-mot_de_passe");
    return users;
  }

  /**
   * Retrieves a user by email
   * @param {String} email - User email
   * @param {Boolean} includePassword - Include password (default: false)
   * @returns {Promise<Object>} User
   */
  static async getUserByEmail(email, includePassword = false) {
    const query = User.findOne({ email });

    if (!includePassword) {
      query.select("-mot_de_passe");
    }

    const user = await query;

    if (!user) {
      throw new Error("User not found");
    }

    return user;
  }

  /**
   * Updates a user's profile
   * @param {String} userId - User ID
   * @param {Object} updateData - Data to update
   * @returns {Promise<Object>} Updated user
   */
  static async updateProfile(userId, updateData) {
    // Fields that cannot be updated via this method
    const restrictedFields = [
      "mot_de_passe",
      "_id",
      "email",
      "userType",
      "date_inscription",
      "verificationCode",
      "verificationCodeExpiry",
      "passwordResetCode",
      "passwordResetCodeExpiry",
      "isOnline",
      "accountStatus",
      "derniere_connexion",
    ];

    // 🚀 NEW: Auto-normalize data before saving
    const normalizedData = { ...updateData };

    // Auto-normalize language preference
    if (normalizedData.langue_preferee) {
      normalizedData.langue_preferee = this._normalizeLanguage(
        normalizedData.langue_preferee,
      );
    }

    // Auto-normalize country
    if (normalizedData.pays_origine) {
      normalizedData.pays_origine = this._normalizeCountry(
        normalizedData.pays_origine,
      );
    }

    // 🚀 NEW: Validate and format phone number
    if (normalizedData.num_tel) {
      normalizedData.num_tel = this._normalizePhoneInput(
        normalizedData.num_tel,
        normalizedData.pays_telephone ||
          normalizedData.pays_origine ||
          "France",
      );

      // Skip validation if phone is just a country code or too short
      const cleanPhone = normalizedData.num_tel.replace(/\D/g, "");
      const countryCodes = {
        "+33": "France",
        "+216": "Tunisie",
        "+213": "Algérie",
        "+218": "Libye",
        "+212": "Maroc",
        "+39": "Italie",
        "+49": "Allemagne",
        "+44": "Royaume-Uni",
        "+34": "Espagne",
        "+32": "Belgique",
        "+41": "Suisse",
        "+1": "Canada",
        "+20": "Égypte",
        "+7": "Russie",
        "+966": "Arabie Saoudite",
        "+971": "Émirats Arabes Unis",
      };

      // Check if phone is just a country code (incomplete)
      const isJustCountryCode = Object.keys(countryCodes).some(code => 
        cleanPhone === code.replace('+', '')
      );

      if (!isJustCountryCode && cleanPhone.length >= 8) {
        const phoneValidation = this._validateAndFormatPhone(
          normalizedData.num_tel,
          normalizedData.pays_telephone ||
            normalizedData.pays_origine ||
            "France",
        );

        if (!phoneValidation.valid) {
          throw new Error(phoneValidation.error);
        }

        normalizedData.num_tel = phoneValidation.phone;
        normalizedData.pays_telephone = phoneValidation.country;
        console.log(
          `📱 Phone formatted: ${phoneValidation.phone} (${phoneValidation.country})`,
        );
      } else {
        // Phone is incomplete or just country code - skip validation but keep the value
        console.log(`📱 Phone is incomplete (${normalizedData.num_tel}), skipping validation`);
      }
    }

    // Auto-validate interests array
    if (typeof normalizedData.centres_interet !== "undefined") {
      normalizedData.centres_interet = this._coerceStringArray(
        normalizedData.centres_interet,
      )
        .filter((interest) => interest && interest.trim().length > 0)
        .map((interest) => interest.trim())
        .filter((interest, index, arr) => arr.indexOf(interest) === index); // Remove duplicates
    }

    // 🚀 NEW: Auto-validate specialties array
    if (typeof normalizedData.specialites_activites !== "undefined") {
      normalizedData.specialites_activites = this._coerceStringArray(
        normalizedData.specialites_activites,
      )
        .filter((specialty) => specialty && specialty.trim().length > 0)
        .map((specialty) => specialty.trim())
        .filter((specialty, index, arr) => arr.indexOf(specialty) === index); // Remove duplicates
      console.log(
        `🎯 Specialties validated: ${normalizedData.specialites_activites.length} items`,
      );
    }

    // 🚀 NEW: Auto-validate spoken languages array (organizer field)
    if (typeof normalizedData.langues_proposees !== "undefined") {
      normalizedData.langues_proposees = this._coerceStringArray(
        normalizedData.langues_proposees,
      )
        .filter((lang) => lang && lang.trim().length > 0)
        .map((lang) => lang.trim())
        .filter((lang, index, arr) => arr.indexOf(lang) === index);
      console.log(
        `🌐 Spoken languages validated: ${normalizedData.langues_proposees.length} items`,
      );
    }

    // Remove restricted fields from update data
    const sanitizedData = { ...normalizedData };
    restrictedFields.forEach((field) => delete sanitizedData[field]);

    // Find and update the actual document instance so discriminator validation stays intact
    const user = await User.findById(userId);

    if (!user) {
      throw new Error("User not found");
    }

    Object.assign(user, sanitizedData);
    await user.save();

    const savedUser = await User.findById(userId).select("-mot_de_passe");

    if (!savedUser) {
      throw new Error("User not found");
    }

    console.log("✅ User profile updated:", userId);
    return savedUser;
  }

  // 🚀 NEW: Helper methods for normalization
  static _normalizeLanguage(raw) {
    const v = raw.trim().toLowerCase();
    if (v === "français" || v === "francais" || v === "french" || v === "fr") {
      return "French";
    }
    if (v === "english" || v === "en" || v === "anglais") return "English";
    if (v === "arabic" || v === "ar" || v === "العربية") return "العربية";
    if (v === "german" || v === "deutsch" || v === "de" || v === "allemand") {
      return "Deutsch";
    }
    return raw;
  }

  static _normalizeCountry(raw) {
    const v = raw.trim().toLowerCase();
    if (v === "tunisia" || v === "tunisie") return "Tunisie";
    if (v === "morocco" || v === "maroc") return "Maroc";
    if (v === "germany" || v === "allemagne") return "Allemagne";
    if (v === "united kingdom" || v === "uk" || v === "royaume-uni") {
      return "Royaume-Uni";
    }
    if (v === "france") return "France";
    return raw;
  }

  // 🚀 NEW: Phone number validation and formatting by country - Top 15 countries visiting Tunisia
  static _validateAndFormatPhone(phone, country) {
    if (!phone || !phone.trim()) {
      return { valid: false, error: "Phone number is required" };
    }

    const cleanPhone = phone.replace(/\s+/g, "").replace(/[^\d+]/g, "");

    // Normalize country name to handle both English and French
    const normalizedCountry = this._normalizeCountryName(country);

    const countryPhoneFormats = {
      France: {
        code: "+33",
        pattern: /^(\+33|0)[1-9](\d{2}){4}$/,
        format: (phone) => {
          const digits = phone.replace(/\D/g, "");
          if (digits.startsWith("33")) {
            return "+33" + digits.substring(2);
          }
          if (digits.startsWith("0")) {
            return "+33" + digits.substring(1);
          }
          return "+33" + digits;
        },
      },
      Tunisie: {
        code: "+216",
        pattern: /^(\+216|0)[2-9]\d{7}$/,
        format: (phone) => {
          const digits = phone.replace(/\D/g, "");
          if (digits.startsWith("216")) {
            return "+216" + digits.substring(3);
          }
          if (digits.startsWith("0")) {
            return "+216" + digits.substring(1);
          }
          return "+216" + digits;
        },
      },
      Algérie: {
        code: "+213",
        pattern: /^(\+213|0)[5-9]\d{8}$/,
        format: (phone) => {
          const digits = phone.replace(/\D/g, "");
          if (digits.startsWith("213")) {
            return "+213" + digits.substring(3);
          }
          if (digits.startsWith("0")) {
            return "+213" + digits.substring(1);
          }
          return "+213" + digits;
        },
      },
      Libye: {
        code: "+218",
        pattern: /^(\+218|0)[2-9]\d{8}$/,
        format: (phone) => {
          const digits = phone.replace(/\D/g, "");
          if (digits.startsWith("218")) {
            return "+218" + digits.substring(3);
          }
          if (digits.startsWith("0")) {
            return "+218" + digits.substring(1);
          }
          return "+218" + digits;
        },
      },
      Maroc: {
        code: "+212",
        pattern: /^(\+212|0)[5-9]\d{8}$/,
        format: (phone) => {
          const digits = phone.replace(/\D/g, "");
          if (digits.startsWith("212")) {
            return "+212" + digits.substring(3);
          }
          if (digits.startsWith("0")) {
            return "+212" + digits.substring(1);
          }
          return "+212" + digits;
        },
      },
      Italie: {
        code: "+39",
        pattern: /^(\+39|0)[3]\d{8,9}$/,
        format: (phone) => {
          const digits = phone.replace(/\D/g, "");
          if (digits.startsWith("39")) {
            return "+39" + digits.substring(2);
          }
          if (digits.startsWith("0")) {
            return "+39" + digits.substring(1);
          }
          return "+39" + digits;
        },
      },
      Allemagne: {
        code: "+49",
        pattern: /^(\+49|0)[1-9]\d{1,14}$/,
        format: (phone) => {
          const digits = phone.replace(/\D/g, "");
          if (digits.startsWith("49")) {
            return "+49" + digits.substring(2);
          }
          if (digits.startsWith("0")) {
            return "+49" + digits.substring(1);
          }
          return "+49" + digits;
        },
      },
      "Royaume-Uni": {
        code: "+44",
        pattern: /^(\+44|0)[1-9]\d{9,10}$/,
        format: (phone) => {
          const digits = phone.replace(/\D/g, "");
          if (digits.startsWith("44")) {
            return "+44" + digits.substring(2);
          }
          if (digits.startsWith("0")) {
            return "+44" + digits.substring(1);
          }
          return "+44" + digits;
        },
      },
      Espagne: {
        code: "+34",
        pattern: /^(\+34|0)[6-9]\d{8}$/,
        format: (phone) => {
          const digits = phone.replace(/\D/g, "");
          if (digits.startsWith("34")) {
            return "+34" + digits.substring(2);
          }
          if (digits.startsWith("0")) {
            return "+34" + digits.substring(1);
          }
          return "+34" + digits;
        },
      },
      Belgique: {
        code: "+32",
        pattern: /^(\+32|0)[4-9]\d{7,8}$/,
        format: (phone) => {
          const digits = phone.replace(/\D/g, "");
          if (digits.startsWith("32")) {
            return "+32" + digits.substring(2);
          }
          if (digits.startsWith("0")) {
            return "+32" + digits.substring(1);
          }
          return "+32" + digits;
        },
      },
      Suisse: {
        code: "+41",
        pattern: /^(\+41|0)[7-9]\d{8}$/,
        format: (phone) => {
          const digits = phone.replace(/\D/g, "");
          if (digits.startsWith("41")) {
            return "+41" + digits.substring(2);
          }
          if (digits.startsWith("0")) {
            return "+41" + digits.substring(1);
          }
          return "+41" + digits;
        },
      },
      Canada: {
        code: "+1",
        pattern: /^(\+1)[2-9]\d{2}[2-9]\d{6}$/,
        format: (phone) => {
          const digits = phone.replace(/\D/g, "");
          if (digits.startsWith("1")) {
            return "+1" + digits.substring(1);
          }
          return "+1" + digits;
        },
      },
      Égypte: {
        code: "+20",
        pattern: /^(\+20|0)[1-9]\d{8,9}$/,
        format: (phone) => {
          const digits = phone.replace(/\D/g, "");
          if (digits.startsWith("20")) {
            return "+20" + digits.substring(2);
          }
          if (digits.startsWith("0")) {
            return "+20" + digits.substring(1);
          }
          return "+20" + digits;
        },
      },
      Russie: {
        code: "+7",
        pattern: /^(\+7|8)[9]\d{9}$/,
        format: (phone) => {
          const digits = phone.replace(/\D/g, "");
          if (digits.startsWith("7")) {
            return "+7" + digits.substring(1);
          }
          if (digits.startsWith("8")) {
            return "+7" + digits.substring(1);
          }
          return "+7" + digits;
        },
      },
      "Arabie Saoudite": {
        code: "+966",
        pattern: /^(\+966|0)[5]\d{8}$/,
        format: (phone) => {
          const digits = phone.replace(/\D/g, "");
          if (digits.startsWith("966")) {
            return "+966" + digits.substring(3);
          }
          if (digits.startsWith("0")) {
            return "+966" + digits.substring(1);
          }
          return "+966" + digits;
        },
      },
      "Émirats Arabes Unis": {
        code: "+971",
        pattern: /^(\+971|0)[5]\d{8}$/,
        format: (phone) => {
          const digits = phone.replace(/\D/g, "");
          if (digits.startsWith("971")) {
            return "+971" + digits.substring(3);
          }
          if (digits.startsWith("0")) {
            return "+971" + digits.substring(1);
          }
          return "+971" + digits;
        },
      },
    };

    const format = countryPhoneFormats[normalizedCountry];
    if (!format) {
      return { valid: false, error: "Unsupported country" };
    }

    if (!format.pattern.test(cleanPhone)) {
      return {
        valid: false,
        error: `Invalid ${country} phone number format. Expected format: ${format.code} followed by valid number`,
      };
    }

    const formattedPhone = format.format(cleanPhone);
    return {
      valid: true,
      phone: formattedPhone,
      country: country,
      code: format.code,
    };
  }

  static _normalizePhoneInput(phone, country) {
    const cleaned = String(phone || "")
      .replace(/\s+/g, "")
      .replace(/[^\d+]/g, "");

    const countryCodes = {
      France: "+33",
      Tunisie: "+216",
      Algérie: "+213",
      Libye: "+218",
      Maroc: "+212",
      Italie: "+39",
      Allemagne: "+49",
      "Royaume-Uni": "+44",
      Espagne: "+34",
      Belgique: "+32",
      Suisse: "+41",
      Canada: "+1",
      Égypte: "+20",
      Russie: "+7",
      "Arabie Saoudite": "+966",
      "Émirats Arabes Unis": "+971",
    };

    const code = countryCodes[country];
    if (code && cleaned.startsWith(code) && cleaned[code.length] === "0") {
      return `${code}${cleaned.slice(code.length + 1)}`;
    }

    return cleaned;
  }

  static _normalizeCountryName(country) {
    if (!country) return "France"; // Default to France if no country provided

    const countryAliases = {
      // English -> French mappings
      "Tunisia": "Tunisie",
      "tunisia": "Tunisie",
      "Tunisie": "Tunisie",
      "tunisie": "Tunisie",
      
      "Algeria": "Algérie",
      "algeria": "Algérie",
      "Algérie": "Algérie",
      "algérie": "Algérie",
      
      "Libya": "Libye",
      "libya": "Libye",
      "Libye": "Libye",
      "libye": "Libye",
      
      "Morocco": "Maroc",
      "morocco": "Maroc",
      "Maroc": "Maroc",
      "maroc": "Maroc",
      
      "Italy": "Italie",
      "italy": "Italie",
      "Italie": "Italie",
      "italie": "Italie",
      
      "Germany": "Allemagne",
      "germany": "Allemagne",
      "Allemagne": "Allemagne",
      "allemagne": "Allemagne",
      
      "United Kingdom": "Royaume-Uni",
      "united kingdom": "Royaume-Uni",
      "UK": "Royaume-Uni",
      "uk": "Royaume-Uni",
      "Royaume-Uni": "Royaume-Uni",
      
      "Spain": "Espagne",
      "spain": "Espagne",
      "Espagne": "Espagne",
      "espagne": "Espagne",
      
      "Belgium": "Belgique",
      "belgium": "Belgique",
      "Belgique": "Belgique",
      "belgique": "Belgique",
      
      "Switzerland": "Suisse",
      "switzerland": "Suisse",
      "Suisse": "Suisse",
      "suisse": "Suisse",
      
      "Canada": "Canada",
      "canada": "Canada",
      
      "Egypt": "Égypte",
      "egypt": "Égypte",
      "Égypte": "Égypte",
      "égypte": "Égypte",
      
      "Russia": "Russie",
      "russia": "Russie",
      "Russie": "Russie",
      "russie": "Russie",
      
      "Saudi Arabia": "Arabie Saoudite",
      "saudi arabia": "Arabie Saoudite",
      "Arabie Saoudite": "Arabie Saoudite",
      
      "UAE": "Émirats Arabes Unis",
      "uae": "Émirats Arabes Unis",
      "United Arab Emirates": "Émirats Arabes Unis",
      "Émirats Arabes Unis": "Émirats Arabes Unis",
      
      "France": "France",
      "france": "France",
    };

    // Try exact match first
    if (countryAliases[country]) {
      return countryAliases[country];
    }

    // Try case-insensitive match
    const lowerCountry = country.toLowerCase();
    for (const [key, value] of Object.entries(countryAliases)) {
      if (key.toLowerCase() === lowerCountry) {
        return value;
      }
    }

    // Return original if no match found
    return country;
  }

  static _coerceStringArray(value) {
    if (Array.isArray(value)) {
      return value.map((item) => String(item));
    }

    if (typeof value === "string") {
      const trimmed = value.trim();
      if (!trimmed) {
        return [];
      }

      try {
        const parsed = JSON.parse(trimmed);
        if (Array.isArray(parsed)) {
          return parsed.map((item) => String(item));
        }
      } catch (err) {
        // Fall through to a single-item array.
      }

      return [trimmed];
    }

    if (value == null) {
      return [];
    }

    return [String(value)];
  }

  /**
   * Updates user privacy settings
   * @param {String} userId - User ID
   * @param {Object} privacyData - Privacy settings to update
   * @returns {Promise<Object>} Updated user
   */
  static async updatePrivacySettings(userId, privacyData) {
    const user = await User.findByIdAndUpdate(
      userId,
      { $set: privacyData },
      { new: true, runValidators: true },
    ).select("-mot_de_passe");

    if (!user) {
      throw new Error("User not found");
    }

    console.log("✅ Privacy settings updated:", userId);
    return user;
  }

  /**
   * Updates user advanced privacy settings
   * @param {String} userId - User ID
   * @param {Object} advancedData - Advanced settings to update
   * @returns {Promise<Object>} Updated user
   */
  static async updateAdvancedSettings(userId, advancedData) {
    const user = await User.findByIdAndUpdate(
      userId,
      { $set: advancedData },
      { new: true, runValidators: true },
    ).select("-mot_de_passe");

    if (!user) {
      throw new Error("User not found");
    }

    console.log("✅ Advanced settings updated:", userId);
    return user;
  }

  /**
   * Updates a user's password
   * @param {String} userId - User ID
   * @param {String} currentPassword - Current password
   * @param {String} newPassword - New password
   * @returns {Promise<Boolean>} Operation success
   */
  static async updatePassword(userId, currentPassword, newPassword) {
    // Get user with password
    const user = await User.findById(userId);

    if (!user) {
      throw new Error("User not found");
    }

    // Verify current password
    const isPasswordValid = await bcrypt.compare(
      currentPassword,
      user.mot_de_passe,
    );

    if (!isPasswordValid) {
      throw new Error("Current password is incorrect");
    }

    // Hash new password
    const hashedPassword = await bcrypt.hash(newPassword, 10);

    // Update password
    user.mot_de_passe = hashedPassword;
    await user.save();

    console.log("✅ User password updated:", userId);
    return true;
  }

  /**
   * Updates account status (active, suspended, banned, inactive)
   * @param {String} userId - User ID
   * @param {String} accountStatus - New status (active/suspended/banned/inactive)
   * @returns {Promise<Object>} Updated user
   */
  static async updateAccountStatus(userId, accountStatus) {
    if (
      !["active", "suspended", "banned", "inactive"].includes(accountStatus)
    ) {
      throw new Error(
        'Account status must be either "active", "suspended", "banned", or "inactive"',
      );
    }

    const user = await User.findByIdAndUpdate(
      userId,
      { accountStatus },
      { new: true },
    ).select("-mot_de_passe");

    if (!user) {
      throw new Error("User not found");
    }

    console.log(`✅ User account status updated to ${accountStatus}:`, userId);
    return user;
  }

  /**
   * Updates last connection and online status of a user
   * @param {String} userId - User ID
   * @returns {Promise<Object>} Updated user
   */
  static async updateLastConnection(userId) {
    const user = await User.findByIdAndUpdate(
      userId,
      {
        derniere_connexion: new Date(),
        isOnline: true,
      },
      { new: true },
    ).select("-mot_de_passe");

    if (!user) {
      throw new Error("User not found");
    }

    return user;
  }

  /**
   * Updates online status
   * @param {String} userId - User ID
   * @param {Boolean} isOnline - Online state
   * @returns {Promise<Object>} Updated user
   */
  static async updateOnlineStatus(userId, isOnline) {
    const user = await User.findByIdAndUpdate(
      userId,
      { isOnline: isOnline },
      { new: true },
    ).select("-mot_de_passe");

    if (!user) {
      throw new Error("User not found");
    }

    console.log(
      `🔵 User online status updated: ${userId} - ${isOnline ? "Online" : "Offline"}`,
    );
    return user;
  }

  /**
   * Checks and updates account status based on activity
   * NOTE: This method no longer automatically changes accountStatus
   * It now serves only for monitoring purposes
   * @param {String} userId - User ID
   * @returns {Promise<Object>} Updated user
   */
  static async updateAccountStatusBasedOnActivity(userId) {
    const user = await User.findById(userId);

    if (!user) {
      throw new Error("User not found");
    }

    // Log for monitoring purposes only
    if (user.derniere_connexion) {
      const now = new Date();
      const daysSinceLastConnection = Math.floor(
        (now - user.derniere_connexion) / (1000 * 60 * 60 * 24),
      );

      if (daysSinceLastConnection > 90) {
        console.log(
          `ℹ️ User inactive for ${daysSinceLastConnection} days:`,
          userId,
        );
      }
    }

    return user;
  }

  /**
   * Creates a new user (used for registration)
   * @param {Object} userData - User data
   * @returns {Promise<Object>} Created user
   */
  static async createUser(userData) {
    const { fullname, email, mot_de_passe, userType, ...additionalData } =
      userData;

    // Validate required fields
    if (!fullname || !email || !mot_de_passe) {
      throw new Error("Fullname, email, and password are required");
    }

    // Validate userType
    if (!userType || !["Touriste", "Organisator", "Admin"].includes(userType)) {
      throw new Error(
        'userType must be either "Touriste", "Organisator", or "Admin"',
      );
    }

    // Check if user already exists
    const existingUser = await User.findOne({ email });
    if (existingUser) {
      throw new Error("Email already registered");
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(mot_de_passe, 10);

    // Generate verification code
    const verificationCode = emailService.generateVerificationCode();
    const verificationCodeExpiry = new Date(Date.now() + 15 * 60 * 1000); // 15 minutes

    // Prepare base data
    const baseData = {
      fullname,
      email,
      mot_de_passe: hashedPassword,
      date_inscription: new Date(),
      accountStatus: "active",
      isOnline: false,
      emailVerified: false,
      verificationCode,
      verificationCodeExpiry,
      ...additionalData,
    };

    // Create user based on userType
    let user;
    if (userType === "Touriste") {
      user = new Touriste(baseData);
    } else if (userType === "Organisator") {
      user = new Organisator(baseData);
    } else if (userType === "Admin") {
      user = new Admin(baseData);
    }

    await user.save();

    // Send verification email asynchronously (don't block response)
    emailService
      .sendVerificationEmail(email, verificationCode, fullname)
      .then((emailResult) => {
        console.log(
          "📧 Verification email sent:",
          user._id,
          "Success:",
          emailResult.success,
        );
      })
      .catch((error) => {
        console.error("❌ Error sending verification email:", error.message);
      });

    // Log verification code in development mode
    if (process.env.NODE_ENV === "development" || !process.env.EMAIL_USER) {
      console.log("\n========================================");
      console.log("📧 EMAIL VERIFICATION CODE (DEV MODE)");
      console.log("========================================");
      console.log("User:", fullname);
      console.log("Email:", email);
      console.log("Code:", verificationCode);
      console.log("Expires in: 15 minutes");
      console.log("========================================\n");
    }

    console.log("✅ New user created:", user._id);
    return user;
  }

  /**
   * Verifies the email verification code
   * @param {String} email - User email
   * @param {String} code - Verification code
   * @returns {Promise<Object>} Verified user
   */
  static async verifyEmail(email, code) {
    const user = await User.findOne({ email });

    if (!user) {
      throw new Error("User not found");
    }

    if (user.emailVerified) {
      throw new Error("Email already verified");
    }

    if (!user.verificationCode || user.verificationCode !== code) {
      throw new Error("Invalid verification code");
    }

    if (new Date() > user.verificationCodeExpiry) {
      throw new Error("Verification code expired");
    }

    // Mark email as verified
    user.emailVerified = true;
    user.verificationCode = undefined;
    user.verificationCodeExpiry = undefined;
    await user.save();

    console.log("✅ Email verified for user:", user._id);
    return user;
  }

  /**
   * Resends an email verification code
   * @param {String} email - User email
   * @returns {Promise<Object>} User with new code
   */
  static async resendVerificationCode(email) {
    const user = await User.findOne({ email });

    if (!user) {
      throw new Error("User not found");
    }

    if (user.emailVerified) {
      throw new Error("Email already verified");
    }

    // Generate new verification code
    const verificationCode = emailService.generateVerificationCode();
    const verificationCodeExpiry = new Date(Date.now() + 15 * 60 * 1000); // 15 minutes

    user.verificationCode = verificationCode;
    user.verificationCodeExpiry = verificationCodeExpiry;
    await user.save();

    // Send verification email
    const emailResult = await emailService.sendVerificationEmail(
      email,
      verificationCode,
      user.fullname,
    );

    // Log in development
    if (process.env.NODE_ENV === "development" || !process.env.EMAIL_USER) {
      console.log("\n========================================");
      console.log("📧 NEW VERIFICATION CODE (DEV MODE)");
      console.log("========================================");
      console.log("User:", user.fullname);
      console.log("Email:", email);
      console.log("Code:", verificationCode);
      console.log("Expires in: 15 minutes");
      console.log("========================================\n");
    }

    console.log("✅ Verification code resent to:", email);
    return { success: emailResult.success, user };
  }

  /**
   * Deletes a user
   * @param {String} userId - User ID
   * @returns {Promise<Boolean>} Operation success
   */
  static async deleteUser(userId) {
    const user = await User.findByIdAndDelete(userId);

    if (!user) {
      throw new Error("User not found");
    }

    console.log("🗑️ User deleted:", userId);
    return true;
  }

  /**
   * Forgot Password - Generate reset code and send email
   * @param {string} email - User email
   * @returns {Object} - Result object
   */
  static async forgotPassword(email) {
    // Find user by email
    const user = await User.findOne({ email });

    if (!user) {
      throw new Error("No account found with this email address");
    }

    // Generate 6-digit reset code
    const resetCode = emailService.generateVerificationCode();
    const resetCodeExpiry = new Date(Date.now() + 15 * 60 * 1000); // 15 minutes

    // Save reset code to user
    user.passwordResetCode = resetCode;
    user.passwordResetCodeExpiry = resetCodeExpiry;
    await user.save();

    // Send password reset email asynchronously (don't block response)
    emailService
      .sendPasswordResetEmail(email, resetCode, user.fullname)
      .then((emailResult) => {
        console.log(
          "📧 Password reset email sent:",
          user._id,
          "Success:",
          emailResult.success,
        );
      })
      .catch((error) => {
        console.error("❌ Error sending password reset email:", error.message);
      });

    // Log reset code in development mode
    if (process.env.NODE_ENV === "development" || !process.env.EMAIL_USER) {
      console.log("\n========================================");
      console.log("🔑 PASSWORD RESET CODE (DEV MODE)");
      console.log("========================================");
      console.log("User:", user.fullname);
      console.log("Email:", email);
      console.log("Reset Code:", resetCode);
      console.log("Expires in: 15 minutes");
      console.log("========================================\n");
    }

    console.log("✅ Password reset code generated for user:", user._id);

    return {
      success: true,
      message: "Password reset code sent to your email",
    };
  }

  /**
   * Reset Password - Verify code and update password
   * @param {string} email - User email
   * @param {string} code - Reset code
   * @param {string} newPassword - New password
   * @returns {Object} - Result object
   */
  static async resetPassword(email, code, newPassword) {
    // Find user by email
    const user = await User.findOne({ email });

    if (!user) {
      throw new Error("No account found with this email address");
    }

    // Check if reset code exists and is not expired
    if (!user.passwordResetCode || !user.passwordResetCodeExpiry) {
      throw new Error("No password reset request found");
    }

    if (user.passwordResetCode !== code) {
      throw new Error("Invalid reset code");
    }

    if (new Date() > user.passwordResetCodeExpiry) {
      throw new Error("Reset code has expired. Please request a new one");
    }

    // Hash new password
    const hashedPassword = await bcrypt.hash(newPassword, 10);

    // Update password, clear reset code, and reactivate account
    user.mot_de_passe = hashedPassword;
    user.passwordResetCode = undefined;
    user.passwordResetCodeExpiry = undefined;
    user.accountStatus = "active"; // Reactivate account on password reset
    user.derniere_connexion = new Date(); // Update last connection
    await user.save();

    console.log("✅ Password reset successful for user:", user._id);

    return {
      success: true,
      message: "Password has been reset successfully",
    };
  }
}

module.exports = UserService;
