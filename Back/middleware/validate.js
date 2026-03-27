/**
 * Generic Joi validation middleware factory.
 * Usage: router.post('/', validate(schema), controller)
 */
const validate = (schema) => (req, res, next) => {
  const { error } = schema.validate(req.body, { abortEarly: false });
  if (error) {
    const details = error.details.map((d) => d.message);
    return res.status(400).json({ success: false, errors: details });
  }
  next();
};

module.exports = validate;
