const { GoogleGenerativeAI } = require('@google/generative-ai');

// Supported languages
const SUPPORTED_LANGUAGES = {
  en: 'English',
  fr: 'French',
  es: 'Spanish',
  de: 'German',
  ar: 'Arabic',
  ru: 'Russian'
};

// Available Gemini models - prioritize fastest for instant responses
const AVAILABLE_MODELS = [
  'gemini-2.5-flash-lite', // Fastest model
  'gemini-3.1-flash-lite', // Fast and lightweight
  'gemini-2.5-flash',     // Good balance
  'gemini-3-flash'        // High quality (fallback)
];

// Get default model - prioritize speed
const DEFAULT_MODEL = process.env.GEMINI_MODEL || 'gemini-2.5-flash-lite';

// Generate prompt based on action - optimized for speed
function generatePrompt(action, text, lang) {
  switch (action) {
    case 'translate':
      return `Translate to ${SUPPORTED_LANGUAGES[lang] || lang}. Keep meaning exactly:\n\n${text}`;
    
    case 'rewrite':
      return `Rewrite this text naturally and engagingly. Keep meaning exactly:\n\n${text}`;
    
    case 'improve':
      return `Fix grammar and clarity. Keep meaning exactly:\n\n${text}`;
    
    default:
      return text;
  }
}

// Try models with fallback system
async function tryModels(apiKey, prompt, preferredModels = null) {
  const modelsToTry = preferredModels || [DEFAULT_MODEL, ...AVAILABLE_MODELS.filter(m => m !== DEFAULT_MODEL)];
  let lastError = null;

  for (const modelName of modelsToTry) {
    try {
      console.log(`[AI] Trying model: ${modelName}`);
      
      const genAI = new GoogleGenerativeAI(apiKey);
      const model = genAI.getGenerativeModel({ model: modelName });
      
      const result = await model.generateContent(prompt);
      const response = await result.response;
      const processedText = response.text().trim();
      
      console.log(`[AI] Success with model: ${modelName}`);
      return {
        success: true,
        text: processedText,
        model: modelName
      };
      
    } catch (error) {
      lastError = error;
      console.warn(`[AI] Model ${modelName} failed:`, error.message);
      
      // Continue to next model if this one fails
      continue;
    }
  }
  
  // All models failed
  throw lastError || new Error('All AI models failed');
}

// Process text with Gemini AI
exports.processText = async (req, res) => {
  try {
    const { text, action, lang } = req.body;

    // Validation
    if (!text || typeof text !== 'string') {
      return res.status(400).json({ 
        success: false, 
        error: 'Text is required and must be a string' 
      });
    }

    if (!action || !['translate', 'rewrite', 'improve'].includes(action)) {
      return res.status(400).json({ 
        success: false, 
        error: 'Action must be one of: translate, rewrite, improve' 
      });
    }

    if (action === 'translate' && (!lang || !SUPPORTED_LANGUAGES[lang])) {
      return res.status(400).json({ 
        success: false, 
        error: `Language is required for translation. Supported: ${Object.keys(SUPPORTED_LANGUAGES).join(', ')}` 
      });
    }

    // Check for API key
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      return res.status(500).json({ 
        success: false, 
        error: 'GEMINI_API_KEY not configured in environment' 
      });
    }

    // Generate prompt
    const prompt = generatePrompt(action, text, lang);

    // Try models with fallback system
    try {
      const result = await tryModels(apiKey, prompt);
      
      return res.json({
        success: true,
        result: result.text,
        action: action,
        originalText: text,
        model: result.model
      });
      
    } catch (modelError) {
      console.error('[AI] All models failed:', modelError.message);
      
      return res.status(503).json({
        success: false,
        error: 'AI service temporarily unavailable. Please try again later.',
        details: modelError.message
      });
    }

  } catch (error) {
    console.error('AI Text Processing Error:', error.message);
    
    return res.status(500).json({
      success: false,
      error: 'Internal server error during AI processing',
      details: error.message
    });
  }
};

// Health check for AI service
exports.healthCheck = async (req, res) => {
  try {
    const apiKey = process.env.GEMINI_API_KEY;
    
    res.json({
      success: true,
      service: 'AI Text Processing',
      status: apiKey ? 'configured' : 'not configured',
      supportedLanguages: Object.keys(SUPPORTED_LANGUAGES),
      supportedActions: ['translate', 'rewrite', 'improve'],
      availableModels: AVAILABLE_MODELS,
      defaultModel: DEFAULT_MODEL
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
};
