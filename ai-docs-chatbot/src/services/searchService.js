import embeddingService from './embeddingService.js';
import vectorStorage from './vectorStorage.js';
import { config } from '../config/index.js';

class SearchService {
  constructor() {
    this.initialized = false;
  }

  async initialize() {
    if (this.initialized) return;

    try {
      await vectorStorage.loadVectors();
      this.initialized = true;
      console.log('Search service initialized successfully');
    } catch (error) {
      console.error('Failed to initialize search service:', error.message);
      throw error;
    }
  }

  async search(query, options = {}) {
    const {
      topK = config.maxChunksPerQuery,
      threshold = config.similarityThreshold,
      filters = {},
    } = options;

    if (!this.initialized) {
      await this.initialize();
    }

    try {
      // Generate embedding for query
      const queryEmbedding = await embeddingService.generateEmbedding(query);
      
      // Get all vectors
      const vectors = await vectorStorage.getAllVectors();
      
      if (vectors.length === 0) {
        return {
          results: [],
          query,
          totalChunks: 0,
          message: 'No documentation chunks available',
        };
      }

      // Apply filters if provided
      let filteredVectors = vectors;
      
      if (filters.filename) {
        filteredVectors = filteredVectors.filter(v => 
          v.metadata.filename === filters.filename
        );
      }
      
      if (filters.path) {
        filteredVectors = filteredVectors.filter(v => 
          v.metadata.path === filters.path
        );
      }
      
      if (filters.sectionHeading) {
        filteredVectors = filteredVectors.filter(v => 
          v.metadata.sectionHeading === filters.sectionHeading
        );
      }

      // Find most similar chunks
      const similarities = await embeddingService.findMostSimilar(
        queryEmbedding,
        filteredVectors,
        topK
      );

      // Filter by threshold
      const filteredResults = similarities.filter(
        result => result.similarity >= threshold
      );

      // Format results
      const results = filteredResults.map(result => ({
        chunk: result.item,
        similarity: result.similarity,
        relevance: this.getRelevanceLabel(result.similarity),
      }));

      return {
        results,
        query,
        totalChunks: vectors.length,
        filteredChunks: filteredVectors.length,
        foundResults: results.length,
        message: results.length === 0 ? 'No relevant documentation found' : 'Search completed',
      };
    } catch (error) {
      console.error('Error during search:', error.message);
      throw new Error(`Search failed: ${error.message}`);
    }
  }

  getRelevanceLabel(similarity) {
    if (similarity >= 0.9) return 'very_high';
    if (similarity >= 0.8) return 'high';
    if (similarity >= 0.7) return 'medium';
    if (similarity >= 0.6) return 'low';
    return 'very_low';
  }

  async searchMultiple(queries, options = {}) {
    const results = [];
    
    for (const query of queries) {
      const searchResult = await this.search(query, options);
      results.push(searchResult);
    }
    
    // Merge and deduplicate results
    const mergedResults = this.mergeSearchResults(results);
    
    return {
      results: mergedResults,
      queries,
      totalQueries: queries.length,
    };
  }

  mergeSearchResults(searchResults) {
    const seen = new Set();
    const merged = [];
    
    for (const result of searchResults) {
      for (const item of result.results) {
        const key = item.chunk.id;
        
        if (!seen.has(key)) {
          seen.add(key);
          merged.push(item);
        } else {
          // Update similarity if higher
          const existing = merged.find(m => m.chunk.id === key);
          if (existing && item.similarity > existing.similarity) {
            existing.similarity = item.similarity;
            existing.relevance = this.getRelevanceLabel(item.similarity);
          }
        }
      }
    }
    
    // Sort by similarity
    merged.sort((a, b) => b.similarity - a.similarity);
    
    return merged;
  }

  async getContextForQuery(query, options = {}) {
    const searchResult = await this.search(query, options);
    
    if (searchResult.results.length === 0) {
      return {
        context: '',
        sources: [],
        message: 'No relevant context found',
      };
    }

    // Combine context from top results
    const topResults = searchResult.results.slice(0, options.maxChunks || 3);
    const context = topResults
      .map((result, index) => {
        const source = result.chunk.metadata;
        return `[${index + 1}] From ${source.filename}${source.sectionHeading ? ` - ${source.sectionHeading}` : ''}:\n${result.chunk.text}`;
      })
      .join('\n\n');

    const sources = topResults.map(result => ({
      filename: result.chunk.metadata.filename,
      path: result.chunk.metadata.path,
      sectionHeading: result.chunk.metadata.sectionHeading,
      similarity: result.similarity,
    }));

    return {
      context,
      sources,
      totalResults: searchResult.results.length,
      usedResults: topResults.length,
    };
  }

  async hybridSearch(query, options = {}) {
    // Combine semantic search with keyword search
    const semanticResults = await this.search(query, options);
    
    // Keyword search (simple implementation)
    const vectors = await vectorStorage.getAllVectors();
    const queryLower = query.toLowerCase();
    
    const keywordResults = vectors
      .filter(v => v.text.toLowerCase().includes(queryLower))
      .map(v => ({
        chunk: v,
        similarity: 0.5, // Base score for keyword match
        relevance: 'medium',
      }));

    // Merge results
    const allResults = [...semanticResults.results, ...keywordResults];
    const merged = this.mergeSearchResults([
      { results: allResults },
    ]);

    return {
      results: merged.slice(0, options.topK || config.maxChunksPerQuery),
      query,
      semanticCount: semanticResults.results.length,
      keywordCount: keywordResults.length,
    };
  }

  isInitialized() {
    return this.initialized;
  }
}

export default new SearchService();
