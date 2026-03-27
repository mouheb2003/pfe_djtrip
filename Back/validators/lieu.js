const Joi = require("joi");

const createLieuSchema = Joi.object({
  titre: Joi.string().required(),
  sousTitre: Joi.string().required(),
  description: Joi.string().required(),
  imagePortrait: Joi.string().required(),
  imagePaysage: Joi.string(),
  images: Joi.array().items(Joi.string()),
  noteMoyenne: Joi.number().min(0).max(5),
  nombreAvis: Joi.number().min(0),
  categorie: Joi.string()
    .valid("Beaches", "Museums", "Villages", "Nature", "Other")
    .required(),
  topDestination: Joi.boolean(),
  meilleurePeriode: Joi.string(),
  dureeVisite: Joi.string(),
  prix: Joi.string(),
  coordonnees: Joi.object({
    latitude: Joi.number(),
    longitude: Joi.number(),
  }),
  tags: Joi.array().items(Joi.string()),
  activiteLiee: Joi.string().alphanum().length(24), // MongoDB ObjectId
});

const updateLieuSchema = Joi.object({
  titre: Joi.string(),
  sousTitre: Joi.string(),
  description: Joi.string(),
  imagePortrait: Joi.string(),
  imagePaysage: Joi.string(),
  images: Joi.array().items(Joi.string()),
  noteMoyenne: Joi.number().min(0).max(5),
  nombreAvis: Joi.number().min(0),
  categorie: Joi.string().valid(
    "Beaches",
    "Museums",
    "Villages",
    "Nature",
    "Other",
  ),
  topDestination: Joi.boolean(),
  meilleurePeriode: Joi.string(),
  dureeVisite: Joi.string(),
  prix: Joi.string(),
  coordonnees: Joi.object({
    latitude: Joi.number(),
    longitude: Joi.number(),
  }),
  tags: Joi.array().items(Joi.string()),
  activiteLiee: Joi.string().alphanum().length(24),
});

module.exports = {
  createLieuSchema,
  updateLieuSchema,
};
