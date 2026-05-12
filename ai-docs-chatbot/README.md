# AI Documentation Chatbot with RAG

A production-ready AI-powered documentation chatbot system that uses GitHub documentation as a dynamic knowledge base. Built with Node.js, Express, and Gemini AI with Retrieval-Augmented Generation (RAG) capabilities.

## 🎯 Features

- **GitHub Integration**: Automatically fetches documentation from GitHub repositories
- **RAG System**: Implements Retrieval-Augmented Generation for accurate responses
- **Semantic Search**: Uses Gemini embeddings for intelligent document search
- **Conversation Memory**: Maintains context across multi-turn conversations
- **Smart Caching**: Optimizes performance with intelligent caching
- **Production-Ready**: Includes error handling, rate limiting, and security
- **Scalable Architecture**: Modular design for easy maintenance and scaling

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Client Layer                             │
│                  (REST API / Web UI)                         │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ HTTP/HTTPS
                            │
┌─────────────────────────────────────────────────────────────┐
│                   Application Layer                           │
│              (Node.js + Express Server)                     │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  API Endpoints │  Controllers │  Middleware          │  │
│  │  - /chat        │  ChatController│  - Validation      │  │
│  │  - /search      │                 │  - Error Handling   │  │
│  │  - /health      │                 │  - Rate Limiting    │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            │
                            │
┌─────────────────────────────────────────────────────────────┐
│                      Service Layer                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ GitHub       │  │ Embedding    │  │ Search       │      │
│  │ Service      │  │ Service      │  │ Service      │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Document     │  │ Gemini Chat  │  │ Conversation │      │
│  │ Parser       │  │ Service      │  │ Memory       │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│  ┌──────────────┐  ┌──────────────┐                         │
│  │ Chunking     │  │ Vector       │                         │
│  │ Service      │  │ Storage      │                         │
│  └──────────────┘  └──────────────┘                         │
└─────────────────────────────────────────────────────────────┘
                            │
                            │
┌─────────────────────────────────────────────────────────────┐
│                    External Services                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ GitHub API   │  │ Gemini API   │  │ Local JSON   │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

## 📁 Project Structure

```
ai-docs-chatbot/
├── src/
│   ├── config/
│   │   └── index.js              # Configuration management
│   ├── controllers/
│   │   └── chatController.js     # API endpoint handlers
│   ├── middleware/
│   │   ├── errorHandler.js       # Error handling middleware
│   │   └── validation.js         # Request validation
│   ├── services/
│   │   ├── githubService.js      # GitHub API integration
│   │   ├── documentParser.js     # Markdown/text parser
│   │   ├── chunkingService.js    # Text chunking logic
│   │   ├── embeddingService.js   # Gemini embeddings
│   │   ├── vectorStorage.js      # Vector storage (JSON)
│   │   ├── searchService.js      # Semantic search
│   │   ├── geminiChatService.js  # Gemini AI chat
│   │   ├── conversationMemory.js # Conversation management
│   │   └── cacheService.js       # Caching system
│   ├── scripts/
│   │   └── reindex-docs.js       # Documentation reindexing
│   └── server.js                 # Main server entry point
├── data/
│   ├── vectors/                  # Vector storage directory
│   └── cache/                    # Cache storage directory
├── .env.example                  # Environment variables template
├── package.json                  # Dependencies
└── README.md                     # This file
```

## ⚙️ Installation

### Prerequisites

- Node.js v20.x or higher
- npm or yarn
- GitHub account (for private repositories)
- Gemini API key

### Setup Steps

1. **Clone or create the project directory**
```bash
cd ai-docs-chatbot
```

2. **Install dependencies**
```bash
npm install
```

3. **Configure environment variables**
```bash
cp .env.example .env
```

Edit `.env` with your configuration:
```env
# Server Configuration
PORT=3001
NODE_ENV=development

# Gemini API Configuration
GEMINI_API_KEY=your_gemini_api_key_here

# GitHub Configuration
GITHUB_OWNER=repository_owner
GITHUB_REPO=repository_name
GITHUB_BRANCH=main
GITHUB_TOKEN=your_github_token_here

# Documentation Configuration
DOCS_PATH=docs
SUPPORTED_EXTENSIONS=.md,.txt
CHUNK_SIZE=1000
CHUNK_OVERLAP=200
MAX_CHUNKS_PER_QUERY=5
SIMILARITY_THRESHOLD=0.7

# Storage Configuration
STORAGE_TYPE=local
VECTOR_STORAGE_PATH=./data/vectors
CACHE_STORAGE_PATH=./data/cache

# Chat Configuration
MAX_CONVERSATION_HISTORY=10
MODEL_NAME=gemini-1.5-flash
TEMPERATURE=0.7
MAX_TOKENS=2048

# Rate Limiting
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100
```

