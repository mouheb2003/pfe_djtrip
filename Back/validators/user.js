// ✅ ADDED
const Joi = require("joi");

exports.signUpSchema = Joi.object({
  fullname: Joi.string().min(2).max(120).required(),
  email: Joi.string().email().required(),
  mot_de_passe: Joi.string().min(6).max(128).required(),
  userType: Joi.string().valid("Touriste", "Organisator", "Admin").required(),
});

exports.signInSchema = Joi.object({
  // Accept both classic emails and username-like identifiers (e.g. admin)
  email: Joi.string().min(1).required(),
  mot_de_passe: Joi.string().min(5).max(128).required(),
});

exports.forgotPasswordSchema = Joi.object({
  email: Joi.string().email().required(),
});

exports.resetPasswordSchema = Joi.object({
  email: Joi.string().email().required(),
  code: Joi.string().min(4).max(12).required(),
  newPassword: Joi.string().min(6).max(128).required(),
});
