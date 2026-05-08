import { GoogleGenerativeAI } from '@google/generative-ai';
import { config } from '../config/index.js';

class GeminiChatService {
  constructor() {
    this.genAI = null;
    this.chatModel = null;
    this.initialized = false;
  }

  initialize() {
    if (this.initialized) return;

    try {
      this.genAI = new GoogleGenerativeAI(config.geminiApiKey);
      this.chatModel = this.genAI.getGenerativeModel({
        model: config.modelName,
        generationConfig: {
          temperature: config.temperature,
          maxOutputTokens: config.maxTokens,
        },
      });
      this.initialized = true;
      console.log('Gemini chat service initialized successfully');
    } catch (error) {
      console.error('Failed to initialize Gemini chat service:', error.message);
      throw new Error(`Gemini chat service initialization failed: ${error.message}`);
    }
  }

  async generateResponse(query, context, conversationHistory = []) {
    if (!this.initialized) {
      this.initialize();
    }

    try {
      const prompt = this.buildPrompt(query, context, conversationHistory);
      
      const result = await this.chatModel.generateContent(prompt);
      const response = result.response.text();
      
      return {
        response: this.cleanResponse(response),
        sources: context.sources || [],
        model: config.modelName,
        timestamp: new Date().toISOString(),
      };
    } catch (error) {
      console.error('Error generating response:', error.message);
      throw new Error(`Failed to generate response: ${error.message}`);
    }
  }

  buildPrompt(query, context, conversationHistory) {
    let prompt = `You are a helpful AI documentation assistant for a software project. Your role is to answer questions about the project based ONLY on the provided documentation context.

## Important Rules:
1. Answer questions using ONLY the provided documentation context
2. If the information is not available in the context, say: "This information is not available in the documentation"
3. Do not invent or hallucinate information
4. Be concise but informative
5. Use bullet points and formatting for clarity
6. If you're unsure, say you don't have enough information
7. Provide step-by-step instructions when relevant
8. Be beginner-friendly but also accurate for technical users

`;

    // Add conversation history if available
    if (conversationHistory.length > 0) {
      prompt += `\n## Previous Conversation:\n`;
      conversationHistory.forEach((msg, index) => {
        if (msg.role === 'user') {
          prompt += `User: ${msg.content}\n`;
        } else {
          prompt += `Assistant: ${msg.content}\n`;
        }
      });
      prompt += '\n';
    }

    // Add context
    if (context.context) {
      prompt += `\n## Documentation Context:\n${context.context}\n\n`;
    }

    // Add sources
    if (context.sources && context.sources.length > 0) {
      prompt += `\n## Sources:\n`;
      context.sources.forEach((source, index) => {
        prompt += `${index + 1}. ${source.filename}${source.sectionHeading ? ` - ${source.sectionHeading}` : ''}\n`;
      });
      prompt += '\n';
    }

    // Add current query
    prompt += `\n## Current Question:\n${query}\n\n`;
    prompt += `## Your Answer:\n`;

    return prompt;
  }

  cleanResponse(response) {
    // Remove any markdown code blocks that might have been added
    let cleaned = response
      .replace(/```markdown\n?/g, '')
      .replace(/```\n?/g, '')
      .trim();
    
    return cleaned;
  }

  async generateStreamingResponse(query, context, conversationHistory = []) {
    if (!this.initialized) {
      this.initialize();
    }

    try {
      const prompt = this.buildPrompt(query, context, conversationHistory);
      const result = await this.chatModel.generateContentStream(prompt);
      
      return {
        stream: result.stream,
        sources: context.sources || [],
        model: config.modelName,
        timestamp: new Date().toISOString(),
      };
    } catch (error) {
      console.error('Error generating streaming response:', error.message);
      throw new Error(`Failed to generate streaming response: ${error.message}`);
    }
  }

  async chatWithHistory(messages, context) {
    if (!this.initialized) {
      this.initialize();
    }

    try {
      // Start a chat session with history
      const chat = this.chatModel.startChat({
        history: this.formatHistoryForGemini(messages),
      });

      const lastMessage = messages[messages.length - 1];
      const prompt = this.buildContextualPrompt(lastMessage.content, context);
      
      const result = await chat.sendMessage(prompt);
      const response = result.response.text();
      
      return {
        response: this.cleanResponse(response),
        sources: context.sources || [],
        model: config.modelName,
        timestamp: new Date().toISOString(),
      };
    } catch (error) {
      console.error('Error in chat with history:', error.message);
      throw new Error(`Chat with history failed: ${error.message}`);
    }
  }

  formatHistoryForGemini(messages) {
    return messages.map(msg => ({
      role: msg.role === 'assistant' ? 'model' : 'user',
      parts: [{ text: msg.content }],
    }));
  }

  buildContextualPrompt(query, context) {
    let prompt = query;

    if (context.context) {
      prompt += `\n\nDocumentation Context:\n${context.context}`;
    }

    if (context.sources && context.sources.length > 0) {
      prompt += `\n\nSources: ${context.sources.map(s => s.filename).join(', ')}`;
    }

    return prompt;
  }

  async summarizeConversation(conversationHistory) {
    if (!this.initialized) {
      this.initialize();
    }

    if (conversationHistory.length === 0) {
      return '';
    }

    try {
      const conversationText = conversationHistory
        .map(msg => `${msg.role}: ${msg.content}`)
        .join('\n');

      const prompt = `Summarize the following conversation in 2-3 sentences:\n\n${conversationText}`;

      const result = await this.chatModel.generateContent(prompt);
      return result.response.text();
    } catch (error) {
      console.error('Error summarizing conversation:', error.message);
      return '';
    }
  }

  isInitialized() {
    return this.initialized;
  }
}

export default new GeminiChatService();
