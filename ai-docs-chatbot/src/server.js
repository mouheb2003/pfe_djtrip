import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import { config, validateConfig } from './config/index.js';
import chatController from './controllers/chatController.js';
import { errorHandler, notFoundHandler, asyncHandler } from './middleware/errorHandler.js';
import { validateChatRequest, validateSearchRequest, validateConversationId } from './middleware/validation.js';
import searchService from './services/searchService.js';
import geminiChatService from './services/geminiChatService.js';
import cacheService from './services/cacheService.js';
import conversationMemory from './services/conversationMemory.js';

// Validate configuration
validateConfig();

const app = express();

// Security middleware
app.use(helmet({
  contentSecurityPolicy: false, // Disable CSP for API
}));

// CORS
if (config.enableCors) {
  app.use(cors({
    origin: config.corsOrigin,
    credentials: true,
  }));
}

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Rate limiting
const limiter = rateLimit({
  windowMs: config.rateLimitWindowMs,
  max: config.rateLimitMaxRequests,
  message: {
    success: false,
    error: 'Too many requests, please try again later',
  },
});

app.use('/api/', limiter);

// Request logging middleware
app.use((req, res, next) => {
  console.log(`${req.method} ${req.path}`);
  next();
});

// Initialize services
async function initializeServices() {
  try {
    console.log('Initializing services...');
    
    // Initialize embedding service
    geminiChatService.initialize();
    
    // Initialize search service
    await searchService.initialize();
    
    // Load cache
    await cacheService.loadCache();
    
    // Schedule cache cleanup
    setInterval(() => cacheService.cleanup(), 5 * 60 * 1000); // Every 5 minutes
    
    console.log('Services initialized successfully');
  } catch (error) {
    console.error('Error initializing services:', error.message);
    throw error;
  }
}

// Routes
app.get('/api/health', asyncHandler(async (req, res) => {
  await chatController.health(req, res);
}));

app.post('/api/chat', validateChatRequest, asyncHandler(async (req, res) => {
  await chatController.chat(req, res);
}));

app.post('/api/search', validateSearchRequest, asyncHandler(async (req, res) => {
  await chatController.search(req, res);
}));

app.post('/api/conversations', asyncHandler(async (req, res) => {
  await chatController.createConversation(req, res);
}));

app.get('/api/conversations/:conversationId', validateConversationId, asyncHandler(async (req, res) => {
  await chatController.getConversation(req, res);
}));

app.delete('/api/conversations/:conversationId', validateConversationId, asyncHandler(async (req, res) => {
  await chatController.deleteConversation(req, res);
}));

// 404 handler
app.use(notFoundHandler);

// Error handler
app.use(errorHandler);

// Start server
const PORT = config.port;

async function startServer() {
  try {
    await initializeServices();
    
    app.listen(PORT, () => {
      console.log(`🚀 AI Docs Chatbot server running on port ${PORT}`);
      console.log(`📊 Environment: ${config.nodeEnv}`);
      console.log(`🤖 Model: ${config.modelName}`);
      console.log(`📚 GitHub: ${config.githubOwner}/${config.githubRepo}`);
    });
  } catch (error) {
    console.error('Failed to start server:', error.message);
    process.exit(1);
  }
}

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, shutting down gracefully...');
  await cacheService.saveCache();
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('SIGINT received, shutting down gracefully...');
  await cacheService.saveCache();
  process.exit(0);
});

// Start the server
startServer();

export default app;
