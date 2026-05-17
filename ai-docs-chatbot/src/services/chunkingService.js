import { config } from '../config/index.js';

class ChunkingService {
  constructor() {
    this.chunkSize = config.chunkSize;
    this.chunkOverlap = config.chunkOverlap;
  }

  splitTextIntoChunks(text, metadata = {}) {
    const chunks = [];
    const sentences = this.splitIntoSentences(text);
    
    let currentChunk = '';
    let currentChunkIndex = 0;
    
    for (let i = 0; i < sentences.length; i++) {
      const sentence = sentences[i];
      const potentialChunk = currentChunk ? `${currentChunk} ${sentence}` : sentence;
      
      if (potentialChunk.length <= this.chunkSize) {
        currentChunk = potentialChunk;
      } else {
        // Save current chunk if it exists
        if (currentChunk) {
          chunks.push(this.createChunk(currentChunk, currentChunkIndex, metadata));
          currentChunkIndex++;
          
          // Add overlap
          currentChunk = this.getOverlapText(currentChunk, sentences, i);
        } else {
          // Single sentence is too long, split it
          const subChunks = this.splitLongSentence(sentence, metadata, currentChunkIndex);
          chunks.push(...subChunks);
          currentChunkIndex += subChunks.length;
        }
      }
    }
    
    // Add the last chunk
    if (currentChunk) {
      chunks.push(this.createChunk(currentChunk, currentChunkIndex, metadata));
    }
    
    return chunks;
  }

  splitIntoSentences(text) {
    // Split by common sentence terminators
    const sentences = text
      .replace(/([.!?])\s+/g, '$1|SPLIT|')
      .replace(/\n+/g, '|SPLIT|')
      .split('|SPLIT|')
      .map(s => s.trim())
      .filter(s => s.length > 0);
    
    return sentences;
  }

  getOverlapText(currentChunk, sentences, currentIndex) {
    if (this.chunkOverlap === 0) return '';
    
    const words = currentChunk.split(' ');
    const overlapWords = Math.floor(this.chunkOverlap / 5); // Approximate 5 chars per word
    
    if (words.length <= overlapWords) return currentChunk;
    
    return words.slice(-overlapWords).join(' ');
  }

  splitLongSentence(sentence, metadata, startIndex) {
    const chunks = [];
    const words = sentence.split(' ');
    const wordsPerChunk = Math.floor(this.chunkSize / 5);
    
    for (let i = 0; i < words.length; i += wordsPerChunk) {
      const chunkWords = words.slice(i, i + wordsPerChunk);
      const chunk = chunkWords.join(' ');
      chunks.push(this.createChunk(chunk, startIndex + chunks.length, metadata));
    }
    
    return chunks;
  }

  createChunk(text, index, metadata) {
    return {
      id: `chunk_${index}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      text: text.trim(),
      index,
      metadata: {
        ...metadata,
        chunkIndex: index,
        chunkLength: text.length,
        createdAt: new Date().toISOString(),
      },
    };
  }

  chunkByHeadings(document) {
    const chunks = [];
    const { content, headings, sections, ...metadata } = document;
    
    if (sections.length === 0) {
      // No sections, use simple chunking
      return this.splitTextIntoChunks(content, metadata);
    }
    
    let chunkIndex = 0;
    
    for (const section of sections) {
      const sectionChunks = this.splitTextIntoChunks(section.content, {
        ...metadata,
        sectionHeading: section.heading,
      });
      
      // Add section heading to each chunk
      const chunksWithHeading = sectionChunks.map(chunk => ({
        ...chunk,
        text: `${section.heading}\n\n${chunk.text}`,
        metadata: {
          ...chunk.metadata,
          sectionHeading: section.heading,
        },
      }));
      
      chunks.push(...chunksWithHeading);
      chunkIndex += chunksWithHeading.length;
    }
    
    return chunks;
  }

  chunkByParagraphs(document) {
    const chunks = [];
    const { content, ...metadata } = document;
    
    const paragraphs = content.split(/\n\n+/);
    let currentChunk = '';
    let chunkIndex = 0;
    
    for (const paragraph of paragraphs) {
      const potentialChunk = currentChunk ? `${currentChunk}\n\n${paragraph}` : paragraph;
      
      if (potentialChunk.length <= this.chunkSize) {
        currentChunk = potentialChunk;
      } else {
        if (currentChunk) {
          chunks.push(this.createChunk(currentChunk, chunkIndex, metadata));
          chunkIndex++;
        }
        
        if (paragraph.length <= this.chunkSize) {
          currentChunk = paragraph;
        } else {
          const subChunks = this.splitTextIntoChunks(paragraph, metadata);
          chunks.push(...subChunks);
          chunkIndex += subChunks.length;
          currentChunk = '';
        }
      }
    }
    
    if (currentChunk) {
      chunks.push(this.createChunk(currentChunk, chunkIndex, metadata));
    }
    
    return chunks;
  }

  chunkDocument(document, strategy = 'headings') {
    switch (strategy) {
      case 'headings':
        return this.chunkByHeadings(document);
      case 'paragraphs':
        return this.chunkByParagraphs(document);
      case 'simple':
      default:
        return this.splitTextIntoChunks(document.content, {
          filename: document.filename,
          path: document.path,
          title: document.title,
        });
    }
  }

  chunkMultipleDocuments(documents, strategy = 'headings') {
    const allChunks = [];
    let globalChunkIndex = 0;
    
    for (const document of documents) {
      const chunks = this.chunkDocument(document, strategy);
      
      // Update chunk IDs to be globally unique
      const chunksWithGlobalId = chunks.map(chunk => ({
        ...chunk,
        id: `chunk_${globalChunkIndex}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
        metadata: {
          ...chunk.metadata,
          globalChunkIndex: globalChunkIndex,
        },
      }));
      
      allChunks.push(...chunksWithGlobalId);
      globalChunkIndex += chunksWithGlobalId.length;
    }
    
    return allChunks;
  }

  mergeChunks(chunks) {
    return chunks.map(chunk => chunk.text).join('\n\n---\n\n');
  }

  getChunkStatistics(chunks) {
    const totalChunks = chunks.length;
    const totalLength = chunks.reduce((sum, chunk) => sum + chunk.text.length, 0);
    const avgLength = totalLength / totalChunks;
    const minLength = Math.min(...chunks.map(c => c.text.length));
    const maxLength = Math.max(...chunks.map(c => c.text.length));
    
    return {
      totalChunks,
      totalLength,
      avgLength: Math.round(avgLength),
      minLength,
      maxLength,
    };
  }
}

export default new ChunkingService();
