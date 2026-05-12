export const validateChatRequest = (req, res, next) => {
  const { query } = req.body;

  if (!query) {
    return res.status(400).json({
      success: false,
      error: 'Query is required',
    });
  }

  if (typeof query !== 'string') {
    return res.status(400).json({
      success: false,
      error: 'Query must be a string',
    });
  }

  if (query.trim().length === 0) {
    return res.status(400).json({
      success: false,
      error: 'Query cannot be empty',
    });
  }

  if (query.length > 10000) {
    return res.status(400).json({
      success: false,
      error: 'Query is too long (max 10000 characters)',
    });
  }

  next();
};

export const validateSearchRequest = (req, res, next) => {
  const { query } = req.body;

  if (!query) {
    return res.status(400).json({
      success: false,
      error: 'Query is required',
    });
  }

  if (typeof query !== 'string') {
    return res.status(400).json({
      success: false,
      error: 'Query must be a string',
    });
  }

  if (query.trim().length === 0) {
    return res.status(400).json({
      success: false,
      error: 'Query cannot be empty',
    });
  }

  next();
};

export const validateConversationId = (req, res, next) => {
  const { conversationId } = req.params;

  if (!conversationId) {
    return res.status(400).json({
      success: false,
      error: 'Conversation ID is required',
    });
  }

  if (typeof conversationId !== 'string') {
    return res.status(400).json({
      success: false,
      error: 'Conversation ID must be a string',
    });
  }

  next();
};
