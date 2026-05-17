const geminiKeyPool = require('../utils/geminiKeyPool');

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
  'gemini-2.0-flash',         // Top priority since images work with it
  'gemini-1.5-flash',         // Standard flash
  'gemini-1.5-flash-001',     // Specific version
  'gemini-1.5-pro',           // Standard pro
  'gemini-1.5-pro-001',       // Specific version
  'gemini-pro',               // Legacy alias
  'gemini-1.0-pro',           // Legacy pro
  'gemini-2.0-flash-lite',    // New lite
];

// Get default model - prioritize stability and success
const DEFAULT_MODEL = process.env.GEMINI_MODEL || 'gemini-2.0-flash';

// Generate prompt based on action - optimized for speed
function generatePrompt(action, text, lang) {
  // If the text already looks like a structured prompt from the frontend, use it directly
  if (text.includes('=== TASK ===') || text.includes('=== TRANSLATION TASK ===')) {
    return text;
  }

  switch (action) {
    case 'translate':
      return `Translate the following text to ${SUPPORTED_LANGUAGES[lang] || lang}. Return ONLY the translated text without any introductions or explanations:\n\n${text}`;
    
    case 'rewrite':
      return `Rewrite the following text naturally and engagingly. Return ONLY the rewritten text without any introductions or explanations:\n\n${text}`;
    
    case 'improve':
      return `Fix grammar and clarity in the following text. Return ONLY the improved text without any introductions or explanations:\n\n${text}`;
    
    default:
      return text;
  }
}

// Process text with Gemini 2.5 Flash directly
async function processWithGemini(prompt) {
  const modelName = 'gemini-2.5-flash';
  console.log(`[AI] Processing with model: ${modelName}`);
  
  const result = await geminiKeyPool.generateContent(modelName, prompt);
  
  return {
    success: true,
    text: result.text,
    model: modelName
  };
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

    // Generate prompt
    const prompt = generatePrompt(action, text, lang);

    // Try models with key pool fallback system
    try {
      const result = await processWithGemini(prompt);
      
      return res.json({
        success: true,
        result: result.text,
        action: action,
        originalText: text,
        model: result.model
      });
      
    } catch (modelError) {
      console.error('[AI] Gemini 2.0 Flash failed:', modelError.message);
      
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
    const poolStatus = geminiKeyPool.getStatus();
    
    res.json({
      success: true,
      service: 'AI Text Processing',
      status: poolStatus.totalKeys > 0 ? 'configured' : 'not configured',
      supportedLanguages: Object.keys(SUPPORTED_LANGUAGES),
      supportedActions: ['translate', 'rewrite', 'improve'],
      availableModels: AVAILABLE_MODELS,
      defaultModel: DEFAULT_MODEL,
      keyPool: poolStatus
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
};
