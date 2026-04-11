const Joi = require("joi");

exports.createCommentSchema = Joi.object({
  content: Joi.string().min(1).max(1200).required().messages({
    "string.empty": "Comment content cannot be empty",
    "string.min": "Comment must be at least 1 character",
    "string.max": "Comment cannot exceed 1200 characters",
    "any.required": "Comment content is required",
  }),
  parentCommentId: Joi.string().allow("", null).optional().messages({
    "string.base": "Parent comment ID must be a string",
  }),
});

exports.updateCommentSchema = Joi.object({
  content: Joi.string().min(1).max(1200).required().messages({
    "string.empty": "Comment content cannot be empty",
    "string.min": "Comment must be at least 1 character",
    "string.max": "Comment cannot exceed 1200 characters",
    "any.required": "Comment content is required",
  }),
});

exports.reactionSchema = Joi.object({
  reactionType: Joi.string()
    .valid("like", "love", "laugh", "wow", "sad", "angry")
    .required()
    .messages({
      "any.only": "Invalid reaction type. Must be one of: like, love, laugh, wow, sad, angry",
      "any.required": "Reaction type is required",
    }),
});
