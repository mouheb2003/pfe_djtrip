import fs from 'fs/promises';
import path from 'path';
import { config } from '../config/index.js';

class VectorStorage {
  constructor() {
    this.storagePath = config.vectorStoragePath;
    this.indexFile = path.join(this.storagePath, 'index.json');
    this.vectorsFile = path.join(this.storagePath, 'vectors.json');
    this.metadataFile = path.join(this.storagePath, 'metadata.json');
    this.index = null;
    this.vectors = null;
    this.metadata = null;
  }

  async ensureStorageDirectory() {
    try {
      await fs.mkdir(this.storagePath, { recursive: true });
    } catch (error) {
      console.error('Error creating storage directory:', error.message);
      throw error;
    }
  }

  async saveIndex(index) {
    await this.ensureStorageDirectory();
    await fs.writeFile(this.indexFile, JSON.stringify(index, null, 2));
    this.index = index;
  }

  async saveVectors(vectors) {
    await this.ensureStorageDirectory();
    await fs.writeFile(this.vectorsFile, JSON.stringify(vectors, null, 2));
    this.vectors = vectors;
  }

  async saveMetadata(metadata) {
    await this.ensureStorageDirectory();
    await fs.writeFile(this.metadataFile, JSON.stringify(metadata, null, 2));
    this.metadata = metadata;
  }

  async loadIndex() {
    try {
      const data = await fs.readFile(this.indexFile, 'utf-8');
      this.index = JSON.parse(data);
      return this.index;
    } catch (error) {
      if (error.code === 'ENOENT') {
        this.index = {};
        return this.index;
      }
      throw error;
    }
  }

  async loadVectors() {
    try {
      const data = await fs.readFile(this.vectorsFile, 'utf-8');
      this.vectors = JSON.parse(data);
      return this.vectors;
    } catch (error) {
      if (error.code === 'ENOENT') {
        this.vectors = [];
        return this.vectors;
      }
      throw error;
    }
  }

  async loadMetadata() {
    try {
      const data = await fs.readFile(this.metadataFile, 'utf-8');
      this.metadata = JSON.parse(data);
      return this.metadata;
    } catch (error) {
      if (error.code === 'ENOENT') {
        this.metadata = {};
        return this.metadata;
      }
      throw error;
    }
  }

  async storeChunk(chunk) {
    if (!this.vectors) {
      await this.loadVectors();
    }

    // Check if chunk already exists
    const existingIndex = this.vectors.findIndex(v => v.id === chunk.id);
    
    if (existingIndex !== -1) {
      // Update existing chunk
      this.vectors[existingIndex] = chunk;
    } else {
      // Add new chunk
      this.vectors.push(chunk);
    }

    await this.saveVectors(this.vectors);
    
    // Update index
    if (!this.index) {
      await this.loadIndex();
    }
    
    this.index[chunk.id] = {
      filename: chunk.metadata.filename,
      path: chunk.metadata.path,
      sectionHeading: chunk.metadata.sectionHeading,
      chunkIndex: chunk.metadata.chunkIndex,
      storedAt: new Date().toISOString(),
    };
    
    await this.saveIndex(this.index);
  }

  async storeChunks(chunks) {
    console.log(`Storing ${chunks.length} chunks...`);
    
    for (const chunk of chunks) {
      await this.storeChunk(chunk);
    }
    
    console.log('Chunks stored successfully');
  }

  async getAllVectors() {
    if (!this.vectors) {
      await this.loadVectors();
    }
    return this.vectors || [];
  }

  async searchByFilename(filename) {
    const vectors = await this.getAllVectors();
    return vectors.filter(v => v.metadata.filename === filename);
  }

  async searchByPath(path) {
    const vectors = await this.getAllVectors();
    return vectors.filter(v => v.metadata.path === path);
  }

  async deleteChunk(chunkId) {
    if (!this.vectors) {
      await this.loadVectors();
    }

    this.vectors = this.vectors.filter(v => v.id !== chunkId);
    await this.saveVectors(this.vectors);

    if (this.index && this.index[chunkId]) {
      delete this.index[chunkId];
      await this.saveIndex(this.index);
    }
  }

  async deleteAll() {
    await this.ensureStorageDirectory();
    
    try {
      await fs.unlink(this.indexFile);
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
    }
    
    try {
      await fs.unlink(this.vectorsFile);
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
    }
    
    try {
      await fs.unlink(this.metadataFile);
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
    }

    this.index = {};
    this.vectors = [];
    this.metadata = {};
  }

  async updateMetadata(key, value) {
    if (!this.metadata) {
      await this.loadMetadata();
    }

    this.metadata[key] = value;
    await this.saveMetadata(this.metadata);
  }

  async getMetadata(key) {
    if (!this.metadata) {
      await this.loadMetadata();
    }

    return this.metadata[key];
  }

  async getStorageStats() {
    const vectors = await this.getAllVectors();
    const index = await this.loadIndex();
    const metadata = await this.loadMetadata();

    return {
      totalChunks: vectors.length,
      totalFiles: Object.keys(index).length,
      lastUpdated: metadata.lastIndexed || null,
      storagePath: this.storagePath,
      indexSize: JSON.stringify(index).length,
      vectorsSize: JSON.stringify(vectors).length,
    };
  }

  async clear() {
    await this.deleteAll();
    this.index = null;
    this.vectors = null;
    this.metadata = null;
  }
}

export default new VectorStorage();
