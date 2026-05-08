class ConversationMemory {
  constructor() {
    this.conversations = new Map();
    this.maxHistory = config.maxConversationHistory;
  }

  createConversation(sessionId = null) {
    const id = sessionId || this.generateId();
    const conversation = {
      id,
      messages: [],
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    this.conversations.set(id, conversation);
    return conversation;
  }

  generateId() {
    return `conv_${Date.now()}_${Math.random().toString(36).substring(2, 11)}`;
  }

  getConversation(conversationId) {
    return this.conversations.get(conversationId);
  }

  addMessage(conversationId, role, content, metadata = {}) {
    const conversation = this.conversations.get(conversationId);
    
    if (!conversation) {
      throw new Error(`Conversation ${conversationId} not found`);
    }

    const message = {
      id: this.generateId(),
      role,
      content,
      timestamp: new Date().toISOString(),
      ...metadata,
    };

    conversation.messages.push(message);
    conversation.updatedAt = new Date().toISOString();

    // Trim history if it exceeds max
    if (conversation.messages.length > this.maxHistory * 2) {
      // Keep the last maxHistory * 2 messages
      conversation.messages = conversation.messages.slice(-this.maxHistory * 2);
    }

    return message;
  }

  getConversationHistory(conversationId, limit = null) {
    const conversation = this.conversations.get(conversationId);
    
    if (!conversation) {
      return [];
    }

    let messages = conversation.messages;

    if (limit) {
      messages = messages.slice(-limit);
    }

    return messages;
  }

  getFormattedHistory(conversationId, limit = null) {
    const messages = this.getConversationHistory(conversationId, limit);
    
    return messages.map(msg => ({
      role: msg.role,
      content: msg.content,
      timestamp: msg.timestamp,
    }));
  }

  updateConversationMetadata(conversationId, metadata) {
    const conversation = this.conversations.get(conversationId);
    
    if (!conversation) {
      throw new Error(`Conversation ${conversationId} not found`);
    }

    conversation.metadata = {
      ...conversation.metadata,
      ...metadata,
    };
    conversation.updatedAt = new Date().toISOString();

    return conversation;
  }

  deleteConversation(conversationId) {
    return this.conversations.delete(conversationId);
  }

  deleteMessage(conversationId, messageId) {
    const conversation = this.conversations.get(conversationId);
    
    if (!conversation) {
      throw new Error(`Conversation ${conversationId} not found`);
    }

    conversation.messages = conversation.messages.filter(m => m.id !== messageId);
    conversation.updatedAt = new Date().toISOString();

    return conversation;
  }

  clearConversation(conversationId) {
    const conversation = this.conversations.get(conversationId);
    
    if (!conversation) {
      throw new Error(`Conversation ${conversationId} not found`);
    }

    conversation.messages = [];
    conversation.updatedAt = new Date().toISOString();

    return conversation;
  }

  getAllConversations() {
    return Array.from(this.conversations.values());
  }

  getConversationStats(conversationId) {
    const conversation = this.conversations.get(conversationId);
    
    if (!conversation) {
      return null;
    }

    const userMessages = conversation.messages.filter(m => m.role === 'user');
    const assistantMessages = conversation.messages.filter(m => m.role === 'assistant');

    return {
      id: conversation.id,
      totalMessages: conversation.messages.length,
      userMessages: userMessages.length,
      assistantMessages: assistantMessages.length,
      createdAt: conversation.createdAt,
      updatedAt: conversation.updatedAt,
      duration: new Date(conversation.updatedAt) - new Date(conversation.createdAt),
    };
  }

  cleanupOldConversations(maxAge = 24 * 60 * 60 * 1000) { // 24 hours default
    const now = Date.now();
    const deleted = [];

    for (const [id, conversation] of this.conversations.entries()) {
      const age = now - new Date(conversation.createdAt).getTime();
      
      if (age > maxAge) {
        this.conversations.delete(id);
        deleted.push(id);
      }
    }

    return deleted;
  }

  exportConversation(conversationId) {
    const conversation = this.conversations.get(conversationId);
    
    if (!conversation) {
      return null;
    }

    return JSON.stringify(conversation, null, 2);
  }

  importConversation(conversationData) {
    try {
      const conversation = JSON.parse(conversationData);
      
      if (!conversation.id || !Array.isArray(conversation.messages)) {
        throw new Error('Invalid conversation data');
      }

      this.conversations.set(conversation.id, conversation);
      return conversation;
    } catch (error) {
      throw new Error(`Failed to import conversation: ${error.message}`);
    }
  }
}

// Import config at the end to avoid circular dependency
import { config } from '../config/index.js';

export default new ConversationMemory();
