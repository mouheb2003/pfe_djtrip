import dotenv from 'dotenv';

dotenv.config();

export const config = {
  // Server
  port: parseInt(process.env.PORT || '3001', 10),
  nodeEnv: process.env.NODE_ENV || 'development',
  
  // Gemini API
  geminiApiKey: process.env.GEMINI_API_KEY,
  geminiApiKeys: process.env.GEMINI_API_KEYS, // Added for rotation
  modelName: process.env.MODEL_NAME || 'gemini-1.5-flash',
  temperature: parseFloat(process.env.TEMPERATURE || '0.7'),
  maxTokens: parseInt(process.env.MAX_TOKENS || '2048', 10),
  
  // GitHub
  githubOwner: process.env.GITHUB_OWNER,
  githubRepo: process.env.GITHUB_REPO,
  githubBranch: process.env.GITHUB_BRANCH || 'main',
  githubToken: process.env.GITHUB_TOKEN,
  githubApiUrl: 'https://api.github.com',
  
  // Documentation
  docsPath: process.env.DOCS_PATH || 'docs',
  supportedExtensions: (process.env.SUPPORTED_EXTENSIONS || '.md,.txt').split(','),
  chunkSize: parseInt(process.env.CHUNK_SIZE || '1000', 10),
  chunkOverlap: parseInt(process.env.CHUNK_OVERLAP || '200', 10),
  maxChunksPerQuery: parseInt(process.env.MAX_CHUNKS_PER_QUERY || '5', 10),
  similarityThreshold: parseFloat(process.env.SIMILARITY_THRESHOLD || '0.7'),
  
  // Storage
  storageType: process.env.STORAGE_TYPE || 'local',
  vectorStoragePath: process.env.VECTOR_STORAGE_PATH || './data/vectors',
  cacheStoragePath: process.env.CACHE_STORAGE_PATH || './data/cache',
  
  // Chat
  maxConversationHistory: parseInt(process.env.MAX_CONVERSATION_HISTORY || '10', 10),
  
  // Rate Limiting
  rateLimitWindowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS || '900000', 10),
  rateLimitMaxRequests: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS || '100', 10),
  
  // Security
  enableCors: process.env.ENABLE_CORS === 'true',
  corsOrigin: process.env.CORS_ORIGIN || '*',
};

export const validateConfig = () => {
  const required = ['GEMINI_API_KEY', 'GITHUB_OWNER', 'GITHUB_REPO'];
  const missing = required.filter(key => !process.env[key]);
  
  if (missing.length > 0) {
    throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
  }
  
  return true;
};
