// ✅ ADDED
const Joi = require("joi");

exports.createPostSchema = Joi.object({
  content: Joi.string().allow("", null),
  imageUrl: Joi.string().uri().allow("", null),
  imageUrls: Joi.array().items(Joi.string().uri()).max(10),
  postType: Joi.string().valid("post", "activity"),
  audience: Joi.string().valid("public", "followers"),
  locationLabel: Joi.string().max(200).allow("", null),
  tripLink: Joi.string().uri().allow("", null),
  hashtags: Joi.array().items(Joi.string().max(60)).max(10),
  mentions: Joi.array().items(Joi.string().hex().length(24)).max(20),
});

exports.commentSchema = Joi.object({
  content: Joi.string().min(1).max(1000).required(),
  parentCommentId: Joi.string().allow("", null),
});

exports.updatePostSchema = Joi.object({
  content: Joi.string().allow("", null),
  imageUrls: Joi.array().items(Joi.string().uri()).max(10),
  postType: Joi.string().valid("post", "activity"),
  audience: Joi.string().valid("public", "followers"),
  locationLabel: Joi.string().max(200).allow("", null),
  hashtags: Joi.array().items(Joi.string().max(60)).max(10),
  mentions: Joi.array().items(Joi.string().hex().length(24)).max(20),
});
