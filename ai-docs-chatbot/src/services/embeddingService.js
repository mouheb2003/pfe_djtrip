import geminiKeyPool from './geminiKeyPool.js';
import { config } from '../config/index.js';

class EmbeddingService {
  constructor() {
    this.initialized = false;
  }

  initialize() {
    if (this.initialized) return;
    geminiKeyPool.initialize();
    this.initialized = true;
    console.log('Embedding service initialized with key pool');
  }

  async generateEmbedding(text) {
    if (!this.initialized) {
      this.initialize();
    }

    try {
      const result = await geminiKeyPool.embedContent('gemini-embedding-2', text);
      return result.embedding.values;
    } catch (error) {
      console.error('Error generating embedding:', error.message);
      throw new Error(`Failed to generate embedding: ${error.message}`);
    }
  }

  async generateBatchEmbeddings(texts, batchSize = 20) {
    if (!this.initialized) {
      this.initialize();
    }
    const embeddings = [];
    
    for (let i = 0; i < texts.length; i += batchSize) {
      const batch = texts.slice(i, i + batchSize);
      console.log(`Processing batch ${Math.floor(i / batchSize) + 1}/${Math.ceil(texts.length / batchSize)}`);
      
      let success = false;
      let retries = 0;
      const maxRetries = 5;

      while (!success && retries < maxRetries) {
        try {
          const genAI = geminiKeyPool.getClient();
          const embeddingModel = genAI.getGenerativeModel({ model: 'gemini-embedding-2' });

          const result = await embeddingModel.batchEmbedContents({
            requests: batch.map(text => ({
              content: { role: 'user', parts: [{ text }] },
              model: 'models/gemini-embedding-2'
            }))
          });
          
          const batchValues = result.embeddings.map(e => e.values);
          embeddings.push(...batchValues);
          success = true;
        } catch (error) {
          if (error.message.includes('429')) {
            retries++;
            const waitTime = Math.pow(2, retries) * 60000; // 60s, 120s, 240s...
            console.warn(`⚠️ Rate limit hit. Retry ${retries}/${maxRetries} in ${waitTime/1000}s...`);
            await this.sleep(waitTime);
          } else {
            console.error(`❌ Non-quota error in batch ${i}:`, error.message);
            // Fallback to individual
            console.log('Falling back to individual embeddings with strict delay...');
            for (const text of batch) {
              let indSuccess = false;
              let indRetries = 0;
              while (!indSuccess && indRetries < 5) {
                try {
                  embeddings.push(await this.generateEmbedding(text));
                  await this.sleep(6000); // 6s between individual
                  indSuccess = true;
                } catch (indErr) {
                  indRetries++;
                  console.warn(`⚠️ Individual retry ${indRetries}...`);
                  await this.sleep(15000 * indRetries);
                }
              }
              if (!indSuccess) throw new Error('Failed to generate individual embedding after retries');
            }
            success = true;
          }
        }
      }

      if (!success) {
        throw new Error(`Failed to process batch ${i} after ${maxRetries} retries`);
      }
      
      // Steady delay to stay under 15 RPM (approx 1 request per 4s)
      // Since a batch of 5 might count as 5 requests, we wait 65s.
      if (i + batchSize < texts.length) {
        console.log('Waiting 20 seconds for next batch to respect RPM quota...');
        await this.sleep(20000);
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
