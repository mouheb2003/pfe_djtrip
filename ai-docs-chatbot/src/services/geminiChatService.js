import geminiKeyPool from './geminiKeyPool.js';
import { config } from '../config/index.js';

class GeminiChatService {
  constructor() {
    this.initialized = false;
  }

  initialize() {
    if (this.initialized) return;
    geminiKeyPool.initialize();
    this.initialized = true;
    console.log('Gemini chat service initialized with key pool');
  }

  async generateResponse(query, context, conversationHistory = []) {
    if (!this.initialized) {
      this.initialize();
    }

    try {
      const prompt = this.buildPrompt(query, context, conversationHistory);
      
      const result = await geminiKeyPool.generateContent(config.modelName, prompt, {
        generationConfig: {
          temperature: config.temperature,
          maxOutputTokens: config.maxTokens,
        },
      });
      
      return {
        response: this.cleanResponse(result.text),
        sources: context.sources || [],
        model: config.modelName,
        timestamp: new Date().toISOString(),
      };
    } catch (error) {
      console.error('Error generating response:', error.message);
      throw new Error(`Failed to generate response: ${error.message}`);
    }
  }

  buildPrompt(query, context, conversationHistory = []) {
    let prompt = `You are the Expert AI Assistant for DJTrip (Djerba Trip Application). Your mission is to provide precise, helpful, and technically accurate information based on the provided documentation.

You have deep knowledge of:
- The project structure (Back, Front, Dashboard).
- Every screen, button, and icon described in the docs.
- The business logic (Booking flows, Check-in, Payments, Social interactions).
- The technology stack (Node.js, Flutter, MongoDB, Socket.io, Stripe).

## Important Rules:
1. Answer using ONLY the provided documentation context.
2. If the info is not in the context, say: "I'm sorry, I don't find this specific information in the current documentation. Could you please clarify or check the relevant files?"
3. Be EXTREMELY precise about UI elements (e.g., "Tap the '+' floating action button in the Activities tab").
4. Maintain a professional, expert, and helpful tone.
5. Use markdown formatting (bullet points, bold text, code snippets) to make answers scannable.
6. When explaining a process, use numbered steps.
7. Always provide context-aware answers based on the user's role (Tourist, Organizer, or Admin) if mentioned.
8. If the user asks about the code structure, refer to the project directories (Back/, Front/, dashbord/).

`;

    // Add conversation history if available
    if (conversationHistory.length > 0) {
      prompt += `\n## Previous Conversation:\n`;
      conversationHistory.forEach((msg) => {
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
      const result = await geminiKeyPool.generateContentStream(config.modelName, prompt, {
        generationConfig: {
          temperature: config.temperature,
          maxOutputTokens: config.maxTokens,
        },
      });
      
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
      // Get a client from the pool
      const genAI = geminiKeyPool.getClient();
      const model = genAI.getGenerativeModel({
        model: config.modelName,
        generationConfig: {
          temperature: config.temperature,
          maxOutputTokens: config.maxTokens,
        },
      });

      // Start a chat session with history
      const chat = model.startChat({
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

      const result = await geminiKeyPool.generateContent(config.modelName, prompt);
      return result.text;
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
