import { GoogleGenerativeAI } from '@google/generative-ai';
import { config } from '../config/index.js';

class EmbeddingService {
  constructor() {
    this.genAI = null;
    this.embeddingModel = null;
    this.initialized = false;
  }

  initialize() {
    if (this.initialized) return;

    try {
      this.genAI = new GoogleGenerativeAI(config.geminiApiKey);
      this.embeddingModel = this.genAI.getEmbeddingModel('text-embedding-004');
      this.initialized = true;
      console.log('Embedding service initialized successfully');
    } catch (error) {
      console.error('Failed to initialize embedding service:', error.message);
      throw new Error(`Embedding service initialization failed: ${error.message}`);
    }
  }

  async generateEmbedding(text) {
    if (!this.initialized) {
      this.initialize();
    }

    try {
      const result = await this.embeddingModel.embedContent(text);
      return result.embedding.values;
    } catch (error) {
      console.error('Error generating embedding:', error.message);
      throw new Error(`Failed to generate embedding: ${error.message}`);
    }
  }

  async generateBatchEmbeddings(texts, batchSize = 100) {
    const embeddings = [];
    
    for (let i = 0; i < texts.length; i += batchSize) {
      const batch = texts.slice(i, i + batchSize);
      console.log(`Processing batch ${Math.floor(i / batchSize) + 1}/${Math.ceil(texts.length / batchSize)}`);
      
      const batchEmbeddings = await Promise.all(
        batch.map(text => this.generateEmbedding(text))
      );
      
      embeddings.push(...batchEmbeddings);
      
      // Small delay to avoid rate limiting
      if (i + batchSize < texts.length) {
        await this.sleep(100);
      }
    }
    
    return embeddings;
  }

  async generateChunkEmbeddings(chunks) {
    console.log(`Generating embeddings for ${chunks.length} chunks...`);
    
    const texts = chunks.map(chunk => chunk.text);
    const embeddings = await this.generateBatchEmbeddings(texts);
    
    // Combine chunks with their embeddings
    const chunksWithEmbeddings = chunks.map((chunk, index) => ({
      ...chunk,
      embedding: embeddings[index],
      embeddingDimension: embeddings[index].length,
    }));
    
    console.log('Embeddings generated successfully');
    return chunksWithEmbeddings;
  }

  calculateSimilarity(embedding1, embedding2) {
    if (embedding1.length !== embedding2.length) {
      throw new Error('Embeddings must have the same dimension');
    }

    // Cosine similarity
    let dotProduct = 0;
    let norm1 = 0;
    let norm2 = 0;

    for (let i = 0; i < embedding1.length; i++) {
      dotProduct += embedding1[i] * embedding2[i];
      norm1 += embedding1[i] * embedding1[i];
      norm2 += embedding2[i] * embedding2[i];
    }

    norm1 = Math.sqrt(norm1);
    norm2 = Math.sqrt(norm2);

    if (norm1 === 0 || norm2 === 0) {
      return 0;
    }

    return dotProduct / (norm1 * norm2);
  }

  async findMostSimilar(queryEmbedding, embeddings, topK = 5) {
    const similarities = embeddings.map((item, index) => ({
      index,
      similarity: this.calculateSimilarity(queryEmbedding, item.embedding),
      item,
    }));

    // Sort by similarity (descending)
    similarities.sort((a, b) => b.similarity - a.similarity);

    // Return top K
    return similarities.slice(0, topK);
  }

  sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  isInitialized() {
    return this.initialized;
  }
}

export default new EmbeddingService();