4. **Get Gemini API Key**
- Go to [Google AI Studio](https://makersuite.google.com/app/apikey)
- Create a new API key
- Add it to your `.env` file

5. **Get GitHub Token (for private repos)**
- Go to GitHub Settings → Developer settings → Personal access tokens
- Generate a new token with `repo` scope
- Add it to your `.env` file

6. **Index Documentation**
```bash
npm run reindex
```

This will:
- Fetch documentation from GitHub
- Parse and chunk the content
- Generate embeddings using Gemini
- Store vectors locally
- Update metadata

7. **Start the Server**
```bash
npm start
```

For development with auto-reload:
```bash
npm run dev
```

## 🔌 API Endpoints

### POST /api/chat
Chat with the AI documentation assistant.

**Request Body:**
```json
{
  "query": "How do I create a new activity?",
  "conversationId": "optional-conversation-id",
  "options": {
    "maxChunks": 5,
    "threshold": 0.7
  }
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "response": "To create a new activity...",
    "conversationId": "conv_1234567890_abc123",
    "sources": [
      {
        "filename": "activity-guide.md",
        "path": "docs/activity-guide.md",
        "sectionHeading": "Creating Activities",
        "similarity": 0.95
      }
    ],
    "context": {
      "totalResults": 10,
      "usedResults": 3
    },
    "model": "gemini-1.5-flash",
    "timestamp": "2025-01-01T00:00:00.000Z"
  }
}
```

### POST /api/search
Search documentation without AI response.

**Request Body:**
```json
{
  "query": "booking system",
  "options": {
    "topK": 10,
    "threshold": 0.6,
    "filters": {
      "filename": "booking.md"
    }
  }
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "results": [
      {
        "chunk": { "id": "chunk_0", "text": "...", "metadata": {} },
        "similarity": 0.92,
        "relevance": "high"
      }
    ],
    "query": "booking system",
    "totalChunks": 150,
    "filteredChunks": 25,
    "foundResults": 10,
    "message": "Search completed"
  }
}
```

### GET /api/conversations/:conversationId
Get conversation history.

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "conv_1234567890_abc123",
    "history": [
      {
        "role": "user",
        "content": "How do I create an activity?",
        "timestamp": "2025-01-01T00:00:00.000Z"
      },
      {
        "role": "assistant",
        "content": "To create a new activity...",
        "timestamp": "2025-01-01T00:00:01.000Z"
      }
    ],
    "stats": {
      "totalMessages": 2,
      "userMessages": 1,
      "assistantMessages": 1
    }
  }
}
```

### DELETE /api/conversations/:conversationId
Delete a conversation.

**Response:**
```json
{
  "success": true,
  "data": {
    "message": "Conversation deleted successfully",
    "conversationId": "conv_1234567890_abc123"
  }
}
```

### POST /api/conversations
Create a new conversation.

**Request Body:**
```json
{
  "sessionId": "optional-session-id"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "conv_1234567890_abc123",
    "createdAt": "2025-01-01T00:00:00.000Z"
  }
}
```

### GET /api/health
Health check endpoint.

**Response:**
```json
{
  "success": true,
  "data": {
    "status": "healthy",
    "timestamp": "2025-01-01T00:00:00.000Z",
    "services": {
      "embedding": true,
      "search": true,
      "storage": true
    },
    "storage": {
      "totalChunks": 150,
      "totalFiles": 10,
      "lastUpdated": "2025-01-01T00:00:00.000Z"
    },
    "config": {
      "model": "gemini-1.5-flash",
      "maxChunks": 5,
      "similarityThreshold": 0.7
    }
  }
}
```

## 🧠 RAG Workflow

```
User Question
    ↓
1. Generate Query Embedding (Gemini)
    ↓
2. Search Vector Storage (Cosine Similarity)
    ↓
3. Retrieve Top-K Relevant Chunks
    ↓
4. Build Context from Chunks
    ↓
5. Send Context + Question to Gemini
    ↓
6. Generate Response (Using ONLY Context)
    ↓
