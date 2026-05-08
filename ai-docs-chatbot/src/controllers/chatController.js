import searchService from '../services/searchService.js';
import geminiChatService from '../services/geminiChatService.js';
import conversationMemory from '../services/conversationMemory.js';
import { config } from '../config/index.js';

class ChatController {
  async chat(req, res) {
    try {
      const { query, conversationId, options = {} } = req.body;

      // Validate input
      if (!query || typeof query !== 'string' || query.trim().length === 0) {
        return res.status(400).json({
          success: false,
          error: 'Query is required and must be a non-empty string',
        });
      }

      const trimmedQuery = query.trim();

      // Get or create conversation
      let conversation;
      if (conversationId) {
        conversation = conversationMemory.getConversation(conversationId);
        if (!conversation) {
          conversation = conversationMemory.createConversation(conversationId);
        }
      } else {
        conversation = conversationMemory.createConversation();
      }

      // Add user message to conversation
      conversationMemory.addMessage(conversation.id, 'user', trimmedQuery);

      // Search for relevant documentation
      const context = await searchService.getContextForQuery(trimmedQuery, options);

      // Get conversation history
      const history = conversationMemory.getFormattedHistory(
        conversation.id,
        config.maxConversationHistory
      );

      // Generate AI response
      const response = await geminiChatService.generateResponse(
        trimmedQuery,
        context,
        history
      );

      // Add assistant response to conversation
      conversationMemory.addMessage(
        conversation.id,
        'assistant',
        response.response,
        { sources: response.sources }
      );

      res.json({
        success: true,
        data: {
          response: response.response,
          conversationId: conversation.id,
          sources: response.sources,
          context: {
            totalResults: context.totalResults,
            usedResults: context.usedResults,
          },
          model: response.model,
          timestamp: response.timestamp,
        },
      });
    } catch (error) {
      console.error('Error in chat endpoint:', error);
      res.status(500).json({
        success: false,
        error: error.message || 'Failed to process chat request',
      });
    }
  }

  async search(req, res) {
    try {
      const { query, options = {} } = req.body;

      if (!query || typeof query !== 'string' || query.trim().length === 0) {
        return res.status(400).json({
          success: false,
          error: 'Query is required and must be a non-empty string',
        });
      }

      const trimmedQuery = query.trim();
      const results = await searchService.search(trimmedQuery, options);

      res.json({
        success: true,
        data: results,
      });
    } catch (error) {
      console.error('Error in search endpoint:', error);
      res.status(500).json({
        success: false,
        error: error.message || 'Search failed',
      });
    }
  }

  async getConversation(req, res) {
    try {
      const { conversationId } = req.params;

      if (!conversationId) {
        return res.status(400).json({
          success: false,
          error: 'Conversation ID is required',
        });
      }

      const conversation = conversationMemory.getConversation(conversationId);

      if (!conversation) {
        return res.status(404).json({
          success: false,
          error: 'Conversation not found',
        });
      }

      const history = conversationMemory.getFormattedHistory(conversationId);
      const stats = conversationMemory.getConversationStats(conversationId);

      res.json({
        success: true,
        data: {
          id: conversation.id,
          history,
          stats,
          metadata: conversation.metadata || {},
        },
      });
    } catch (error) {
      console.error('Error in getConversation endpoint:', error);
      res.status(500).json({
        success: false,
        error: error.message || 'Failed to get conversation',
      });
    }
  }

  async deleteConversation(req, res) {
    try {
      const { conversationId } = req.params;

      if (!conversationId) {
        return res.status(400).json({
          success: false,
          error: 'Conversation ID is required',
        });
      }

      const deleted = conversationMemory.deleteConversation(conversationId);

      if (!deleted) {
        return res.status(404).json({
          success: false,
          error: 'Conversation not found',
        });
      }

      res.json({
        success: true,
        data: {
          message: 'Conversation deleted successfully',
          conversationId,
        },
      });
    } catch (error) {
      console.error('Error in deleteConversation endpoint:', error);
      res.status(500).json({
        success: false,
        error: error.message || 'Failed to delete conversation',
      });
    }
  }

  async createConversation(req, res) {
    try {
      const { sessionId } = req.body;
      const conversation = conversationMemory.createConversation(sessionId);

      res.json({
        success: true,
        data: {
          id: conversation.id,
          createdAt: conversation.createdAt,
        },
      });
    } catch (error) {
      console.error('Error in createConversation endpoint:', error);
      res.status(500).json({
        success: false,
        error: error.message || 'Failed to create conversation',
      });
    }
  }

  async health(req, res) {
    try {
      const storageStats = await searchService.isInitialized()
        ? await searchService.searchService?.vectorStorage?.getStorageStats()
        : null;

      res.json({
        success: true,
        data: {
          status: 'healthy',
          timestamp: new Date().toISOString(),
          services: {
            embedding: geminiChatService.isInitialized(),
            search: searchService.isInitialized(),
            storage: storageStats !== null,
          },
          storage: storageStats || null,
          config: {
            model: config.modelName,
            maxChunks: config.maxChunksPerQuery,
            similarityThreshold: config.similarityThreshold,
          },
        },
      });
    } catch (error) {
      console.error('Error in health endpoint:', error);
      res.status(500).json({
        success: false,
        error: error.message || 'Health check failed',
      });
    }
  }
}

export default new ChatController();
