/**
 * Generic Joi validation middleware factory.
 * Usage: router.post('/', validate(schema), controller)
 */
const validate = (schema) => (req, res, next) => {
  console.log('[VALIDATE] Starting validation');
  const { error, value } = schema.validate(req.body, {
    abortEarly: false,
    stripUnknown: true,
  });
  if (error) {
    console.log('[VALIDATE] Validation failed:', error.message);
    const details = error.details.map((d) => d.message);
    return res.status(400).json({
      success: false,
      message: "Validation failed",
      error: details,
    });
  }
  console.log('[VALIDATE] Validation passed');
  req.body = value;
  next();
};

module.exports = validate;
