const mongoose = require("mongoose");
const User = require("./user");

// Admin-specific schema
const adminSchema = new mongoose.Schema({
  // Admin-specific fields can be added here later
  // E.g.: permissions, access logs, etc.
  managedBy: {
    type: String, // Could be "System" or another Admin
    default: "System",
  },
});

// Using discriminator to inherit from User
const Admin = User.discriminator("Admin", adminSchema);

module.exports = Admin;