7. Return Response with Sources
```

## 🔧 Services Explained

### GitHub Service
- Fetches documentation files from GitHub repositories
- Supports public and private repositories
- Handles rate limiting and pagination
- Filters files by extension and path

### Document Parser
- Parses Markdown and plain text files
- Extracts metadata (headings, sections)
- Removes code blocks and special characters
- Preserves document structure

### Chunking Service
- Splits documents into manageable chunks
- Supports multiple strategies (headings, paragraphs, simple)
- Maintains context with overlap
- Preserves metadata for each chunk

### Embedding Service
- Generates embeddings using Gemini API
- Handles batch processing for efficiency
- Implements rate limiting
- Calculates cosine similarity

### Vector Storage
- Stores embeddings locally as JSON
- Maintains index for fast lookup
- Supports filtering by metadata
- Provides storage statistics

### Search Service
- Performs semantic search using embeddings
- Ranks results by similarity
- Filters by threshold
- Supports hybrid search (semantic + keyword)

### Gemini Chat Service
- Generates AI responses using Gemini
- Builds contextual prompts
- Manages conversation history
- Enforces documentation-only responses

### Conversation Memory
- Stores conversation history in memory
- Maintains context across turns
- Limits history size
- Provides conversation statistics

### Cache Service
- Caches search results and responses
- Implements TTL (Time To Live)
- Automatic cleanup of expired entries
- Hit rate tracking

## 🚀 Usage Examples

### Example 1: Simple Chat
```bash
curl -X POST http://localhost:3001/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "query": "How do I reset my password?"
  }'
```

### Example 2: Chat with Conversation Context
```bash
curl -X POST http://localhost:3001/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "query": "What about for organizers?",
    "conversationId": "conv_1234567890_abc123"
  }'
```

### Example 3: Search Only
```bash
curl -X POST http://localhost:3001/api/search \
  -H "Content-Type: application/json" \
  -d '{
    "query": "payment processing",
    "options": {
      "topK": 10
    }
  }'
```

### Example 4: Get Conversation History
```bash
curl http://localhost:3001/api/conversations/conv_1234567890_abc123
```

## 🔄 Reindexing Documentation

When documentation changes, reindex to keep the knowledge base up-to-date:

```bash
npm run reindex
```

This will:
1. Fetch latest documentation from GitHub
2. Clear existing vectors
3. Parse and chunk new content
4. Generate new embeddings
5. Store updated vectors
6. Clear cache

## ⚡ Performance Optimization

### Caching
- Search results are cached for 1 hour
- Cache cleanup runs every 5 minutes
- Reduces Gemini API calls

### Embedding Batching
- Processes embeddings in batches of 100
- Includes rate limiting delays
- Prevents API quota exhaustion

### Chunking Strategy
- Configurable chunk size (default: 1000 chars)
- Overlap ensures context continuity
- Headings-based chunking preserves structure

### Similarity Threshold
- Filters low-quality matches
- Configurable threshold (default: 0.7)
- Reduces irrelevant context

## 🔒 Security

### Rate Limiting
- 100 requests per 15 minutes per IP
- Configurable window and limits
- Prevents API abuse

### Input Validation
- Query length validation (max 10,000 chars)
- Type checking for all inputs
- Sanitization of special characters

### Environment Variables
- Sensitive data in `.env` file
- Never commit `.env` to git
- Use `.env.example` as template

### CORS
- Configurable CORS origins
- Credentials support
- Development vs production modes

## 📊 Monitoring

### Health Check
```bash
curl http://localhost:3001/api/health
```

Returns:
- Service status
- Storage statistics
- Configuration values
- Service initialization status

### Logs
- All operations logged to console
- Error details in development mode
- Structured logging for production

## 🐛 Troubleshooting

### Issue: "Embedding service initialization failed"
**Solution**: Check your `GEMINI_API_KEY` in `.env`

### Issue: "Failed to fetch repository tree"
**Solution**: Verify GitHub credentials and repository access

### Issue: "No documentation chunks available"
**Solution**: Run `npm run reindex` to index documentation

### Issue: "Rate limit exceeded"
**Solution**: Wait for rate limit window or increase limits in config

### Issue: "Conversation not found"
**Solution**: Create a new conversation using `POST /api/conversations`

## 🔮 Future Enhancements

- [ ] Support for vector databases (Pinecone, Weaviate, ChromaDB)
- [ ] Streaming responses
- [ ] Multi-language support
- [ ] Webhook notifications for documentation updates
- [ ] Admin dashboard for monitoring
- [ ] Analytics and usage tracking
- [ ] A/B testing for prompts
- [ ] Custom fine-tuning of Gemini model
- [ ] Support for multiple repositories
- [ ] GraphQL API

## 📝 Development

### Running Tests
```bash
npm test
```

### Linting
```bash
npm run lint
```

### Code Structure
- Services contain business logic
- Controllers handle HTTP requests
- Middleware handles cross-cutting concerns
- Configuration centralized in `config/`

### Adding New Features
1. Create service in `services/`
2. Add controller in `controllers/`
3. Add validation in `middleware/validation.js`
4. Add route in `server.js`
5. Update documentation

## 📄 License

ISC

## 🤝 Contributing

Contributions are welcome! Please follow these steps:
1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

## 📞 Support

For issues and questions:
- Create an issue on GitHub
- Check existing documentation
- Review troubleshooting section

---

**Built with ❤️ using Node.js, Express, and Gemini AI**
